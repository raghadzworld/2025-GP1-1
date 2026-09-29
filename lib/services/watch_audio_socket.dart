import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_auth.dart';
import 'watch_link.dart';

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

/// Discovery helpers and one-shot fallbacks for the watch's TCP protocol
/// on `<watchIp>:3333`.
///
/// The app talks to the watch over the single persistent connection in
/// [WatchLink]; the `*Once` helpers below open a short-lived connection and
/// are only used by [WatchLink] when no isolate owns that connection (e.g. a
/// reminder alarm firing while the app itself is not running).
class WatchAudioSocket {
  static const int port = 3333;
  static const int sampleRate = 16000;

  /// Finds the watch on the local Wi-Fi network without asking the user for
  /// its changing DHCP address. The cached IP remains a fallback for networks
  /// that block multicast DNS.
  ///
  /// [cancelled] يوقف البحث بين الخطوات — WatchLink يستخدمه لما يتنازل عن
  /// الاتصال لخدمة الاستماع، عشان ما يضل يفحص الساعة وقتها.
  static Future<String?> discoverWatchHost({
    Duration timeout = const Duration(seconds: 3),
    bool Function()? cancelled,
  }) async {
    final client = MDnsClient();
    try {
      await client.start();
      final deadline = DateTime.now().add(timeout);
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('$_watchServiceType.local'),
      )) {
        if (DateTime.now().isAfter(deadline)) break;
        if (cancelled?.call() ?? false) return null;
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
    if (cancelled?.call() ?? false) return null;
    return discoverWatchHostByScan(timeout: timeout, cancelled: cancelled);
  }

  /// Fallback for networks that block multicast DNS. The probe is limited to
  /// the phone's current IPv4 subnets, so a saved address from another Wi-Fi
  /// network can never be treated as a live watch connection.
  static Future<String?> discoverWatchHostByScan({
    Duration timeout = const Duration(seconds: 3),
    bool Function()? cancelled,
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
      if (cancelled?.call() ?? false) return null;
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

  /// الساعة تبدأ كل اتصال بسطر PAIR أو AUTH — هذا يكفي للتعرّف عليها.
  /// الفحص **ما يصادق** عمدًا: أي مصادقة تكتمل تطرد جلسة الساعة الحالية،
  /// والإقران (X25519) يعيد نفسه بالاتصال الجاي لو ما ردّينا على PAIR.
  static Future<String?> _probeWatchHost(String host, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final line = await socket
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 2));
      if (line.startsWith('PAIR,') || line.startsWith('AUTH,')) return host;
    } catch (_) {
      // Most addresses in the local subnet are expected to refuse the probe.
    } finally {
      socket?.destroy();
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

  /// يفتح اتصال مؤقت مصادَق — للاحتياط فقط لما ما فيه مالك للاتصال الدائم
  /// (مثل منبّه يشتغل من عزلة AlarmManager والتطبيق مقفول). المفتاح ينقرأ
  /// من flutter_secure_storage داخل نفس العزلة.
  /// يرمي [WatchAuthException] لو الساعة تحتاج إقران.
  static Future<WatchLineSocket?> _openOnce(
    String? host,
    Duration timeout,
  ) async {
    if (host != null && host.isNotEmpty && await isOnSameLocalNetwork(host)) {
      try {
        return await WatchLineSocket.connect(host, port, timeout: timeout);
      } on WatchAuthException {
        rethrow;
      } catch (e) {
        debugPrint('WatchAudioSocket: $host unreachable — $e');
      }
    }
    final found = await discoverWatchHost();
    if (found == null || found == host) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWatchIpPrefsKey, found);
    try {
      return await WatchLineSocket.connect(found, port, timeout: timeout);
    } on WatchAuthException {
      rethrow;
    } catch (e) {
      debugPrint('WatchAudioSocket: $found unreachable — $e');
      return null;
    }
  }

  /// إرسال بايتات عبر اتصال مؤقت مصادَق.
  static Future<bool> sendOnce(
    String? host,
    List<int> message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    WatchLineSocket? conn;
    try {
      conn = await _openOnce(host, timeout);
      if (conn == null) return false;
      conn.socket.add(message);
      await conn.socket.flush();
      debugPrint('sendOnce: sent "${String.fromCharCodes(message)}"');
      return true;
    } catch (e) {
      debugPrint('sendOnce: failed — $e');
      return false;
    } finally {
      await conn?.close();
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
  /// (نسخة الاتصال المؤقت — التطبيق يستخدم [WatchLink.sendReminders].)
  static Future<int?> sendRemindersOnce(
    String? host,
    String payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    WatchLineSocket? conn;
    try {
      conn = await _openOnce(host, timeout);
      if (conn == null) return null;
      conn.socket.add(utf8.encode('@$payload\n'));
      await conn.socket.flush();

      // ننتظر ردّ الساعة `R,<count>` قبل ما نقفل الاتصال — الفيرموير يقرأ
      // الجدول داخل حلقة فيها تأخير، وقفل الاتصال فورًا كان يقطعه بالنص.
      final ack = await conn.waitFor('R,', timeout);
      final count = int.tryParse(ack.substring(2).trim());
      debugPrint(
        'sendRemindersOnce: sent "${payload.isEmpty ? '(cleared)' : payload}" '
        '— الساعة حفظت $count تذكير',
      );
      return count;
    } catch (e) {
      debugPrint('sendRemindersOnce: failed to send schedule — $e');
      return null;
    } finally {
      await conn?.close();
    }
  }

  /// اتصال قصير مصادَق، يرسل 'i'، ويرجع حالة الساعة.
  /// احتياطي فقط — الشاشات تستخدم حالة [WatchLink] الحية.
  static Future<WatchStatus?> queryStatusOnce(
    String? host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    WatchLineSocket? conn;
    try {
      conn = await _openOnce(host, timeout);
      if (conn == null) return null;
      conn.socket.add([0x69]); // 'i'
      await conn.socket.flush();
      final parts = (await conn.waitFor('I,', timeout)).split(',');
      if (parts.length != 4) return null;
      return WatchStatus(
        isConnected: parts[1] == '1',
        batteryPercent: int.parse(parts[2]),
        lastSyncSecondsAgo: int.parse(parts[3]),
      );
    } catch (e) {
      debugPrint('queryStatusOnce: failed — $e');
      return null;
    } finally {
      await conn?.close();
    }
  }
}
