import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';
import 'package:corpsapp/views/change_user_role_view.dart';

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
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _changeEmail() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text("Change Email", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "New Email",
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SUBMIT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true) return;

    final email = ctrl.text.trim();
    if (!EmailValidator.validate(email)) {
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
      final res = await AuthHttpClient.requestEmailChange(email);
      if (res.statusCode == 200) {
        _showSnack("Check your new email to confirm.", background: Colors.green);
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = (body['message'] as String).toLowerCase();
        final err = msg.contains("email")
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
    final userCtrl  = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl  = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text("Update Profile", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _dialogField(userCtrl, "New Username"),
              const SizedBox(height: 8),
              _dialogField(firstCtrl, "New First Name"),
              const SizedBox(height: 8),
              _dialogField(lastCtrl, "New Last Name"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("UPDATE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    userCtrl.dispose();
    firstCtrl.dispose();
    lastCtrl.dispose();
    if (ok != true) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthHttpClient.updateProfile(
        newUserName:  userCtrl.text.trim().isEmpty ? null : userCtrl.text.trim(),
        newFirstName: firstCtrl.text.trim().isEmpty ? null : firstCtrl.text.trim(),
        newLastName:  lastCtrl.text.trim().isEmpty ? null : lastCtrl.text.trim(),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text("Delete Profile", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthHttpClient.deleteProfile(); // DELETE /api/profile/me
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Log Out?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("LOG OUT", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isLoading = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/landing');
  }

  Widget _dialogField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final user      = auth.userProfile;
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUnder16 = (user?['age'] ?? 0) < 16;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.person, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          Text(user?['userName'] ?? '',
              style: const TextStyle(fontSize: 18, color: Colors.white70)),
          Text(
            '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(user?['email'] ?? '',
              style: const TextStyle(color: Colors.grey)),
          if (user?['age'] != null) ...[
            const SizedBox(height: 8),
            Text('Age: ${user!['age']}', style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 30),
          const Text(
            "Manage your profile settings below.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Actions
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

          // Only show if user is under 16
          if (!auth.isAdmin) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.delete,
              label: "DELETE PROFILE",
              onPressed: _isLoading ? null : _confirmDelete,
            ),
          ],
            
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.logout,
            label: "LOG OUT",
            onPressed: _isLoading ? null : _confirmLogout,
          ),

          // Children management (for >=16)
          if (!isUnder16) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.child_care,
              label: "MANAGE CHILDREN",
              onPressed: () => Navigator.pushNamed(context, '/children'),
            ),
          ],

          // Role management (admin/eventManager only)
          if (canManage) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.admin_panel_settings,
              label: "USER ROLE MANAGEMENT",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangeUserRoleView()),
              ),
            ),
          ],

          // Error displays
          if (_emailChangeError != null) ...[
            const SizedBox(height: 20),
            Text(_emailChangeError!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center),
          ],
          if (_generalError != null) ...[
            const SizedBox(height: 20),
            Text(_generalError!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center),
          ],

          // Loading spinner
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
  Widget build(BuildContext c) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
