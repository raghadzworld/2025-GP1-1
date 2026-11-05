import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// ارتفاع بوكس لغة الإشارة — غيّره من هنا وينطبق على كل الصفحات
const double kSignVideoCardHeight = 300;

const Color _navy = Color(0xFF181059);
const Color _cardBorder = Color(0xFFA4ACB0);

// ═════════════════════════════════════════════════════════════════════════════
//  الفيديو نفسه + زر التكبير (بدون إطار ولا زر إغلاق)
// ═════════════════════════════════════════════════════════════════════════════
class SignVideoView extends StatefulWidget {
  final String videoAsset;

  const SignVideoView({super.key, required this.videoAsset});

  @override
  State<SignVideoView> createState() => _SignVideoViewState();
}

class _SignVideoViewState extends State<SignVideoView> {
  late final VideoPlayerController _video;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset(widget.videoAsset);
    _init();
  }

  Future<void> _init() async {
    try {
      await _video.initialize();
      await _video.setLooping(true);
      await _video.setVolume(0);
      await _video.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // الفيديو ما اشتغل — يبقى مؤشر التحميل
    }
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    if (!_ready) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _SignVideoFullscreen(controller: _video),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _navy),

        // لمسة على الفيديو = تكبير
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openFullscreen,
          child: _ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: VideoPlayer(_video),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
        ),

        // زر تكبير المقطع (أيقونة + كلمة)
        if (_ready)
          PositionedDirectional(
            top: 8,
            start: 8,
            child: GestureDetector(
              onTap: _openFullscreen,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: _navy.withValues(alpha: 0.85),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'تكبير',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  بوكس كامل: إطار + فيديو + زر تكبير + زر إغلاق
// ═════════════════════════════════════════════════════════════════════════════
class SignVideoCard extends StatelessWidget {
  final String videoAsset;
  final VoidCallback onClose;

  const SignVideoCard({
    super.key,
    required this.videoAsset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: kSignVideoCardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SignVideoView(videoAsset: videoAsset),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _navy.withValues(alpha: 0.85),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  شاشة التكبير: لمسة = إيقاف/تشغيل، زر تدوير، زر رجوع، شريط تقدم
// ═════════════════════════════════════════════════════════════════════════════
class _SignVideoFullscreen extends StatefulWidget {
  final VideoPlayerController controller;

  const _SignVideoFullscreen({required this.controller});

  @override
  State<_SignVideoFullscreen> createState() => _SignVideoFullscreenState();
}

class _SignVideoFullscreenState extends State<_SignVideoFullscreen> {
  late bool _landscape;

  @override
  void initState() {
    super.initState();
    // إذا الفيديو عريض نفتحه أفقي تلقائيًا
    _landscape = widget.controller.value.aspectRatio > 1;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyOrientation();
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _landscape
          ? [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
  }

  @override
  void dispose() {
    // نرجّع الوضع الطبيعي للتطبيق
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _togglePlay() {
    final c = widget.controller;
    c.value.isPlaying ? c.pause() : c.play();
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.55),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),

            // أيقونة التشغيل تظهر لما يكون الفيديو واقف
            IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (_, value, __) => AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // شريط التقدم
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),

            // زر الرجوع من التكبير
            PositionedDirectional(
              top: 12,
              end: 16,
              child: _circleButton(
                icon: Icons.fullscreen_exit_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            // زر تدوير الشاشة (أفقي ⇄ عمودي)
            PositionedDirectional(
              top: 12,
              start: 16,
              child: _circleButton(
                icon: Icons.screen_rotation_rounded,
                onTap: _toggleOrientation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}