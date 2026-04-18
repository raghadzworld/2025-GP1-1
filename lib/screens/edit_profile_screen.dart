import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  final VoidCallback onBack;
  const EditProfileScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'تعديل الملف',
          style: TextStyle(
            color: Color(0xFF1A1A40),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF1A1A40), size: 30),
          onPressed: onBack,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildEditInput('الاسم', Icons.person_outline, 'ريم العويس'),
              const SizedBox(height: 25),
              _buildEditInput('الايميل', Icons.email_outlined, 'Reem@gmile.com'),
              const SizedBox(height: 25),
              _buildEditInput('رقم الهاتف', Icons.phone_android_outlined, '050 123 4567'),
              const SizedBox(height: 60),
              _buildSaveButton(),
              const SizedBox(height: 15),
              _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.save, color: Colors.white),
      label: const Text(
        'حفظ التغييرات',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A40),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text(
        'حذف الحساب',
        style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: Colors.red.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildEditInput(String label, IconData icon, String initialValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A40)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: initialValue),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
