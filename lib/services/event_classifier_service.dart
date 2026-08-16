import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class EventClassificationResult {
  final String label;
  final bool shouldAlert;
  final bool fireAlarmSafetyFlag;
  final String? debugReason;

  EventClassificationResult({
    required this.label,
    required this.shouldAlert,
    required this.fireAlarmSafetyFlag,
    this.debugReason,
  });

  factory EventClassificationResult.fromJson(Map<String, dynamic> json) {
    return EventClassificationResult(
      label: json['label'] as String? ?? 'na',
      shouldAlert: json['should_alert'] == true,
      fireAlarmSafetyFlag: json['fire_alarm_safety_flag'] == true,
      debugReason: json['debug_reason'] as String?,
    );
  }
}

class EventClassifierService {
  static const String _baseUrl =
      'https://nabeeh-api-715905518635.us-central1.run.app';

  static Future<EventClassificationResult> classifyWavChunk(
    Uint8List wavBytes,
  ) async {
    final uri = Uri.parse('$_baseUrl/predict_stream');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', wavBytes, filename: 'chunk.wav'),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String detail = 'خطأ من السيرفر (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['detail'] != null) detail = body['detail'].toString();
      } catch (_) {}
      throw Exception(detail);
    }

    return EventClassificationResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
