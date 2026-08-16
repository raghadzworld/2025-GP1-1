import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// مفتاح SharedPreferences المشترك لعنوان IP الخاص بالساعة — نفس المفتاح
/// تستخدمه كل الشاشات (الاستماع، الساعة، الرئيسية) عشان يبقى IP واحد فقط.
const kWatchIpPrefsKey = 'watch_ip';

class WatchStatus {
  final bool isConnected;
  final int batteryPercent; // -1 يعني غير متوفرة
  final int lastSyncSecondsAgo;

  const WatchStatus({
    required this.isConnected,
    required this.batteryPercent,
    required this.lastSyncSecondsAgo,
  });
}

/// Raw-TCP client for the watch's audio streaming protocol.
///
/// Connects to `<watchIp>:3333`, sends 'r' (0x72) to start a continuous
/// raw PCM16 mono 16kHz audio stream, and 's' (0x73) to stop it.
class WatchAudioSocket {
  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  String? _host;

  static const int port = 3333;
  static const int sampleRate = 16000;

  bool get isConnected => _socket != null;

  Future<void> connect({
    required String host,
    required void Function(Uint8List data) onData,
    required void Function(Object error) onError,
    required void Function() onDone,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    _socket = socket;
    _host = host;
    socket.add([0x72]); // 'r' — start streaming
    _subscription = socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: true,
    );
  }

  Future<void> stop() async {
    try {
      _socket?.add([0x73]); // 's' — stop streaming
      await _socket?.flush();
    } catch (_) {
      // الاتصال قد يكون مقطوعاً بالفعل
    }
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }

  /// يرسل نتيجة التصنيف للساعة كـ٤ بايتات خام بإرسال واحد: '#' + رمز الفئة
  /// + رمز نمط الاهتزاز + رمز شدة الاهتزاز (كل واحد رقم '1'/'2'/'3').
  /// يستخدم اتصال البث المفتوح أصلاً إذا كان متاحاً، وإلا يفتح اتصال
  /// مؤقت جديد فقط لإرسال هذي البايتات (بدون إعادة بث الصوت).
  Future<void> sendDetectionCode(
    String code, {
    required int pattern,
    required int power,
  }) async {
    final message = [
      0x23, // '#'
      ...code.codeUnits,
      ...pattern.toString().codeUnits,
      ...power.toString().codeUnits,
    ];
    final asText = String.fromCharCodes(message);

    if (_socket != null) {
      try {
        _socket!.add(message);
        await _socket!.flush();
        debugPrint(
          'sendDetectionCode: sent "$asText" over existing socket',
        );
        return;
      } catch (e) {
        debugPrint(
          'sendDetectionCode: existing socket write failed ($e), retrying with temp connection',
        );
      }
    }

    final host = _host;
    if (host == null) {
      debugPrint('sendDetectionCode: no known host — nothing sent');
      return;
    }

    Socket? tempSocket;
    try {
      tempSocket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      tempSocket.add(message);
      await tempSocket.flush();
      debugPrint(
        'sendDetectionCode: sent "$asText" over temporary connection to $host:$port',
      );
    } catch (e) {
      debugPrint('sendDetectionCode: failed to send "$asText" — $e');
    } finally {
      await tempSocket?.close();
    }
  }

  /// يفتح اتصال قصير مستقل بالساعة، يرسل 'i'، ويرجع حالتها الحالية.
  /// يستخدم من شاشات ما فيها اتصال بث مفتوح أصلاً (الساعة، الرئيسية).
  static Future<WatchStatus?> queryStatus(
    String host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      debugPrint('queryStatus: TCP connected to $host:$port, sending "i"');
      socket.add([0x69]); // 'i'

      String line;
      try {
        line = await socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(timeout);
      } catch (e) {
        debugPrint('queryStatus: no line received within $timeout — $e');
        return null;
      }
      debugPrint('queryStatus: raw line received: "$line"');

      final parts = line.split(',');
      if (parts.length != 4 || parts[0] != 'I') {
        debugPrint('queryStatus: unexpected format (${parts.length} parts)');
        return null;
      }

      return WatchStatus(
        isConnected: parts[1] == '1',
        batteryPercent: int.parse(parts[2]),
        lastSyncSecondsAgo: int.parse(parts[3]),
      );
    } catch (e) {
      debugPrint('queryStatus: TCP connect to $host:$port failed — $e');
      return null;
    } finally {
      await socket?.close();
    }
  }
}
