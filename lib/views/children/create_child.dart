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
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          //my theming styles
          colorScheme: ColorScheme.dark(
            primary: Colors.grey, // header background
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
        backgroundColor: isError ? Colors.redAccent : Colors.grey,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grayscaleTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardColor: Colors.grey[900],
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[500]!),
          borderRadius: BorderRadius.circular(10),
        ),
        suffixIconColor: Colors.white70,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );

    return Theme(
      data: grayscaleTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text("Add Child")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildField(_firstName, "First Name"),
                    _buildField(_lastName, "Last Name"),
                    _buildField(
                      _dob,
                      "Date of Birth",
                      readOnly: true,
                      onTap: _selectDate,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    _buildField(_contactName, "Emergency Contact Name"),
                    _buildField(
                      _contactPhone,
                      "Emergency Contact Phone",
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : createChild,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: const Text("Save"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon,
        ),
        style: const TextStyle(color: Colors.white),
        validator: (val) => val == null || val.isEmpty ? "Required" : null,
      ),
    );
  }
}
