// lib/views/account_security_view.dart

import 'dart:convert';

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
  String? _emailError;

  void _showSnack(String msg, {Color bg = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
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
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _SingleFieldDialog(
        title: title,
        initial: initial,
        hint: hint,
        isEmail: false,
      ),
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

  Future<void> _changeEmail() async {
    final auth = context.read<AuthProvider>();
    final current = auth.userProfile?['email'] as String? ?? '';
    final newEmail = await showDialog<String?>(
      context: context,
      builder: (_) => _SingleFieldDialog(
        title: 'Change Email',
        initial: current,
        hint: 'you@example.com',
        isEmail: true,
      ),
    );
    if (newEmail == null || newEmail.trim() == current.trim()) return;

    if (!EmailValidator.validate(newEmail)) {
      setState(() => _emailError = "Enter a valid email");
      _showSnack("Enter a valid email");
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      final res = await AuthHttpClient.requestEmailChange(newEmail.trim());
      if (res.statusCode == 200) {
        _showSnack("Check your new email to confirm", bg: Colors.green);
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'Unknown error';
        setState(() => _emailError = msg);
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack("Network error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (_) => const _DeleteConfirmDialog(),
    ) ?? false;
    if (!ok) return;

    setState(() => _isLoading = true);
    try {
      await AuthHttpClient.deleteProfile();
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/landing');
    } catch (e) {
      _showSnack("Delete failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Account & Security'),
            titleTextStyle: const TextStyle(
              fontFamily: 'WinnerSans',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ───── Info Card ─────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildTile(
                          label: 'First Name',
                          value: user['firstName'] as String? ?? '',
                          onTap: () => _editField(
                            title: 'First Name',
                            initial: user['firstName'] as String? ?? '',
                            hint: 'new first name',
                            onSubmit: (v) =>
                                AuthHttpClient.updateProfile(newFirstName: v),
                          ),
                          showArrow: true,
                        ),
                        _divider(),
                        _buildTile(
                          label: 'Last Name',
                          value: user['lastName'] as String? ?? '',
                          onTap: () => _editField(
                            title: 'Last Name',
                            initial: user['lastName'] as String? ?? '',
                            hint: 'new last name',
                            onSubmit: (v) =>
                                AuthHttpClient.updateProfile(newLastName: v),
                          ),
                          showArrow: true,
                        ),
                        _divider(),
                        _buildTile(
                          label: 'Username',
                          value: user['userName'] as String? ?? '',
                          onTap: () => _editField(
                            title: 'Username',
                            initial: user['userName'] as String? ?? '',
                            hint: 'new username',
                            onSubmit: (v) =>
                                AuthHttpClient.updateProfile(newUserName: v),
                          ),
                          showArrow: true,
                        ),
                        _divider(),
                        _buildTile(
                          label: 'Email',
                          value: user['email'] as String? ?? '',
                          onTap: _changeEmail,
                          showArrow: true,
                          errorText: _emailError,
                        ),
                        _divider(),
                        _buildTile(
                          label: 'Age',
                          value: (user['age']?.toString() ?? ''),
                        ),
                        _divider(),
                        // _buildTile(
                        //   label: 'Location',
                        //   value: user['location'] as String? ?? '',
                        //   onTap: () {
                        //     // TODO: push a real LocationPickerView
                        //   },
                        //   showArrow: true,
                        // ),
                        // _divider(),
                        _buildTile(
                          label: 'Password',
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

                  const SizedBox(height: 24),

                  // only non-admins can delete
                  if (!isAdmin)
                    TextButton(
                      onPressed: _confirmDelete,
                      child: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
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
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      subtitle: errorText != null
          ? Text(errorText, style: const TextStyle(color: Colors.redAccent))
          : null,
      trailing: showArrow
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white30),
              ],
            )
          : Text(value, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _divider() => const Divider(
        color: Colors.white24,
        height: 1,
        indent: 16,
        endIndent: 16,
      );
}

/// A simple dialog for editing a single field.
class _SingleFieldDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String hint;
  final bool isEmail;
  const _SingleFieldDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
    this.isEmail = false,
  });

  @override
  __SingleFieldDialogState createState() => __SingleFieldDialogState();
}

class __SingleFieldDialogState extends State<_SingleFieldDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        keyboardType: widget.isEmail
            ? TextInputType.emailAddress
            : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('SUBMIT', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

/// A delete‐confirmation dialog that only enables DELETE once you type “DELETE”.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({super.key});
  @override
  __DeleteConfirmDialogState createState() => __DeleteConfirmDialogState();
}

class __DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _ctrl.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Delete Account", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type “delete” to confirm permanent removal.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'delete',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.pop(context, true) : null,
          child: Text(
            "DELETE",
            style: TextStyle(
              color: isValid
                  ? Colors.redAccent
                  : Colors.redAccent.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }
}
