import 'package:cloud_functions/cloud_functions.dart';

class EmailService {
  static final _functions = FirebaseFunctions.instance;

  static Future<void> sendPasswordReset(String email) async {
    await _functions
        .httpsCallable('sendCustomPasswordReset')
        .call({'email': email});
  }

  static Future<void> sendVerifyNewEmail(String newEmail) async {
    await _functions
        .httpsCallable('sendVerifyNewEmail')
        .call({'newEmail': newEmail});
  }

  static Future<void> sendWelcomeEmail(String email, String displayName) async {
    await _functions
        .httpsCallable('sendWelcomeEmail')
        .call({'email': email, 'displayName': displayName});
  }

  static Future<void> sendSosEmail({
    required List<String> emails,
    double? latitude,
    double? longitude,
  }) async {
    await _functions.httpsCallable('sendSosEmail').call({
      'emails': emails,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }
}
