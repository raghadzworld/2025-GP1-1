import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/location_trigger_model.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'اختر الموقع',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: NabeehColors.dark,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: NabeehColors.dark,
          elevation: 0,
        ),
        body: Stack(
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
            Positioned(
              top: 16,
              left: 16,
              child: FloatingActionButton.small(
                heroTag: 'my-location',
                backgroundColor: Colors.white,
                onPressed: _locating ? null : _goToMyLocation,
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.my_location,
                        color: NabeehColors.darkBlue,
                      ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                    color: NabeehColors.dark,
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
              activeColor: NabeehColors.darkBlue,
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NabeehColors.darkBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'تأكيد الموقع',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
