// lib/views/change_password_view.dart

import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  _ChangePasswordViewState createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl  = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _isLoading    = false;
  String? _error;

  bool _obscureOld  = true;
  bool _obscureNew  = true;
  bool _obscureConf = true;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error     = null;
      _isLoading = true;
    });

    try {
      final resp = await AuthHttpClient.post(
        '/api/password/change-password',
        body: {
          'oldPassword': _oldCtrl.text.trim(),
          'newPassword': _newCtrl.text.trim(),
        },
      );

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed'),
            backgroundColor: Colors.white,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _error = resp.body.isNotEmpty ? resp.body : 'Unknown error');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool obscureFlag,
    required VoidCallback toggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          obscureFlag ? Icons.visibility_off : Icons.visibility,
          color: Colors.black54,
        ),
        onPressed: toggle,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool obscureFlag,
    required VoidCallback toggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureFlag,
          style: const TextStyle(color: Colors.black),
          decoration: _inputDecoration(
            hint: label,
            obscureFlag: obscureFlag,
            toggle: toggle,
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.black,
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                    ],
                    _buildField(
                      label: 'Current Password',
                      controller: _oldCtrl,
                      obscureFlag: _obscureOld,
                      toggle: () => setState(() => _obscureOld = !_obscureOld),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'New Password',
                      controller: _newCtrl,
                      obscureFlag: _obscureNew,
                      toggle: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Confirm New Password',
                      controller: _confCtrl,
                      obscureFlag: _obscureConf,
                      toggle: () => setState(() => _obscureConf = !_obscureConf),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != _newCtrl.text) return 'Does not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C85D0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'UPDATE PASSWORD',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
