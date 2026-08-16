import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/watch_audio_socket.dart';

/// يعرض حوار إدخال/تعديل عنوان IP الخاص بالساعة، ويحفظه في SharedPreferences
/// عند الضغط على "حفظ". يرجع العنوان الجديد، أو null لو أُلغي.
Future<String?> promptForWatchIp(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final currentIp = prefs.getString(kWatchIpPrefsKey);
  final controller = TextEditingController();

  if (!context.mounted) return null;

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.watch, color: Color(0xFF181059)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'عنوان IP الخاص بالساعة',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.left,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: Color(0xFF181059),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: currentIp ?? '192.168.1.23',
              hintStyle: const TextStyle(color: Color(0xFFA4ACB0), fontSize: 15),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1773CF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF181059), Color(0xFF1773CF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text.trim()),
                    style: TextButton.styleFrom(
                      fixedSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.save, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'حفظ',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(50),
                    side: const BorderSide(
                      color: Color.fromARGB(255, 200, 198, 195),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, color: Colors.grey, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  if (result != null && result.isNotEmpty) {
    await prefs.setString(kWatchIpPrefsKey, result);
    return result;
  }
  return null;
}
