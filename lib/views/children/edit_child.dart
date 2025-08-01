import 'dart:convert';
import 'package:flutter/material.dart';
import '/models/child_model.dart';
import '/services/auth_http_client.dart';

class EditChildView extends StatefulWidget {
  final ChildModel child;
  const EditChildView({super.key, required this.child});

  @override
  State<EditChildView> createState() => _EditChildViewState();
}

class _EditChildViewState extends State<EditChildView> {
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _dob;
  late TextEditingController _contactName;
  late TextEditingController _contactPhone;
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.child.firstName);
    _lastName = TextEditingController(text: widget.child.lastName);
    _dob = TextEditingController(text: widget.child.dateOfBirth);
    _contactName = TextEditingController(
      text: widget.child.emergencyContactName,
    );
    _contactPhone = TextEditingController(
      text: widget.child.emergencyContactPhone,
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> updateChild() async {
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
      final res = await AuthHttpClient.put(
        '/api/child/${widget.child.childId}',
        body: body,
      );
      if (res.statusCode == 200) {
        Navigator.pop(context);
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Unknown error';
        _showSnackBar(msg, isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: isError ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> deleteChild() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text(
              'Delete Child',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this child? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      final res = await AuthHttpClient.delete(
        '/api/child/${widget.child.childId}',
      );
      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Unknown error';
        _showSnackBar(msg, isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Edit Child',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : deleteChild,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  controller: _firstName,
                  label: 'First Name',
                  icon: Icons.person_outline,
                ),
                _buildField(
                  controller: _lastName,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                ),
                _buildField(
                  controller: _dob,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  isDisabled: true,
                ),
                _buildField(
                  controller: _contactName,
                  label: 'Emergency Contact Name',
                  icon: Icons.contact_phone_outlined,
                ),
                _buildField(
                  controller: _contactPhone,
                  label: 'Emergency Contact Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : updateChild,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('UPDATE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    bool isDisabled = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(color: Colors.black),
            enabled: !isDisabled,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: isDisabled ? Colors.black38 : Colors.black54,
              ),
              filled: true,
              fillColor: isDisabled ? Colors.grey.shade200 : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator:
                (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
