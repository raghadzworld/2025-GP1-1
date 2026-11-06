import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/location_trigger_model.dart';
import '../services/sign_language_mode.dart';
import '../widgets/sign_video_card.dart';
import 'nabeeh_colors.dart';

const _kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _kAppPackage = 'com.example.nabbeh';
const _kFallbackCenter = LatLng(24.7136, 46.6753); // الرياض

/// خريطة صغيرة غير تفاعلية تعرض المكان ونطاقه (تُستخدم بشاشة المجموعة)
class LocationPreviewMap extends StatelessWidget {
  final LocationTriggerModel trigger;

  const LocationPreviewMap({super.key, required this.trigger});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(trigger.latitude, trigger.longitude);
    return FlutterMap(
      key: ValueKey(
        '${trigger.latitude},${trigger.longitude},'
        '${trigger.radiusMeters}',
      ),
      options: MapOptions(
        initialCenter: point,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _kOsmTileUrl,
          userAgentPackageName: _kAppPackage,
        ),
        _radiusLayer(point, trigger.radiusMeters),
        _pinLayer(point),
      ],
    );
  }
}

Widget _radiusLayer(LatLng point, double radius) => CircleLayer(
  circles: [
    CircleMarker(
      point: point,
      radius: radius,
      useRadiusInMeter: true,
      color: NabeehColors.green.withValues(alpha: 0.18),
      borderColor: NabeehColors.green,
      borderStrokeWidth: 2,
    ),
  ],
);

Widget _pinLayer(LatLng point) => MarkerLayer(
  markers: [
    Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(
        Icons.location_pin,
        color: NabeehColors.darkBlue,
        size: 44,
      ),
    ),
  ],
);

/// شاشة اختيار المكان: المستخدم يحرّك الخريطة والدبوس ثابت بالنص، أو يضغط
/// على أي نقطة، ويحدد نطاق المكان. ترجّع LocationTriggerModel مفعّل.
class LocationPickerScreen extends StatefulWidget {
  final LocationTriggerModel? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  late LatLng _selected;
  late double _radius;
  bool _locating = false;

  // رسالة الخطأ (تظهر تحت الشاشة بدون ما تغطي اللوحة)
  bool _showingMessage = false;
  String _messageText = '';
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _selected = initial == null
        ? _kFallbackCenter
        : LatLng(initial.latitude, initial.longitude);
    _radius = initial?.radiusMeters ?? LocationTriggerModel.defaultRadiusMeters;
    // مكان جديد: نبدأ من موقع المستخدم الحالي
    if (initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('ما قدرنا نوصل لموقعك — اختر المكان من الخريطة');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('خدمة الموقع (GPS) مقفلة في الجوال');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = here);
      _mapController.move(here, 17);
    } catch (_) {
      _showMessage('تعذّر تحديد موقعك الحالي');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() {
      _messageText = text;
      _showingMessage = true;
    });
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showingMessage = false);
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      LocationTriggerModel(
        isEnabled: true,
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        radiusMeters: _radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
              stops: [0.0, 0.35, 0.6],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context),

              // بوكس فيديو لغة الإشارة — خارج بطاقة الخريطة (يظهر فقط عند التفعيل)
              ValueListenableBuilder<bool>(
                valueListenable: signLanguageModeNotifier,
                builder: (context, isActive, _) => AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isActive
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: SignVideoCard(
                            key: const ValueKey('sign_location_card'),
                            videoAsset: 'assets/videos/sign_location.mp4',
                            onClose: () =>
                                signLanguageModeNotifier.value = false,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),

              // بطاقة الخريطة تاخذ المساحة المتبقية
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: NabeehColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: _buildMapArea(),
                    ),
                  ),
                ),
              ),

              // رسالة الخطأ: تحت، والخريطة واللوحة فوقها
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.bottomCenter,
                child: _showingMessage
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          bottomSafe + 16,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFF4D4D),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _messageText,
                                  style: const TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD32F2F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: bottomSafe + 12,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── الهيدر الموحّد (زر رجوع + عنوان + أيقونة لغة الإشارة) ──────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF181059),
                      width: 1.5,
                    ),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF181059),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'اختر الموقع',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: signLanguageModeNotifier,
            builder: (context, isActive, _) => GestureDetector(
              onTap: () => signLanguageModeNotifier.value = !isActive,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF0B4D2C),
                            Color(0xFF0B4D2C),
                            NabeehColors.green,
                          ],
                          stops: [0.09, 0.30, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            NabeehColors.darkNavy,
                            NabeehColors.darkNavy,
                            NabeehColors.lightBlue,
                          ],
                          stops: [0.09, 0.30, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/icon_signLan.png',
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── الخريطة + العناصر فوقها ────────────────────────────────────────────────
  Widget _buildMapArea() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selected,
            initialZoom: widget.initial == null ? 12 : 16,
            onTap: (_, point) => setState(() => _selected = point),
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) setState(() => _selected = camera.center);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _kOsmTileUrl,
              userAgentPackageName: _kAppPackage,
            ),
            _radiusLayer(_selected, _radius),
            _pinLayer(_selected),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),

        // زر موقعي (أعلى الخريطة)
        Positioned(
          top: 12,
          left: 12,
          child: GestureDetector(
            onTap: _locating ? null : _goToMyLocation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF181059),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _locating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NabeehColors.darkNavy,
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: NabeehColors.darkNavy,
                      size: 22,
                    ),
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _buildBottomPanel(),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NabeehColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حرّك الخريطة أو اضغط على المكان',
              style: TextStyle(fontSize: 14, color: NabeehColors.slate500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  LucideIcons.radar,
                  size: 18,
                  color: NabeehColors.darkBlue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'نطاق المكان',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.darkBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_radius.round()} م',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.darkBlue,
                  ),
                ),
              ],
            ),
            Slider(
              value: _radius,
              min: 50,
              max: 500,
              divisions: 9,
              activeColor: NabeehColors.darkNavy,
              inactiveColor: NabeehColors.gray.withValues(alpha: 0.35),
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 4),
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF181059), Color(0xFF1773CF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: TextButton.icon(
                onPressed: _confirm,
                icon: const Icon(
                  LucideIcons.mapPin,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'تأكيد الموقع',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
