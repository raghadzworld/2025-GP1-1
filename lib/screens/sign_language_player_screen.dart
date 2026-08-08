import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SignLanguagePlayerScreen extends StatefulWidget {
  final String videoAsset;
  final VoidCallback onFinished;

  const SignLanguagePlayerScreen({
    super.key,
    required this.videoAsset,
    required this.onFinished,
  });

  @override
  State<SignLanguagePlayerScreen> createState() =>
      _SignLanguagePlayerScreenState();
}

class _SignLanguagePlayerScreenState extends State<SignLanguagePlayerScreen> {
  late final VideoPlayerController _controller;
  bool _proceeded = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAsset)
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  void _onTick() {
    final value = _controller.value;
    if (!_proceeded &&
        value.isInitialized &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _proceed();
    }
  }

  void _proceed() {
    if (_proceeded || !mounted) return;
    _proceeded = true;
    Navigator.of(context).pop();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_controller.value.isInitialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            else
              const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: _proceed,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
