import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/auth_http_client.dart';

class ChangeUserRoleView extends StatefulWidget {
  const ChangeUserRoleView({super.key});

  @override
  State<ChangeUserRoleView> createState() => _ChangeUserRoleViewState();
}

class _ChangeUserRoleViewState extends State<ChangeUserRoleView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  static const _roles = ['Admin', 'Event Manager', 'Staff', 'User'];

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _changeRole() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) return;
    setState(() => _isLoading = true);

    try {
      final resp = await AuthHttpClient.changeUserRole(
        email: _emailCtl.text.trim(),
        role: _selectedRole!,
      );

      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      _showSnack(
        body?['message'] ??
            (resp.statusCode == 200
                ? 'Role changed successfully'
                : 'Failed (${resp.statusCode})'),
        isError: resp.statusCode != 200,
      );

      if (resp.statusCode == 200) {
        _emailCtl.clear();
        setState(() => _selectedRole = null);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: isError ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtl,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'User Email',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Email is required';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildRoleDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Select Role',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: Colors.black,
          isExpanded: true,
          iconEnabledColor: Colors.white,
          hint: const Text('Choose role', style: TextStyle(color: Colors.white54)),
          items: _roles.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Text(r, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedRole = v),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _isLoading ? null : _changeRole,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Change Role', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change User Role'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildEmailField(),
                const SizedBox(height: 24),
                _buildRoleDropdown(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
