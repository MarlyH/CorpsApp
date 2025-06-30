import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';

class ProfileFragment extends StatefulWidget {
  const ProfileFragment({super.key});

  @override
  State<ProfileFragment> createState() => _ProfileFragmentState();
}

class _ProfileFragmentState extends State<ProfileFragment> {
  bool _isLoading = false;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleEmailChange() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Change Email", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "New Email",
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("SUBMIT", style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await AuthHttpClient.requestEmailChange(controller.text.trim());
        _showSnackBar("Check your new email to confirm the change.");
      } catch (e) {
        _showSnackBar("Failed: ${e.toString()}");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUpdateProfile() async {
    final usernameController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Update Profile", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "New Username",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              TextField(
                controller: firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "New First Name",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              TextField(
                controller: lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "New Last Name",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("UPDATE", style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await AuthHttpClient.updateProfile(
          newUserName: usernameController.text.trim().isNotEmpty ? usernameController.text.trim() : null,
          newFirstName: firstNameController.text.trim().isNotEmpty ? firstNameController.text.trim() : null,
          newLastName: lastNameController.text.trim().isNotEmpty ? lastNameController.text.trim() : null,
        );
        await context.read<AuthProvider>().loadUser();
        _showSnackBar("Profile updated.");
      } catch (e) {
        _showSnackBar("Failed: ${e.toString()}");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDeleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Profile", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete your account? This cannot be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await AuthHttpClient.deleteProfile();
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/landing');
      } catch (e) {
        _showSnackBar("Failed: ${e.toString()}");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                user?['userName'] ?? '',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              Text(
                '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                user?['email'] ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleEmailChange,
                    icon: const Icon(Icons.email, color: Colors.white),
                    label: const Text('Change Email'),
                    style: _buttonStyle,
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleUpdateProfile,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('Update Profile'),
                    style: _buttonStyle,
                  ),
                  if (!context.watch<AuthProvider>().isAdmin)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleDeleteProfile,
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text('Delete Profile'),
                      style: _buttonStyle.copyWith(
                        foregroundColor: MaterialStateProperty.all(Colors.redAccent),
                        side: MaterialStateProperty.all(
                            const BorderSide(color: Colors.redAccent)),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await context.read<AuthProvider>().logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/landing');
                            }
                          },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout'),
                    style: _buttonStyle,
                  ),
                ],
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );
}
