// lib/views/account_security_view.dart

import 'dart:convert';

import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/Modals/edit_modal.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';
import 'change_password_view.dart';

class AccountSecurityView extends StatefulWidget {
  const AccountSecurityView({super.key});

  @override
  _AccountSecurityViewState createState() => _AccountSecurityViewState();
}

class _AccountSecurityViewState extends State<AccountSecurityView> {
  bool _isLoading = false;

  void _showSnack(String msg, {Color bg = AppColors.errorColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editField({
    required String title,
    required String initial,
    required String hint,
    required Future<void> Function(String) onSubmit,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsetsGeometry.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleFieldDialog(
          title: title,
          initial: initial,
          hint: hint,
        ),
      )     
    );
    if (result == null || result.trim() == initial.trim()) return;

    setState(() => _isLoading = true);
    try {
      await onSubmit(result.trim());
      await context.read<AuthProvider>().loadUser();
      _showSnack('$title updated', bg: Colors.green);
    } catch (e) {
      _showSnack('Failed to update: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // keyboard-safe
      backgroundColor: Colors.transparent,
      builder: (_) => const _DeleteConfirmSheet(),
    ) ??
    false;

    if (!ok) return;

    setState(() => _isLoading = true);
    try {
      await AuthHttpClient.deleteProfile();
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/landing');
    } catch (e) {
      _showSnack("Delete failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Account & Security'),
        titleTextStyle: const TextStyle(
          fontFamily: 'WinnerSans',
          fontSize: 16,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 24, 
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: AppPadding.screen,
              child: Column(
                children: [
                  // ───── Info Card ─────────
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF242424),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildTile(
                                label: 'First Name',
                                value: user['firstName'] as String? ?? '',                         
                              ),

                              _divider(),

                              _buildTile(
                                label: 'Last Name',
                                value: user['lastName'] as String? ?? '',                         
                              ),

                              _divider(),

                              _buildTile(
                                label: 'Username',
                                value: user['userName'] as String? ?? '',                        
                              ),

                              _divider(),

                              _buildTile(
                                label: 'Email',
                                value: user['email'] as String? ?? '',
                                showArrow: false,
                              ),

                              _divider(),

                              _buildTile(
                                label: 'Phone',
                                value: user['phoneNumber'] as String? ?? '',
                                onTap: () => _editField(
                                  title: 'Phone',
                                  initial: user['phoneNumber'] as String? ?? '',
                                  hint: 'e.g. 0211234567',
                                  onSubmit: (v) => AuthHttpClient.updateProfile(
                                    newPhoneNumber: v,
                                  ),
                                ),
                                showArrow: true,
                              ),

                              _divider(),

                              _buildTile(
                                label: 'Age',
                                value: (user['age']?.toString() ?? ''),
                              ),                       
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF242424),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildTile(
                                label: 'Change Password',
                                value: '●●●●●●●●',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ChangePasswordView()),
                                ),
                                showArrow: true,
                              ),
                            ],
                          ),
                        ),           
                      ],
                    ),                   
                  ),     
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF242424),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isAdmin) ... [
                          TextButton(
                            onPressed: _confirmDelete,
                            child: const Text(
                              'Delete Account',
                              style: TextStyle(color: AppColors.errorColor, fontSize: 16, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ), 

                  const SizedBox(height: 32)          
                ],
              ),
            ),
    );
  }

  Widget _buildTile({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showArrow = false,
    String? errorText,
  }) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: errorText != null
        ? Text(errorText, style: const TextStyle(color: AppColors.errorColor, fontSize: 16))
        : null,
      trailing: showArrow
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          )
        : Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _divider() => const Divider(
    color: Colors.white24,
    height: 0,
    indent: 16,
    endIndent: 16,
  );
}

/// Bottom-sheet delete confirmation (keyboard-safe, tidy)
class _DeleteConfirmSheet extends StatefulWidget {
  const _DeleteConfirmSheet({super.key});

  @override
  State<_DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<_DeleteConfirmSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom; // keyboard height
    final isValid = _ctrl.text.trim().toUpperCase() == 'DELETE';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [             
                // header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),               
                  ],
                ),

                const SizedBox(height: 4),

                // scrollable body in case of small screens
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Type “delete” to confirm permanent account deletion.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _ctrl,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 16, color: AppColors.normalText, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // actions
                Button(
                  label: 'Delete', 
                  onPressed: isValid ? () => Navigator.pop(context, true) : null,
                  buttonColor: isValid
                    ? Colors.redAccent
                    : Colors.redAccent.withOpacity(0.4),
                ),                                                                        
              ],
            ),
          ),
        ),
      ),
    );
  }
}
