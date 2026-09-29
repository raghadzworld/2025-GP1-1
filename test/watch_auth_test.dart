import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart'
    show KeyPairType, SimpleKeyPair, SimplePublicKey, X25519;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nabbeh/services/watch_auth.dart';

const _keyHex =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
const _nonceHex = '6465666768696a6b6c6d6e6f70717273';
// محسوبة بشكل مستقل: Python hmac.new(key, nonce, sha256).hexdigest()
const _expectedMac =
    '82b166a6ea164ce7bde4cb0bbec5b7e5a3db5c6f3eea49e9a83f36f46eb5d6db';

const _storageKey = 'nabeeh_watch_device_key';

/// شو تسوي الساعة الوهمية بعد ما يوصلها PAIR من الجوال.
enum _PairBehavior { complete, dropBeforeAuth, rejectAuth }

/// ساعة وهمية. لو [pairing] true تبدأ بـ X25519 (زي الساعة غير المقترنة)،
/// وإلا تقبل فقط [acceptKey].
Future<ServerSocket> _fakeWatch({
  bool pairing = false,
  _PairBehavior pairBehavior = _PairBehavior.complete,
  String? acceptKey,
  List<String>? derivedKeys,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) async {
    var key = acceptKey;
    SimpleKeyPair? watchKp;
    List<int>? watchPub;
    if (pairing) {
      watchKp = await X25519().newKeyPair();
      watchPub = (await watchKp.extractPublicKey()).bytes;
      client.write('PAIR,${hex.encode(watchPub)}\n');
    } else {
      client.write('AUTH,$_nonceHex\n');
    }

    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
          if (line.startsWith('PAIR,') && watchKp != null) {
            // جهة الساعة من الاشتقاق — مكتوبة هنا بشكل مستقل عن التطبيق.
            final phonePub = hex.decode(line.substring(5));
            final shared = await (await X25519().sharedSecretKey(
              keyPair: watchKp,
              remotePublicKey: SimplePublicKey(
                phonePub,
                type: KeyPairType.x25519,
              ),
            )).extractBytes();
            final derived = sha256.convert([
              ...utf8.encode('nabeeh-pair-v1'),
              ...shared,
              ...watchPub!,
              ...phonePub,
            ]).toString();
            key = derived;
            derivedKeys?.add(derived);
            if (pairBehavior == _PairBehavior.dropBeforeAuth) {
              client.destroy();
              return;
            }
            client.write('AUTH,$_nonceHex\n');
          } else if (line.startsWith('AUTH,')) {
            final current = key;
            final ok =
                current != null &&
                pairBehavior != _PairBehavior.rejectAuth &&
                line == 'AUTH,${WatchAuth.sign(current, _nonceHex)}';
            if (ok) {
              client.write('AUTH,OK\n');
            } else {
              client.destroy(); // مفتاح غلط — الساعة تقفل الاتصال
            }
          }
        }, onError: (_) {});
  });
  return server;
}

Future<WatchLineSocket> _connect(ServerSocket server) =>
    WatchLineSocket.connect(
      '127.0.0.1',
      server.port,
      timeout: const Duration(seconds: 2),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('HMAC is computed over the nonce bytes, not the hex text', () {
    expect(WatchAuth.sign(_keyHex, _nonceHex), _expectedMac);
  });

  test('pair key derivation matches an independent implementation', () async {
    // مفاتيح RFC 7748 §6.1 (الجوال = Alice، الساعة = Bob)، والناتج محسوب
    // بـ Python cryptography + hashlib بنفس الصيغة.
    final phoneKp = await X25519().newKeyPairFromSeed(
      hex.decode(
        '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
      ),
    );
    final derived = await WatchAuth.derivePairKey(
      hex.decode(
        'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f',
      ),
      phoneKeyPair: phoneKp,
    );
    expect(
      hex.encode(derived.phonePub),
      '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
    );
    expect(
      derived.keyHex,
      '16bdebfdb43c3776bfa5acf899ded402885dd57f55d9c632be4fd2fbb15bd372',
    );
  });

  test('X25519 pairing stores key after AUTH,OK; reconnect reuses it', () async {
    final derivedKeys = <String>[];
    var server = await _fakeWatch(pairing: true, derivedKeys: derivedKeys);
    var conn = await _connect(server);
    await conn.close();
    await server.close();

    expect(derivedKeys, hasLength(1));
    expect(await WatchAuth.readKey(), derivedKeys.single);

    // "سكّر التطبيق وافتحه": الساعة مقترنة الحين، فما فيه PAIR.
    server = await _fakeWatch(acceptKey: derivedKeys.single);
    conn = await _connect(server);
    await conn.close();
    await server.close();
  });

  test(
    'pairing interrupted before AUTH stores nothing and is retryable',
    () async {
      final server = await _fakeWatch(
        pairing: true,
        pairBehavior: _PairBehavior.dropBeforeAuth,
      );
      await expectLater(
        _connect(server),
        throwsA(isNot(isA<WatchAuthException>())),
      );
      expect(await WatchAuth.readKey(), isNull);
      await server.close();
    },
  );

  test('pairing rejected at AUTH stores nothing and is retryable', () async {
    final server = await _fakeWatch(
      pairing: true,
      pairBehavior: _PairBehavior.rejectAuth,
    );
    await expectLater(
      _connect(server),
      throwsA(isNot(isA<WatchAuthException>())),
    );
    expect(await WatchAuth.readKey(), isNull);
    await server.close();
  });

  test('no stored key and no PAIR -> needsPairing', () async {
    final server = await _fakeWatch(acceptKey: _keyHex);
    await expectLater(
      _connect(server),
      throwsA(
        isA<WatchAuthException>().having(
          (e) => e.reason,
          'reason',
          WatchAuthFailure.needsPairing,
        ),
      ),
    );
    await server.close();
  });

  test('rejected stored key is cleared so it is not retried forever', () async {
    FlutterSecureStorage.setMockInitialValues({_storageKey: 'ff' * 32});
    final server = await _fakeWatch(acceptKey: _keyHex);
    await expectLater(
      _connect(server),
      throwsA(
        isA<WatchAuthException>().having(
          (e) => e.reason,
          'reason',
          WatchAuthFailure.keyRejected,
        ),
      ),
    );
    expect(await WatchAuth.readKey(), isNull);
    await server.close();
  });
}
