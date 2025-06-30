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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleEmailChange() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Email"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: "New Email"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Submit")),
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
        title: const Text("Update Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: "New Username")),
            TextField(controller: firstNameController, decoration: const InputDecoration(labelText: "New First Name")),
            TextField(controller: lastNameController, decoration: const InputDecoration(labelText: "New Last Name")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Update")),
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
        title: const Text("Delete Profile"),
        content: const Text("Are you sure you want to delete your account? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
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

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 100, color: Colors.white),
          const SizedBox(height: 16),

          Text(user?['userName'] ?? '', style: const TextStyle(fontSize: 18, color: Colors.white)),
          Text('${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(user?['email'] ?? '', style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleEmailChange,
            icon: const Icon(Icons.email),
            label: const Text('Change Email'),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleUpdateProfile,
            icon: const Icon(Icons.edit),
            label: const Text('Update Profile'),
          ),
          if (!context.watch<AuthProvider>().isAdmin)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleDeleteProfile,
              icon: const Icon(Icons.delete),
              label: const Text('Delete Profile'),
            ),
          ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/landing');
                    }
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}


}
