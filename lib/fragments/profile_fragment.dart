// lib/views/profile_fragment.dart

import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';
import 'package:corpsapp/views/change_user_role_view.dart';
import 'package:corpsapp/views/manage_locations_view.dart';

/// Dialog to change the user’s email.
class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({Key? key}) : super(key: key);

  @override
  __ChangeEmailDialogState createState() => __ChangeEmailDialogState();
}

class __ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final TextEditingController _ctrl = TextEditingController();

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
      title: const Text("Change Email", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "New Email",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: "you@example.com",
              hintStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text("SUBMIT", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

/// Dialog to update username, first name, and last name.
class _UpdateProfileDialog extends StatefulWidget {
  const _UpdateProfileDialog({Key? key}) : super(key: key);

  @override
  __UpdateProfileDialogState createState() => __UpdateProfileDialogState();
}

class __UpdateProfileDialogState extends State<_UpdateProfileDialog> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _firstCtrl = TextEditingController();
  final TextEditingController _lastCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black54),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Update Profile",
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildField("New Username", _userCtrl, "username"),
            const SizedBox(height: 12),
            _buildField("New First Name", _firstCtrl, "first name"),
            const SizedBox(height: 12),
            _buildField("New Last Name", _lastCtrl, "last name"),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed:
              () => Navigator.pop(context, {
                'userName': _userCtrl.text.trim(),
                'firstName': _firstCtrl.text.trim(),
                'lastName': _lastCtrl.text.trim(),
              }),
          child: const Text("UPDATE", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class ProfileFragment extends StatefulWidget {
  const ProfileFragment({Key? key}) : super(key: key);

  @override
  State<ProfileFragment> createState() => _ProfileFragmentState();
}

class _ProfileFragmentState extends State<ProfileFragment> {
  bool _isLoading = false;
  String? _emailChangeError;
  String? _generalError;

  void _showSnack(String message, {Color background = Colors.grey}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _changeEmail() async {
    final newEmail = await showDialog<String?>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
    if (newEmail == null) return;

    if (!EmailValidator.validate(newEmail)) {
      setState(() => _emailChangeError = "Enter a valid email.");
      _showSnack("Enter a valid email.", background: Colors.redAccent);
      return;
    }

    setState(() {
      _isLoading = true;
      _emailChangeError = null;
      _generalError = null;
    });

    try {
      final res = await AuthHttpClient.requestEmailChange(newEmail);
      if (res.statusCode == 200) {
        _showSnack(
          "Check your new email to confirm.",
          background: Colors.green,
        );
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = (body['message'] as String).toLowerCase();
        final err =
            msg.contains("email")
                ? "That email is already in use."
                : "Error: ${body['message']}";
        setState(() => _emailChangeError = err);
        _showSnack(err, background: Colors.redAccent);
      }
    } catch (e) {
      setState(() => _generalError = "Network error: $e");
      _showSnack("Network error: $e", background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => const _UpdateProfileDialog(),
    );
    if (result == null) return;

    final userName = result['userName']!.trim();
    final firstName = result['firstName']!.trim();
    final lastName = result['lastName']!.trim();

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthHttpClient.updateProfile(
        newUserName: userName.isEmpty ? null : userName,
        newFirstName: firstName.isEmpty ? null : firstName,
        newLastName: lastName.isEmpty ? null : lastName,
      );
      await context.read<AuthProvider>().loadUser();
      _showSnack("Profile updated.", background: Colors.green);
    } catch (e) {
      setState(() => _generalError = "Failed to update: $e");
      _showSnack("Failed to update: $e", background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final TextEditingController _confirmController = TextEditingController();
    bool ok =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return StatefulBuilder(
              builder: (context, setState) {
                final isValid =
                    _confirmController.text.trim().toLowerCase() == 'delete';
                return AlertDialog(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    "Delete Account",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Type “delete” below to permanently remove your account.\nThis action cannot be undone.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      // Styled textfield
                      TextField(
                        controller: _confirmController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'delete',
                          hintStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
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
                      child: const Text(
                        "CANCEL",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          isValid ? () => Navigator.pop(context, true) : null,
                      child: Text(
                        "DELETE",
                        style: TextStyle(
                          color:
                              isValid
                                  ? Colors.redAccent
                                  : Colors.redAccent.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
    if (!ok) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });
    try {
      await AuthHttpClient.deleteProfile();
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/landing');
    } catch (e) {
      setState(() => _generalError = "Failed to delete: $e");
      _showSnack("Failed to delete: $e", background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  "Log Out?",
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  "Are you sure?",
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "LOG OUT",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _isLoading = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/landing');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile;
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUnder16 = (user?['age'] ?? 0) < 16;
    final isAdmin = auth.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          Text(
            user?['userName'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
          Text(
            '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            user?['email'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (user?['age'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Age: ${user!['age']}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 30),
          const Text(
            "Manage your profile settings below.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          _ActionButton(
            icon: Icons.email,
            label: "CHANGE EMAIL",
            onPressed: _isLoading ? null : _changeEmail,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.edit,
            label: "UPDATE PROFILE",
            onPressed: _isLoading ? null : _updateProfile,
          ),
          if (!auth.isAdmin) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.delete,
              label: "DELETE ACCOUNT",
              onPressed: _isLoading ? null : _confirmDelete,
            ),
          ],
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.logout,
            label: "LOG OUT",
            onPressed: _isLoading ? null : _confirmLogout,
          ),
          if (!isUnder16) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.child_care,
              label: "MANAGE CHILDREN",
              onPressed: () => Navigator.pushNamed(context, '/children'),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.admin_panel_settings,
              label: "USER ROLE MANAGEMENT",
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangeUserRoleView(),
                    ),
                  ),
            ),
          ],// only admins get this extra button
          if (isAdmin) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.location_on,
              label: "MANAGE LOCATIONS",
              onPressed: _isLoading
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageLocationsView(),
                        ),
                      ),
            ),
          ],

          
          if (_emailChangeError != null) ...[
            const SizedBox(height: 20),
            Text(
              _emailChangeError!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
          if (_generalError != null) ...[
            const SizedBox(height: 20),
            Text(
              _generalError!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
