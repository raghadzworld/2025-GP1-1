import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart'
    show KeyPairType, SimpleKeyPair, SimplePublicKey, X25519;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// الرسالة اللي تنعرض لما الساعة تحتاج إقران من جديد.
const kWatchRepairMessage =
    'أعيدي الإقران من الساعة: الإعدادات ← الإنترنت ← نسيان إقران الجوال';

enum WatchAuthFailure {
  /// ما فيه مفتاح محفوظ والساعة ما أرسلت PAIR.
  needsPairing,

  /// الساعة رفضت المفتاح المحفوظ (غالبًا انعمل "نسيان إقران") — انمسح.
  keyRejected,
}

/// فشل مصادقة مؤكد من الساعة نفسها — مو مشكلة شبكة، فإعادة المحاولة بنفس
/// الحالة ما تفيد لين المستخدمة تعيد الإقران.
class WatchAuthException implements Exception {
  const WatchAuthException(this.reason);
  final WatchAuthFailure reason;

  @override
  String toString() => 'WatchAuthException($reason)';
}

/// الساعة قفلت الاتصال.
class WatchClosedException implements Exception {
  const WatchClosedException();

  @override
  String toString() => 'WatchClosedException';
}

/// مصادقة HMAC-SHA256 اللي تطلبها الساعة على كل اتصال TCP قبل أي أمر:
///
///   ← PAIR,<64 hex>   (بس لو الساعة مو مقترنة — مفتاحها العام المؤقت X25519)
///   → PAIR,<64 hex>   مفتاحنا العام المؤقت X25519، خلال ٥ ثوانٍ
///                     المفتاح = SHA-256("nabeeh-pair-v1" ‖ shared ‖ watchPub ‖ phonePub)
///                     — المفتاح نفسه ما يمر على الشبكة أبدًا
///   ← AUTH,<32 hex>   (مع كل اتصال — nonce عشوائي، ١٦ بايت)
///   → AUTH,<64 hex>   HMAC-SHA256(المفتاح, بايتات الـnonce) خلال ٥ ثوانٍ
///   ← AUTH,OK         (أو تقفل الاتصال لو المفتاح غلط)
///
/// المفتاح محفوظ بـ flutter_secure_storage، فأي عزلة (الواجهة، خدمة
/// الاستماع، منبّه AlarmManager) تقرأه بنفسها.
class WatchAuth {
  WatchAuth._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'nabeeh_watch_device_key';
  static const _lineTimeout = Duration(seconds: 5);

  static Future<String?> readKey() async {
    try {
      return await _storage.read(key: _keyName);
    } catch (e) {
      debugPrint('WatchAuth: could not read key — $e');
      return null;
    }
  }

  static Future<void> _saveKey(String keyHex) =>
      _storage.write(key: _keyName, value: keyHex);

  static Future<void> clearKey() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (e) {
      debugPrint('WatchAuth: could not delete key — $e');
    }
  }

  /// HMAC-SHA256 على بايتات الـnonce (بعد فك الـhex)، مو على النص نفسه.
  @visibleForTesting
  static String sign(String keyHex, String nonceHex) =>
      Hmac(sha256, hex.decode(keyHex)).convert(hex.decode(nonceHex)).toString();

  static const _pairLabel = 'nabeeh-pair-v1';

  /// تبادل مفاتيح X25519 مع مفتاح الساعة العام المؤقت. يرجّع مفتاحنا العام
  /// (لإرساله) والمفتاح النهائي المشتق (٣٢ بايت hex).
  @visibleForTesting
  static Future<({List<int> phonePub, String keyHex})> derivePairKey(
    List<int> watchPub, {
    SimpleKeyPair? phoneKeyPair, // للاختبار بمفاتيح ثابتة فقط
  }) async {
    final algo = X25519();
    final keyPair = phoneKeyPair ?? await algo.newKeyPair();
    final phonePub = (await keyPair.extractPublicKey()).bytes;
    final shared = await (await algo.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(watchPub, type: KeyPairType.x25519),
    )).extractBytes();
    final key = sha256.convert([
      ...utf8.encode(_pairLabel),
      ...shared,
      ...watchPub,
      ...phonePub,
    ]);
    return (phonePub: phonePub, keyHex: key.toString());
  }

  static bool _isHex(String value, int length) =>
      value.length == length && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);

  /// ينفّذ المصادقة على اتصال مفتوح توّه. [nextLine] يرجّع السطر الجاي من
  /// الساعة (أو يرمي [WatchClosedException] لو قفلت / TimeoutException).
  ///
  /// [storedKey] لازم ينقرأ من التخزين ([readKey]) **قبل** فتح الاتصال —
  /// أول قراءة من flutter_secure_storage ممكن تاخذ أكثر من مهلة الساعة (٥
  /// ثوانٍ)، فقراءته بعد وصول AUTH كانت تقطع الاتصال.
  ///
  /// يرمي [WatchAuthException] لو الساعة تحتاج إقران من جديد — وفي حالة
  /// رفض المفتاح يمسحه أول، عشان ما نعيد المحاولة بنفس المفتاح للأبد.
  static Future<void> authenticate({
    required Future<String> Function(Duration timeout) nextLine,
    required Future<void> Function(String line) writeLine,
    required String? storedKey,
  }) async {
    var line = await nextLine(_lineTimeout);
    String? keyHex;
    var pairing = false;

    if (line.startsWith('PAIR,')) {
      final watchPubHex = line.substring(5).trim();
      if (!_isHex(watchPubHex, 64)) {
        throw FormatException('invalid PAIR public key from watch', line);
      }
      final derived = await derivePairKey(hex.decode(watchPubHex));
      await writeLine('PAIR,${hex.encode(derived.phonePub)}\n');
      // ما نحفظ المفتاح هنا — بس بعد AUTH,OK. الساعة كمان ما تحفظه إلا بعد
      // نجاح التحقق، فلو انقطع الاتصال بالنص الإقران يعيد نفسه بالاتصال الجاي.
      keyHex = derived.keyHex;
      pairing = true;
      debugPrint('WatchAuth: X25519 pairing — derived new device key');
      line = await nextLine(_lineTimeout);
    }

    if (!line.startsWith('AUTH,')) {
      throw FormatException('expected AUTH challenge', line);
    }
    final nonceHex = line.substring(5).trim();
    if (!_isHex(nonceHex, 32)) {
      throw FormatException('invalid AUTH nonce from watch', line);
    }

    keyHex ??= storedKey;
    if (keyHex == null || !_isHex(keyHex, 64)) {
      throw const WatchAuthException(WatchAuthFailure.needsPairing);
    }

    await writeLine('AUTH,${sign(keyHex, nonceHex)}\n');

    String? reply;
    try {
      reply = await nextLine(_lineTimeout);
    } on WatchClosedException {
      reply = null;
    } on SocketException {
      // إغلاق مفاجئ (RST) بعد ردّنا = نفس معنى الرفض.
      reply = null;
    }

    if (reply?.trim() == 'AUTH,OK') {
      if (pairing) {
        await _saveKey(keyHex);
        debugPrint('WatchAuth: pairing verified — device key stored');
      }
      return;
    }

    if (pairing) {
      // فشل أثناء الإقران نفسه: ما حفظنا شي، والساعة بعدها مو مقترنة فترسل
      // PAIR من جديد بالاتصال الجاي — إعادة محاولة عادية، مو "أعيدي الإقران".
      throw StateError('pairing was not confirmed by the watch');
    }
    await _rejectKey(keyHex);
  }

  static Future<Never> _rejectKey(String usedKey) async {
    debugPrint('WatchAuth: watch rejected stored key — clearing it');
    // نمسح بس لو المحفوظ لسا هو نفس المفتاح اللي انرفض — عزلة ثانية ممكن
    // تكون أقرنت وحفظت مفتاح جديد بين ما قرأنا وما انرفضنا.
    if (await readKey() == usedKey) await clearKey();
    throw const WatchAuthException(WatchAuthFailure.keyRejected);
  }
}

/// اتصال قصير مع قراءة أسطر — للاتصالات المؤقتة (الفحص، منبّه التطبيق
/// المقفول). الاتصال الدائم بـ WatchLink له قارئ أسطر خاص فيه.
class WatchLineSocket {
  WatchLineSocket._(this.socket)
    : _lines = StreamIterator(
        socket
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter()),
      );

  final Socket socket;
  final StreamIterator<String> _lines;

  /// يفتح الاتصال ويصادق. يرمي [WatchAuthException] لو تحتاج إقران.
  static Future<WatchLineSocket> connect(
    String host,
    int port, {
    required Duration timeout,
  }) async {
    // المفتاح قبل فتح الاتصال — مهلة الساعة ٥ ثوانٍ تبدأ مع الاتصال.
    final storedKey = await WatchAuth.readKey();
    final socket = await Socket.connect(host, port, timeout: timeout);
    final conn = WatchLineSocket._(socket);
    try {
      await WatchAuth.authenticate(
        storedKey: storedKey,
        nextLine: conn.nextLine,
        writeLine: (line) async {
          socket.write(line);
          await socket.flush();
        },
      );
      return conn;
    } catch (_) {
      await conn.close();
      rethrow;
    }
  }

  Future<String> nextLine(Duration timeout) async {
    if (!await _lines.moveNext().timeout(timeout)) {
      throw const WatchClosedException();
    }
    return _lines.current.trim();
  }

  Future<String> waitFor(String prefix, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) throw TimeoutException(prefix);
      final line = await nextLine(remaining);
      if (line.startsWith(prefix)) return line;
    }
  }

  Future<void> close() async {
    try {
      await socket.flush().timeout(const Duration(seconds: 1));
    } catch (_) {}
    socket.destroy();
    unawaited(_lines.cancel().catchError((_) {}));
  }
}
