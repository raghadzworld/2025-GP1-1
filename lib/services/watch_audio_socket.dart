import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح SharedPreferences المشترك لعنوان IP الخاص بالساعة — نفس المفتاح
/// تستخدمه كل الشاشات (الاستماع، الساعة، الرئيسية) عشان يبقى IP واحد فقط.
const kWatchIpPrefsKey = 'watch_ip';
const _watchServiceType = '_nabeeh._tcp';
const _watchServiceName = 'nabeeh-watch';

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

  /// Finds the watch on the local Wi-Fi network without asking the user for
  /// its changing DHCP address. The cached IP remains a fallback for networks
  /// that block multicast DNS.
  static Future<String?> discoverWatchHost({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = MDnsClient();
    try {
      await client.start();
      final deadline = DateTime.now().add(timeout);
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('$_watchServiceType.local'),
      )) {
        if (DateTime.now().isAfter(deadline)) break;
        if (!ptr.domainName.startsWith('$_watchServiceName.')) continue;

        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final address in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            debugPrint(
              'Discovered Nabeeh Watch at ${address.address.address}:$port',
            );
            return address.address.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Watch mDNS discovery failed: $e');
    } finally {
      client.stop();
    }
    return discoverWatchHostByScan(timeout: timeout);
  }

  /// Fallback for networks that block multicast DNS. The probe is limited to
  /// the phone's current IPv4 subnets, so a saved address from another Wi-Fi
  /// network can never be treated as a live watch connection.
  static Future<String?> discoverWatchHostByScan({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final prefixes = <String>{};
    for (final networkInterface in interfaces) {
      for (final address in networkInterface.addresses) {
        final octets = address.address.split('.');
        if (octets.length == 4) {
          prefixes.add('${octets[0]}.${octets[1]}.${octets[2]}');
        }
      }
    }

    final candidates = [
      for (final prefix in prefixes)
        for (var lastOctet = 1; lastOctet <= 254; lastOctet++)
          '$prefix.$lastOctet',
    ];
    final probeTimeout = timeout < const Duration(milliseconds: 300)
        ? timeout
        : const Duration(milliseconds: 300);

    for (var offset = 0; offset < candidates.length; offset += 32) {
      final batch = candidates.skip(offset).take(32);
      final results = await Future.wait(
        batch.map((candidate) => _probeWatchHost(candidate, probeTimeout)),
      );
      for (final candidate in results) {
        if (candidate != null) {
          debugPrint(
            'Discovered Nabeeh Watch by network scan at $candidate:$port',
          );
          return candidate;
        }
      }
    }
    return null;
  }

  static Future<String?> _probeWatchHost(String host, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add([0x69]); // 'i' — request watch status
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);
      final parts = line.split(',');
      if (parts.length == 4 &&
          parts[0] == 'I' &&
          int.tryParse(parts[2]) != null &&
          int.tryParse(parts[3]) != null) {
        return host;
      }
    } catch (_) {
      // Most addresses in the local subnet are expected to refuse the probe.
    } finally {
      await socket?.close();
    }
    return null;
  }

  /// Resolve the watch on the current network only. A cached address is kept
  /// for display/diagnostics, but is never trusted as an automatic connection.
  static Future<String?> resolveWatchHost([String? preferredHost]) async {
    if (preferredHost != null && preferredHost.isNotEmpty) {
      if (!await isOnSameLocalNetwork(preferredHost)) {
        debugPrint(
          'Ignoring watch address $preferredHost: it is outside the phone local network',
        );
      } else {
      final verified = await _probeWatchHost(
        preferredHost,
        const Duration(milliseconds: 500),
      );
      if (verified != null) return verified;
      }
    }

    final discovered = await discoverWatchHost();
    if (discovered != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kWatchIpPrefsKey, discovered);
      return discovered;
    }
    return null;
  }

  /// Checks the local IPv4 /24 network before accepting a watch address.
  /// This prevents a previously saved, routable address from looking like a
  /// local watch connection while the phone is on another Wi-Fi network.
  static Future<bool> isOnSameLocalNetwork(String host) async {
    final watchAddress = InternetAddress.tryParse(host);
    if (watchAddress == null || watchAddress.type != InternetAddressType.IPv4) {
      return false;
    }

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final watchBytes = watchAddress.rawAddress;
    for (final networkInterface in interfaces) {
      for (final address in networkInterface.addresses) {
        final localBytes = address.rawAddress;
        if (localBytes.length == 4 &&
            localBytes[0] == watchBytes[0] &&
            localBytes[1] == watchBytes[1] &&
            localBytes[2] == watchBytes[2]) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> connect({
    String? host,
    required void Function(Uint8List data) onData,
    required void Function(Object error) onError,
    required void Function() onDone,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    host = await resolveWatchHost(host);
    if (host == null || host.isEmpty) {
      throw StateError('Nabeeh Watch was not found on the local network');
    }
    final socket = await Socket.connect(host, port, timeout: timeout);
    _socket = socket;
    _host = host;
    _subscription = socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: true,
    );
    debugPrint('connect: TCP connected to $host:$port, starting audio stream');
    socket.add([0x72]); // 'r' — start streaming
    await socket.flush();
    debugPrint('connect: start audio command sent to $host:$port');
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
        debugPrint('sendDetectionCode: sent "$asText" over existing socket');
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

  /// نفس فكرة sendDetectionCode لكن بدون الحاجة لكائن WatchAudioSocket
  /// موجود أصلاً (وبالتالي بدون _host محفوظ من اتصال بث سابق) — تُستخدم من
  /// سياقات ما فيها أي اتصال بث مفتوح، مثل منبّه يشتغل من عزلة خلفية منفصلة
  /// تمامًا (AlarmManager) عند وصول وقته. تفتح اتصال TCP مؤقت للإرسال فقط
  /// وتقفله، بالضبط متل الفرع الاحتياطي بـ sendDetectionCode.
  static Future<bool> sendCodeToHostDirect(
    String? host,
    String code, {
    required int pattern,
    required int power,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    host = await resolveWatchHost(host);
    if (host == null || host.isEmpty) return false;
    final message = [
      0x23, // '#'
      ...code.codeUnits,
      ...pattern.toString().codeUnits,
      ...power.toString().codeUnits,
    ];
    Socket? tempSocket;
    try {
      tempSocket = await Socket.connect(host, port, timeout: timeout);
      tempSocket.add(message);
      await tempSocket.flush();
      debugPrint(
        'sendCodeToHostDirect: sent "$code$pattern$power" to $host:$port',
      );
      return true;
    } catch (e) {
      debugPrint('sendCodeToHostDirect: failed to send "$code" to $host — $e');
      return false;
    } finally {
      await tempSocket?.close();
    }
  }

  /// يرسل جدول التذكيرات كامل للساعة: '@' + الجدول + '\n'.
  ///
  /// الساعة تحفظه بذاكرتها الدائمة (NVS) وتطلق كل تذكير من ساعتها الداخلية،
  /// فيهتز السوار بوقته حتى لو الجوال نايم أو خارج الشبكة أو بطاريته فاضية —
  /// وهذا المهم لمستخدم أصم، لأن السوار هو قناة التنبيه الأساسية مو الجوال.
  ///
  /// صيغة الجدول (تفكّها parse_reminder_payload بالفيرموير):
  ///   H:M:daysMask:pattern:intensity:once  ومقاطعها مفصولة بـ ';'
  /// ونص فاضي معناه "امسح كل التذكيرات المحفوظة بالساعة".
  /// يرجّع عدد التذكيرات اللي أكّدت الساعة إنها حفظتها، أو null لو ما وصل ردّ.
  static Future<int?> sendRemindersToHost(
    String? host,
    String payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    host = await resolveWatchHost(host);
    if (host == null || host.isEmpty) return null;
    Socket? tempSocket;
    try {
      tempSocket = await Socket.connect(host, port, timeout: timeout);
      tempSocket.add(utf8.encode('@$payload\n'));
      await tempSocket.flush();

      // ننتظر ردّ الساعة "R,<count>" قبل ما نقفل الاتصال — مو بس للتأكيد:
      // الانتظار نفسه ضروري. الفيرموير يقرأ من الاتصال داخل حلقة فيها
      // تأخير، والجدول عشرات البايتات، فقفل الاتصال فور الإرسال كان يقطعه
      // بالنص ويضيع بدون ما يظهر أي خطأ بالجوال. البقاء لين يوصل الردّ
      // يضمن إن الساعة خلّصت قراءة كل شي.
      final ack = await tempSocket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.startsWith('R,'))
          .timeout(timeout);

      final count = int.tryParse(ack.substring(2).trim());
      debugPrint(
        'sendRemindersToHost: sent "${payload.isEmpty ? '(cleared)' : payload}" '
        'to $host:$port — الساعة حفظت $count تذكير',
      );
      return count;
    } catch (e) {
      debugPrint('sendRemindersToHost: failed to send schedule to $host — $e');
      return null;
    } finally {
      await tempSocket?.close();
    }
  }

  /// يفتح اتصال قصير مستقل بالساعة، يرسل 'i'، ويرجع حالتها الحالية.
  /// يستخدم من شاشات ما فيها اتصال بث مفتوح أصلاً (الساعة، الرئيسية).
  static Future<WatchStatus?> queryStatus(
    String? host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    host = await resolveWatchHost(host);
    if (host == null || host.isEmpty) return null;
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
