import 'dart:convert';
import 'package:flutter/material.dart';
import '/services/auth_http_client.dart';

class CreateChildView extends StatefulWidget {
  const CreateChildView({super.key});

  @override
  State<CreateChildView> createState() => _CreateChildViewState();
}

class _CreateChildViewState extends State<CreateChildView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  bool isLoading = false;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      builder:
          (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue, // header background
                onPrimary: Colors.white, // header text
                surface: Colors.black, // picker background
                onSurface: Colors.white, // picker text
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      _dob.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> createChild() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final body = {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'dateOfBirth': _dob.text.trim(),
      'emergencyContactName': _contactName.text.trim(),
      'emergencyContactPhone': _contactPhone.text.trim(),
    };

    try {
      final res = await AuthHttpClient.post('/api/child', body: body);
      if (res.statusCode == 200) {
        Navigator.pop(context);
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Unknown error';
        _showSnackBar(msg, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: isError ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Add Child',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  controller: _firstName,
                  label: 'First Name',
                  icon: Icons.person_outline,
                ),
                _buildField(
                  controller: _lastName,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                ),
                _buildField(
                  controller: _dob,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: _selectDate,
                ),
                _buildField(
                  controller: _contactName,
                  label: 'Emergency Contact Name',
                  icon: Icons.contact_phone_outlined,
                ),
                _buildField(
                  controller: _contactPhone,
                  label: 'Emergency Contact Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : createChild,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('SAVE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    ),
  );
  }
  }

