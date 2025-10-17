// lib/views/change_password_view.dart

import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
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

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

Future<void> _submit() async {
  // Immediately clear previous server error
  if (mounted) {
    setState(() {
      _error = null;
      _isLoading = true;
    });
  }

  // Validate form fields
  if (!_formKey.currentState!.validate()) {
    if (mounted) setState(() => _isLoading = false);
    return;
  }

  try {
    final resp = await AuthHttpClient.post(
      '/api/password/change-password',
      body: {
        'oldPassword': _oldCtrl.text.trim(),
        'newPassword': _newCtrl.text.trim(),
      },
    );

    if (resp.statusCode == 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed'),
          backgroundColor: Colors.white,
        ),
      );
      Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() {
          _error = resp.body.isNotEmpty ? resp.body : 'Unknown error';
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
      });
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Change Password'),
      body: Padding(
        padding: AppPadding.screen,
        child: Form(
                key: _formKey,
                child: Column(
                  children: [                  
                    InputField(
                      label: 'Current Password', 
                      hintText: 'Enter your current password', 
                      controller: _oldCtrl,
                      isPassword: true,
                    ),

                    const SizedBox(height: 16),

                    InputField(
                      label: 'New Password', 
                      hintText: 'Enter a new password', 
                      controller: _newCtrl,
                      isPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),

                    InputField(
                      label: 'Confirm New Password', 
                      hintText: 'Re-enter new password', 
                      controller: _confCtrl,
                      isPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != _newCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Text(
                        _error!, 
                        style: const TextStyle(color: AppColors.errorColor)
                        ),
                      const SizedBox(height: 16),
                    ],

                    Button(
                      label: 'Change Password', 
                      onPressed: _submit,
                      loading: _isLoading,
                    ),               
                  ],
                ),
              ),          
      )      
    );
  }
}
