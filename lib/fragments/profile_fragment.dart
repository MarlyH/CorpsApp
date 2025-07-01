import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:email_validator/email_validator.dart';

import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';

class ProfileFragment extends StatefulWidget {
  const ProfileFragment({super.key});

  @override
  State<ProfileFragment> createState() => _ProfileFragmentState();
}

class _ProfileFragmentState extends State<ProfileFragment> {
  bool _isLoading = false;
  String? _emailChangeError;

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.grey[900],
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _handleEmailChange() async {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() => _emailChangeError = null);

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Change Email",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "New Email",
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("SUBMIT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final newEmail = controller.text.trim();
    if (!EmailValidator.validate(newEmail)) {
      setState(() => _emailChangeError = "Please enter a valid email address.");
      _showSnackBar("Please enter a valid email address.",
          backgroundColor: Colors.redAccent);
      return;
    }

    setState(() {
      _isLoading = true;
      _emailChangeError = null;
    });

    try {
      final http.Response resp =
          await AuthHttpClient.requestEmailChange(newEmail);

      if (resp.statusCode == 200) {
        _showSnackBar("Check your new email to confirm the change.",
            backgroundColor: Colors.green);
      } else if (resp.statusCode == 400) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = (body['message'] as String).toLowerCase();
        if (msg.contains("email")) {
          setState(() => _emailChangeError =
              "That email address is already in use.");
          _showSnackBar("That email address is already in use.",
              backgroundColor: Colors.redAccent);
        } else {
          setState(() => _emailChangeError = "Error: ${body['message']}");
          _showSnackBar("Error: ${body['message']}",
              backgroundColor: Colors.redAccent);
        }
      } else if (resp.statusCode == 401) {
        _showSnackBar("Session expired. Please log in again.",
            backgroundColor: Colors.orangeAccent);
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/landing');
      } else {
        setState(() =>
            _emailChangeError = "Unexpected error (${resp.statusCode}).");
        _showSnackBar("Unexpected error (${resp.statusCode})",
            backgroundColor: Colors.redAccent);
      }
    } catch (e) {
      setState(() =>
          _emailChangeError = "Network error: ${e.toString()}");
      _showSnackBar("Network error: ${e.toString()}",
          backgroundColor: Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateProfile() async {
    final usernameCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Update Profile",
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(
                  controller: usernameCtrl, label: "New Username"),
              const SizedBox(height: 8),
              _buildTextField(
                  controller: firstNameCtrl, label: "New First Name"),
              const SizedBox(height: 8),
              _buildTextField(
                  controller: lastNameCtrl, label: "New Last Name"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("UPDATE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await AuthHttpClient.updateProfile(
        newUserName: usernameCtrl.text.trim().isNotEmpty
            ? usernameCtrl.text.trim()
            : null,
        newFirstName: firstNameCtrl.text.trim().isNotEmpty
            ? firstNameCtrl.text.trim()
            : null,
        newLastName: lastNameCtrl.text.trim().isNotEmpty
            ? lastNameCtrl.text.trim()
            : null,
      );
      await context.read<AuthProvider>().loadUser();
      _showSnackBar("Profile updated.", backgroundColor: Colors.green);
    } catch (e) {
      _showSnackBar("Failed: ${e.toString()}",
          backgroundColor: Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Profile",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete your account? This cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await AuthHttpClient.deleteProfile();
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/landing');
    } catch (e) {
      _showSnackBar("Failed: ${e.toString()}",
          backgroundColor: Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.person, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(user?['userName'] ?? '',
                  style: const TextStyle(
                      fontSize: 18, color: Colors.white70)),
              Text('${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(user?['email'] ?? '',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : _handleEmailChange,
                    icon: const Icon(Icons.email, color: Colors.white),
                    label: const Text('Change Email'),
                    style: _buttonStyle,
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : _handleUpdateProfile,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('Update Profile'),
                    style: _buttonStyle,
                  ),
                  if (!isAdmin)
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _handleDeleteProfile,
                      icon: const Icon(Icons.delete,
                          color: Colors.redAccent),
                      label: const Text('Delete Profile'),
                      style: _buttonStyle.copyWith(
                        foregroundColor:
                            MaterialStateProperty.all(Colors.redAccent),
                        side: MaterialStateProperty.all(
                            const BorderSide(color: Colors.redAccent)),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await context
                                .read<AuthProvider>()
                                .logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/landing');
                            }
                          },
                    icon: const Icon(Icons.logout,
                        color: Colors.white),
                    label: const Text('Logout'),
                    style: _buttonStyle,
                  ),
                ],
              ),

              if (_emailChangeError != null) ...[
                const SizedBox(height: 12),
                Text(_emailChangeError!,
                    style:
                        const TextStyle(color: Colors.redAccent)),
              ],

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );
}
