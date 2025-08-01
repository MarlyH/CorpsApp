import 'dart:convert';

import 'package:flutter/material.dart';

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
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF4C85D0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtl,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'User Email',
        hintText: 'Enter user email',
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: Colors.white,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
          hint: const Text(
            'Select role',
            style: TextStyle(color: Colors.black54),
          ),
          items:
              _roles.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(color: Colors.black87)),
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
          backgroundColor: const Color(0xFF4C85D0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: _isLoading ? null : _changeRole,
        child:
            _isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'CHANGE ROLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Role Management',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change User Access Level',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
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
