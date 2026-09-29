import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_audio_socket.dart';
import 'watch_auth.dart';

/// اسم منفذ "مالك الاتصال" الحالي بسجل IsolateNameServer — السجل مشترك بين
/// كل العزلات بنفس العملية (الواجهة، خدمة الاستماع الخلفية، منبّه
/// AlarmManager)، فأي عزلة تقدر توصل للمالك وترسل أوامرها عبر اتصاله.
const _kOwnerPortName = 'nabeeh_watch_link_owner';

/// عزلة الواجهة تسجّل منفذها هنا لما تتنازل عن الاتصال لخدمة الاستماع، عشان
/// الخدمة ترجّع لها الاتصال (resume) أول ما يوقف الاستماع.
const _kStandbyPortName = 'nabeeh_watch_link_standby';

enum _Role { idle, owner, standby }

/// اتصال TCP واحد مستمر بالساعة (المنفذ 3333) لكل التطبيق.
///
/// بدل ما كل استعلام حالة/أمر يفتح اتصال جديد ويقفله (كل ٥ ثوانٍ تقريبًا)،
/// هذا الكلاس يفتح اتصال واحد ويخليه مفتوح، ويمرّر عليه كل شي: استطلاع
/// الحالة الدوري ('i')، بدء/إيقاف بث الصوت ('r'/'s')، نتائج الاكتشاف ('#')،
/// وجدول التذكيرات ('@').
///
/// الساعة تقبل عميل واحد بس، وسوكِت Dart ما ينتقل بين العزلات، فبأي لحظة فيه
/// عزلة وحدة بس "مالكة" للاتصال:
///  - عزلة الواجهة تملكه عادةً ([start]).
///  - خدمة الاستماع الخلفية تستلمه طول جلسة الاستماع ([takeOver]) وترجّعه
///    بعدها ([release]) — الواجهة تنتقل لوضع الانتظار وتستعلم من الخدمة.
///  - أي عزلة ثانية (مثل منبّه التذكير) ترسل أوامرها للمالك عبر منفذه، وما
///   تفتح اتصال مؤقت خاص فيها إلا لو ما فيه مالك أصلًا (التطبيق مقفول).
///
/// القراءة من السوكِت غير محظورة: الـ VM يقرأ بخيط I/O خاص ويوصل البيانات
/// كأحداث لحلقة العزلة، وبث الصوت نفسه يشتغل بعزلة الخدمة الخلفية المنفصلة
/// عن عزلة الواجهة، فما يعطّل الرسم أبدًا.
class WatchLink {
  WatchLink._();

  /// نسخة وحدة لكل عزلة.
  static final WatchLink instance = WatchLink._();

  static const _initialBackoff = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 60);
  static const _pollInterval = Duration(seconds: 5);
  static const _handshakeTimeout = Duration(seconds: 3);
  // وقت البث الساعة ترسل صوت باستمرار — سكوت أطول من كذا معناه الاتصال مات
  // حتى لو نظام التشغيل ما بلّغ بإغلاقه (مثلاً الساعة انطفت فجأة).
  static const _audioSilenceLimit = Duration(seconds: 5);
  static const _maxLineBuffer = 4096;

  /// هل فيه اتصال حي بالساعة الآن (سواء بهذي العزلة أو عند المالك).
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// آخر حالة وصلت من الساعة، أو null لو غير متصلة.
  final ValueNotifier<WatchStatus?> status = ValueNotifier(null);

  /// الساعة موجودة بس رفضت المصادقة (ما فيه مفتاح، أو المفتاح انمسح بعد
  /// "نسيان الإقران") — الواجهة تعرض [kWatchRepairMessage].
  final ValueNotifier<bool> needsPairing = ValueNotifier(false);

  _Role _role = _Role.idle;
  ReceivePort? _port;

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  String? _host;
  bool _connecting = false;
  Future<void>? _connectFuture;
  Duration _backoff = _initialBackoff;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _polling = false;
  int _missedPolls = 0;
  DateTime _lastRx = DateTime.now();
  DateTime? _statusAt;

  void Function(Uint8List data)? _onAudio;
  bool _audioPaused = false;
  final List<int> _lineBuffer = [];
  final List<_LineWaiter> _waiters = [];
  // أسطر المصادقة (PAIR/AUTH) تنحفظ بطابور لأنها ممكن توصل مع بعض بنفس
  // الحزمة قبل ما نطلبها.
  bool _inHandshake = false;
  final Queue<String> _handshakeLines = Queue();
  Completer<void>? _handshakeSignal;
  Future<void> _opChain = Future.value();

  String? get host => _host;

  // ─── دورة الملكية ──────────────────────────────────────────────────────────

  /// يُستدعى مرة وحدة من عزلة الواجهة عند تشغيل التطبيق. لو خدمة الاستماع
  /// ماسكة الاتصال أصلًا (رجعنا للتطبيق وهي شغّالة)، ننتظر لين ترجّعه.
  Future<void> start() async {
    if (_role != _Role.idle) return;
    _openPort();
    if (await _mayOpenOwnConnection()) {
      _becomeOwner();
    } else {
      _becomeStandby();
    }
  }

  /// القاعدة الوحيدة لفتح اتصال من عزلة مو مالكة: الساعة تقبل عميل واحد،
  /// وأي مصادقة تكتمل تطرد الجلسة الحالية حتى لو كانت تبث. فطول ما خدمة
  /// الاستماع شغّالة ما نفتح اتصال أبدًا — حتى لو ردّها تأخر (مشغولة
  /// بالصوت) — لين ترجّع الاتصال صراحة بـ 'resume'، أو تموت الخدمة نفسها.
  Future<bool> _mayOpenOwnConnection() async {
    if (await _backgroundServiceRunning()) return false;
    final owner = IsolateNameServer.lookupPortByName(_kOwnerPortName);
    if (owner == null || owner == _port?.sendPort) return true;
    // مالك ثاني غير الخدمة (مثلًا عزلة الواجهة والمنبّه يسأل): نفتح بس لو
    // ما يردّ أبدًا — عزلة ميتة وسجلها باقي.
    return !(await _call(owner, ['ping'], const Duration(seconds: 15))).ok;
  }

  static Future<bool> _backgroundServiceRunning() async {
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (_) {
      return false;
    }
  }

  /// تستدعيها خدمة الاستماع الخلفية: تطلب من المالك الحالي (الواجهة) يقفل
  /// اتصاله، وتفتح هي الاتصال الوحيد طول جلسة الاستماع.
  Future<void> takeOver() async {
    _openPort();
    if (_role == _Role.owner) return;
    final owner = IsolateNameServer.lookupPortByName(_kOwnerPortName);
    if (owner != null && owner != _port!.sendPort) {
      // المالك (الواجهة) ما يردّ إلا بعد ما يوقف أي محاولة اتصال أو فحص كان
      // بنصه — الساعة تقبل مصادقة معلّقة وحدة بس، والأحدث يلغي الأقدم،
      // فلو اتصلنا والواجهة لسا تحاول، الاثنين يفشلون.
      // لو ما ردّ (عزلة ميتة وسجلها باقي) نكمل عادي ونستبدله.
      await _call(owner, ['suspend'], const Duration(seconds: 10));
    }
    _becomeOwner();
  }

  /// ترجّع الخدمة الخلفية الاتصال لعزلة الواجهة (لو موجودة) بعد الاستماع.
  Future<void> release() async {
    if (_role != _Role.owner) return;
    _role = _Role.idle;
    _onAudio = null;
    _audioPaused = false;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    await _dropSocket(sendStop: true);
    if (IsolateNameServer.lookupPortByName(_kOwnerPortName) ==
        _port?.sendPort) {
      IsolateNameServer.removePortNameMapping(_kOwnerPortName);
    }
    IsolateNameServer.lookupPortByName(_kStandbyPortName)?.send(['resume']);
  }

  void _openPort() {
    if (_port != null) return;
    _port = ReceivePort()..listen(_onPortMessage);
  }

  void _becomeOwner() {
    IsolateNameServer.removePortNameMapping(_kOwnerPortName);
    IsolateNameServer.registerPortWithName(_port!.sendPort, _kOwnerPortName);
    if (IsolateNameServer.lookupPortByName(_kStandbyPortName) ==
        _port!.sendPort) {
      IsolateNameServer.removePortNameMapping(_kStandbyPortName);
    }
    _role = _Role.owner;
    _backoff = _initialBackoff;
    _startPolling();
    unawaited(_connect());
  }

  void _becomeStandby() {
    // بوضع الانتظار ما فيه أي إعادة محاولة ولا فحص: _scheduleReconnect و
    // _connect و_open كلهم يتأكدون إننا المالك، والبحث بالشبكة يوقف عبر
    // cancelled، و_dropSocket يقطع أي مصادقة بنصها.
    _role = _Role.standby;
    _reconnectTimer?.cancel();
    unawaited(_dropSocket());
    if (IsolateNameServer.lookupPortByName(_kOwnerPortName) ==
        _port!.sendPort) {
      IsolateNameServer.removePortNameMapping(_kOwnerPortName);
    }
    IsolateNameServer.removePortNameMapping(_kStandbyPortName);
    IsolateNameServer.registerPortWithName(_port!.sendPort, _kStandbyPortName);
    _startPolling();
  }

  // ─── الاتصال وإعادة المحاولة ───────────────────────────────────────────────

  Future<void> _connect() {
    if (_role != _Role.owner || _socket != null || _connecting) {
      return _connectFuture ?? Future.value();
    }
    return _connectFuture = _connectAttempt();
  }

  bool _notOwner() => _role != _Role.owner;

  Future<void> _connectAttempt() async {
    _connecting = true;
    _reconnectTimer?.cancel();
    try {
      // العنوان المحفوظ أولًا (ممكن المستخدم عدّله يدويًا)، بعده آخر عنوان
      // نجح، وآخر شي البحث بالشبكة — نفس ترتيب resolveWatchHost القديم لكن
      // بدون ما نقفل الاتصال بعد التحقق.
      final prefs = await SharedPreferences.getInstance();
      final candidates = <String>{
        ?prefs.getString(kWatchIpPrefsKey),
        ?_host,
      };
      var ok = false;
      for (final candidate in candidates) {
        if (_notOwner()) return;
        if (candidate.isEmpty ||
            !await WatchAudioSocket.isOnSameLocalNetwork(candidate)) {
          continue;
        }
        if (await _open(candidate)) {
          ok = true;
          break;
        }
      }
      if (!ok && _role == _Role.owner) {
        final found = await WatchAudioSocket.discoverWatchHost(
          cancelled: _notOwner,
        );
        if (found != null && !_notOwner()) ok = await _open(found);
      }
      if (!ok) throw StateError('Nabeeh Watch not reachable');
    } on WatchAuthException catch (e) {
      // الساعة موجودة لكن تحتاج إقران — ما نجرّب عناوين ثانية. المفتاح
      // المرفوض انمسح، فالمحاولات الجاية (بنفس الـ backoff) ما تعيد نفس
      // المفتاح؛ بس تنتظر لين الساعة ترسل PAIR جديد بعد إعادة الإقران.
      debugPrint('WatchLink: authentication failed — $e');
      needsPairing.value = true;
      _scheduleReconnect();
    } catch (e) {
      debugPrint('WatchLink: connect failed — $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// يفتح السوكِت، يصادق، ويجيب أول حالة بطلب 'i' — ولو نجح يخليه مفتوح.
  /// يرمي [WatchAuthException] لو الساعة تحتاج إقران.
  Future<bool> _open(String host) async {
    // المفتاح قبل فتح الاتصال — مهلة الساعة (٥ ثوانٍ) تبدأ مع الاتصال،
    // وأول قراءة من التخزين بعد فتح التطبيق ممكن تاخذ أطول من كذا.
    final storedKey = await WatchAuth.readKey();
    if (_notOwner()) return false;
    final Socket socket;
    try {
      socket = await Socket.connect(
        host,
        WatchAudioSocket.port,
        timeout: _handshakeTimeout,
      );
    } catch (_) {
      return false;
    }
    if (_role != _Role.owner || _socket != null) {
      socket.destroy();
      return false;
    }
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;
    _lineBuffer.clear();
    _handshakeLines.clear();
    _inHandshake = true;
    _lastRx = DateTime.now();
    _socketSub = socket.listen(
      _onBytes,
      onError: (Object e) => _onSocketLost(socket, e),
      onDone: () => _onSocketLost(socket, 'closed by watch'),
      cancelOnError: true,
    );

    // المصادقة قبل أي أمر (وقبل البث)، فأسطر PAIR/AUTH ما تختلط بالصوت.
    try {
      await WatchAuth.authenticate(
        storedKey: storedKey,
        nextLine: (timeout) => _nextHandshakeLine(socket, timeout),
        writeLine: (line) async {
          socket.write(line);
          await socket.flush();
        },
      );
    } on WatchAuthException {
      _inHandshake = false;
      await _dropSocket();
      rethrow;
    } catch (e) {
      debugPrint('WatchLink: $host authentication did not complete — $e');
      _inHandshake = false;
      await _dropSocket();
      return false;
    }
    _inHandshake = false;
    _handshakeLines.clear();
    needsPairing.value = false;

    try {
      final reply = _waitForLine((l) => l.startsWith('I,'), _handshakeTimeout);
      socket.add([0x69]); // 'i'
      await socket.flush();
      await reply;
    } catch (e) {
      debugPrint('WatchLink: $host did not answer handshake — $e');
      await _dropSocket();
      return false;
    }

    _host = host;
    _backoff = _initialBackoff;
    _missedPolls = 0;
    connected.value = true;
    debugPrint('WatchLink: persistent connection open to $host');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWatchIpPrefsKey, host);
    // انقطع البث بالنص وتوّنا رجعنا — نكمل البث على الاتصال الجديد.
    if (_onAudio != null && identical(_socket, socket)) _write([0x72]);
    return true;
  }

  void _onSocketLost(Socket socket, Object reason) {
    if (!identical(_socket, socket)) return;
    debugPrint('WatchLink: connection lost ($reason)');
    unawaited(_dropSocket());
    // أثناء المصادقة _open/_connect هم اللي يقررون إعادة المحاولة.
    if (!_inHandshake) _scheduleReconnect();
  }

  Future<String> _nextHandshakeLine(Socket socket, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (_handshakeLines.isEmpty) {
      if (!identical(_socket, socket)) throw const WatchClosedException();
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('watch handshake', timeout);
      }
      final signal = _handshakeSignal ??= Completer<void>();
      try {
        await signal.future.timeout(remaining);
      } on TimeoutException {
        // الحلقة تعيد الفحص وترمي المهلة
      }
    }
    return _handshakeLines.removeFirst();
  }

  void _wakeHandshake() {
    final signal = _handshakeSignal;
    _handshakeSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  /// إعادة محاولة بتأخير يتضاعف (٢، ٤، ٨ ... لين ٦٠ ثانية)، بدل محاولات
  /// فورية متكررة تستهلك بطارية الساعة والجوال وقت انقطاع الشبكة.
  void _scheduleReconnect() {
    if (_role != _Role.owner) return;
    _reconnectTimer?.cancel();
    final delay = _backoff;
    final doubled = _backoff * 2;
    _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
    debugPrint('WatchLink: retrying in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () => unawaited(_connect()));
  }

  Future<void> _dropSocket({bool sendStop = false}) async {
    final socket = _socket;
    _socket = null;
    _wakeHandshake();
    await _socketSub?.cancel();
    _socketSub = null;
    _lineBuffer.clear();
    for (final waiter in List.of(_waiters)) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(StateError('connection closed'));
      }
    }
    _waiters.clear();
    if (_role != _Role.standby) {
      connected.value = false;
      status.value = null;
    }
    if (socket == null) return;
    try {
      if (sendStop) {
        socket.add([0x73]); // 's'
        await socket.flush().timeout(const Duration(seconds: 1));
      }
      await socket.close().timeout(const Duration(seconds: 1));
    } catch (_) {
      // الاتصال مقطوع أصلًا
    } finally {
      socket.destroy();
    }
  }

  /// لسحب التحديث بالواجهة: لو ننتظر إعادة محاولة نحاول الحين بدل ما ننتظر
  /// الـ backoff، وإلا نستعلم الحالة فورًا.
  Future<void> refresh() async {
    if (_role == _Role.owner && _socket == null) {
      _backoff = _initialBackoff;
      await _connect();
      return;
    }
    await _pollOnce();
  }

  // ─── الاستطلاع الدوري (نبض الاتصال) ───────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_pollOnce()));
  }

  Future<void> _pollOnce() async {
    if (_polling) return;
    _polling = true;
    try {
      if (_role == _Role.standby) {
        final owner = IsolateNameServer.lookupPortByName(_kOwnerPortName);
        final reply = owner == null
            ? const _Reply.none()
            : await _call(owner, ['status'], const Duration(seconds: 3));
        if (!reply.ok) {
          // ردّ متأخر أو ما فيه مالك مسجّل (مثلًا بنص التسليم) ما يعني إن
          // الخدمة وقفت — نسترجع الاتصال بس لو الخدمة نفسها ما عادت شغّالة
          // (ماتت بدون 'resume').
          if (_role == _Role.standby && await _mayOpenOwnConnection()) {
            _becomeOwner();
          }
          return;
        }
        final (s, pairing) = _decodeStatusReply(reply.value);
        status.value = s;
        connected.value = s != null;
        needsPairing.value = pairing;
        return;
      }

      // حماية إضافية: لو عزلة ثانية سجّلت نفسها مالك (الخدمة استلمت)، ما
      // يصير فيه مالكَين يتناوبون على الساعة — نتنحّى.
      if (_role == _Role.owner &&
          IsolateNameServer.lookupPortByName(_kOwnerPortName) !=
              _port?.sendPort) {
        debugPrint('WatchLink: another isolate owns the watch — standing by');
        _becomeStandby();
        return;
      }

      final socket = _socket;
      if (_role != _Role.owner || socket == null || !connected.value) return;
      if (_onAudio != null) {
        if (!_audioPaused &&
            DateTime.now().difference(_lastRx) > _audioSilenceLimit) {
          _onSocketLost(socket, 'no audio for $_audioSilenceLimit');
        }
        return;
      }
      final s = await _ownerQueryStatus(const Duration(seconds: 3));
      if (s != null) {
        _missedPolls = 0;
      } else if (++_missedPolls >= 2) {
        _onSocketLost(socket, 'no status reply');
      }
    } finally {
      _polling = false;
    }
  }

  // ─── قراءة البيانات ────────────────────────────────────────────────────────

  void _onBytes(Uint8List data) {
    _lastRx = DateTime.now();
    final audio = _onAudio;
    // الصوت بس بعد ما يكتمل الاتصال (مصادقة + أول حالة). قبلها، حتى لو
    // startAudio انطلب، البيانات أسطر PAIR/AUTH/I — كانت تنقرأ كصوت
    // ("first audio packet (38 bytes)" = سطر AUTH) والمصادقة ما تكتمل.
    if (audio != null && !_audioPaused && !_inHandshake && connected.value) {
      audio(data);
      return;
    }
    _lineBuffer.addAll(data);
    var newline = _lineBuffer.indexOf(0x0A);
    while (newline != -1) {
      final line = utf8
          .decode(_lineBuffer.sublist(0, newline), allowMalformed: true)
          .trim();
      _lineBuffer.removeRange(0, newline + 1);
      if (line.isNotEmpty) _handleLine(line);
      newline = _lineBuffer.indexOf(0x0A);
    }
    // بقايا صوت بعد 's' ممكن تكون بايتات كثيرة بدون سطر جديد — ما نخليها تكبر.
    if (_lineBuffer.length > _maxLineBuffer) {
      _lineBuffer.removeRange(0, _lineBuffer.length - _maxLineBuffer);
    }
  }

  void _handleLine(String line) {
    if (_inHandshake) {
      _handshakeLines.add(line);
      _wakeHandshake();
      return;
    }
    final parsed = _parseStatus(line);
    if (parsed != null) {
      status.value = parsed;
      _statusAt = DateTime.now();
    }
    for (final waiter in List.of(_waiters)) {
      if (waiter.test(line) && !waiter.completer.isCompleted) {
        _waiters.remove(waiter);
        waiter.completer.complete(line);
      }
    }
  }

  Future<String> _waitForLine(bool Function(String) test, Duration timeout) {
    final waiter = _LineWaiter(test);
    _waiters.add(waiter);
    return waiter.completer.future
        .timeout(timeout)
        .whenComplete(() => _waiters.remove(waiter));
  }

  static WatchStatus? _parseStatus(String line) {
    final parts = line.split(',');
    if (parts.length != 4 || parts[0] != 'I') return null;
    final battery = int.tryParse(parts[2]);
    final lastSync = int.tryParse(parts[3]);
    if (battery == null || lastSync == null) return null;
    return WatchStatus(
      isConnected: parts[1] == '1',
      batteryPercent: battery,
      lastSyncSecondsAgo: lastSync,
    );
  }

  // ─── الكتابة ───────────────────────────────────────────────────────────────

  void _write(List<int> bytes) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(bytes);
    } catch (e) {
      _onSocketLost(socket, e);
    }
  }

  Future<bool> _writeAndFlush(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) return false;
    try {
      socket.add(bytes);
      await socket.flush();
      return true;
    } catch (e) {
      _onSocketLost(socket, e);
      return false;
    }
  }

  Future<bool> _waitConnected(Duration timeout) async {
    if (_socket != null && connected.value) return true;
    final done = Completer<bool>();
    void listener() {
      if (connected.value && !done.isCompleted) done.complete(true);
    }

    // لو الساعة رفضت المصادقة وقت الانتظار، ما له داعي نكمل الانتظار.
    void pairingListener() {
      if (needsPairing.value && !done.isCompleted) done.complete(false);
    }

    connected.addListener(listener);
    needsPairing.addListener(pairingListener);
    try {
      return await done.future.timeout(timeout, onTimeout: () => false);
    } finally {
      connected.removeListener(listener);
      needsPairing.removeListener(pairingListener);
    }
  }

  /// طلب/ردّ واحد بكل مرة على الاتصال، عشان ما تختلط ردود الساعة.
  Future<T> _exclusive<T>(Future<T> Function() op) async {
    final previous = _opChain;
    final done = Completer<void>();
    _opChain = done.future;
    try {
      await previous;
      return await op();
    } finally {
      done.complete();
    }
  }

  // ─── الواجهة العامة (تشتغل من أي عزلة) ──────────────────────────────────

  /// يبدأ بث الصوت الخام من الساعة على الاتصال المفتوح. لو الاتصال انقطع
  /// أثناء البث، يرجع يبدأ البث تلقائيًا بعد إعادة الاتصال.
  Future<bool> startAudio(
    void Function(Uint8List data) onData, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _onAudio = onData;
    _audioPaused = false;
    if (_socket != null && connected.value) return _writeAndFlush([0x72]);
    // _open يرسل 'r' بنفسه أول ما يتصل لأن _onAudio صار موجود.
    return _waitConnected(timeout);
  }

  Future<void> stopAudio() async {
    if (_onAudio == null) return;
    _onAudio = null;
    _audioPaused = false;
    await _writeAndFlush([0x73]); // 's'
  }

  Future<WatchStatus?> queryStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_role == _Role.owner) return _ownerQueryStatus(timeout);
    final reply = await _forward(['status'], timeout);
    if (reply.ok) return _decodeStatusReply(reply.value).$1;
    if (!await _mayOpenOwnConnection()) return null;
    return WatchAudioSocket.queryStatusOnce(
      await _savedHost(),
      timeout: timeout,
    );
  }

  Future<WatchStatus?> _ownerQueryStatus(Duration timeout) async {
    // وقت البث البيانات صوت خام، وردّ 'I,...' بينضيع بينها — نرجّع آخر
    // حالة معروفة (مع تحديث مدة الاتصال) طالما البث نفسه حي.
    if (_onAudio != null) {
      final cached = status.value;
      if (!connected.value) return null;
      if (cached == null || _statusAt == null) return cached;
      return WatchStatus(
        isConnected: cached.isConnected,
        batteryPercent: cached.batteryPercent,
        lastSyncSecondsAgo:
            cached.lastSyncSecondsAgo +
            DateTime.now().difference(_statusAt!).inSeconds,
      );
    }
    return _exclusive(() async {
      if (!await _waitConnected(timeout)) return null;
      try {
        final reply = _waitForLine((l) => l.startsWith('I,'), timeout);
        if (!await _writeAndFlush([0x69])) return null; // 'i'
        return _parseStatus(await reply);
      } catch (_) {
        return null;
      }
    });
  }

  /// '#' + رمز الفئة + رمز نمط الاهتزاز + رمز شدة الاهتزاز.
  Future<bool> sendDetectionCode(
    String code, {
    required int pattern,
    required int power,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final message = [
      0x23, // '#'
      ...code.codeUnits,
      ...pattern.toString().codeUnits,
      ...power.toString().codeUnits,
    ];
    return send(message, timeout: timeout);
  }

  Future<bool> send(
    List<int> bytes, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_role == _Role.owner) {
      if (!await _waitConnected(timeout)) return false;
      final ok = await _writeAndFlush(bytes);
      debugPrint(
        'WatchLink: ${ok ? 'sent' : 'failed to send'} "${String.fromCharCodes(bytes)}"',
      );
      return ok;
    }
    final reply = await _forward(['send', bytes], timeout);
    if (reply.ok) return reply.value == true;
    if (!await _mayOpenOwnConnection()) return false;
    return WatchAudioSocket.sendOnce(
      await _savedHost(),
      bytes,
      timeout: timeout,
    );
  }

  /// يرسل جدول التذكيرات '@' + الجدول + '\n' وينتظر ردّ الساعة `R,<count>`.
  /// لو البث شغّال نوقفه لحظيًا، لأن الردّ النصي بيضيع وسط بايتات الصوت.
  Future<int?> sendReminders(
    String payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_role != _Role.owner) {
      final reply = await _forward(['reminders', payload], timeout);
      if (reply.ok) return reply.value as int?;
      if (!await _mayOpenOwnConnection()) return null;
      return WatchAudioSocket.sendRemindersOnce(
        await _savedHost(),
        payload,
        timeout: timeout,
      );
    }
    return _exclusive(() async {
      if (!await _waitConnected(timeout)) return null;
      final pauseAudio = _onAudio != null;
      if (pauseAudio) {
        _audioPaused = true;
        _write([0x73]); // 's'
      }
      try {
        _lineBuffer.clear();
        final reply = _waitForLine((l) => l.startsWith('R,'), timeout);
        if (!await _writeAndFlush(utf8.encode('@$payload\n'))) return null;
        final count = int.tryParse((await reply).substring(2).trim());
        debugPrint('WatchLink: reminders sent — الساعة حفظت $count تذكير');
        return count;
      } catch (e) {
        debugPrint('WatchLink: reminders not acknowledged — $e');
        return null;
      } finally {
        if (pauseAudio) {
          _audioPaused = false;
          if (_onAudio != null) _write([0x72]); // 'r'
        }
      }
    });
  }

  // ─── المراسلة بين العزلات ─────────────────────────────────────────────────

  Future<void> _onPortMessage(dynamic message) async {
    if (message is! List || message.isEmpty) return;
    final command = message[0] as String;
    final replyTo = message.length > 1 && message[1] is SendPort
        ? message[1] as SendPort
        : null;
    final args = message.length > 2 ? message.sublist(2) : const [];

    switch (command) {
      case 'ping':
        replyTo?.send(true);
      case 'suspend':
        if (_role == _Role.owner) _becomeStandby();
        // ما نأكّد إلا بعد ما تخلص أي محاولة اتصال/فحص كانت شغّالة.
        try {
          await _connectFuture?.timeout(const Duration(seconds: 8));
        } catch (_) {}
        replyTo?.send(true);
      case 'resume':
        if (_role == _Role.standby) _becomeOwner();
      case 'status':
        if (_role != _Role.owner) return; // مو المالك — خلّه يوصل لمهلته
        // ردّ فوري من آخر حالة (المالك يستطلع بنفسه) — بدون انتظار اتصال،
        // عشان الواجهة ما تحسب المالك ميت لو كان بنص إعادة اتصال.
        replyTo?.send([
          _encodeStatus(
            !connected.value
                ? null
                : _onAudio != null
                ? await _ownerQueryStatus(Duration.zero) // من الذاكرة وقت البث
                : status.value,
          ),
          needsPairing.value,
        ]);
      case 'send':
        if (_role != _Role.owner) return;
        replyTo?.send(await send(List<int>.from(args[0] as List)));
      case 'reminders':
        if (_role != _Role.owner) return;
        replyTo?.send(await sendReminders(args[0] as String));
    }
  }

  Future<_Reply> _forward(List<Object?> message, Duration timeout) async {
    final owner = IsolateNameServer.lookupPortByName(_kOwnerPortName);
    if (owner == null || owner == _port?.sendPort) return const _Reply.none();
    return _call(owner, message, timeout);
  }

  static Future<_Reply> _call(
    SendPort to,
    List<Object?> message,
    Duration timeout,
  ) async {
    final replyPort = ReceivePort();
    try {
      to.send([message[0], replyPort.sendPort, ...message.skip(1)]);
      final value = await replyPort.first.timeout(timeout);
      return _Reply(value);
    } catch (_) {
      return const _Reply.none();
    } finally {
      replyPort.close();
    }
  }

  static List<int>? _encodeStatus(WatchStatus? s) => s == null
      ? null
      : [s.isConnected ? 1 : 0, s.batteryPercent, s.lastSyncSecondsAgo];

  static (WatchStatus?, bool) _decodeStatusReply(Object? raw) {
    if (raw is! List || raw.length != 2) return (null, false);
    return (_decodeStatus(raw[0]), raw[1] == true);
  }

  static WatchStatus? _decodeStatus(Object? raw) {
    if (raw is! List || raw.length != 3) return null;
    return WatchStatus(
      isConnected: raw[0] == 1,
      batteryPercent: raw[1] as int,
      lastSyncSecondsAgo: raw[2] as int,
    );
  }

  static Future<String?> _savedHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kWatchIpPrefsKey);
  }
}

class _LineWaiter {
  _LineWaiter(this.test);
  final bool Function(String) test;
  final Completer<String> completer = Completer<String>();
}

class _Reply {
  const _Reply(this.value) : ok = true;
  const _Reply.none() : ok = false, value = null;
  final bool ok;
  final Object? value;
}
