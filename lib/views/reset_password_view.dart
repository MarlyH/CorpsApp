import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'reset_success_view.dart';

class ResetPasswordView extends StatefulWidget {
  final String email;
  final String resetToken;

  const ResetPasswordView({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (mounted) setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$base/api/password/reset-password');
    final body = jsonEncode({
      'email': widget.email,
      'resetPasswordToken': widget.resetToken,
      'newPassword': _newPassCtrl.text.trim(),
    });

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        // success: navigate to success screen
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResetSuccessView()),
        );
      } else {
        setState(() => _error = data['message'] ?? 'Reset failed');
      }
    } catch (_) {
      setState(() => _error = 'Server error, please try again');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ensure we avoid bottom overflow when keyboard appears
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          return SingleChildScrollView(
            padding: AppPadding.screen,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // back arrow
                    CustomBackButton(),

                    const Spacer(),

                    // lock image
                    Image.asset('assets/change_password.png', height: 360),

                    // title
                    const Text(
                      'RESET PASSWORD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'WinnerSans',
                      ),
                    ),

                    // subtitle
                    const Text(
                      'Now you can enter a new password and use it from now on.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // New password
                          InputField(
                            label: 'NEW PASSWORD', 
                            hintText: 'Enter new password', 
                            controller: _newPassCtrl,
                            obscureText: _obscureNew,
                            keyboardType: TextInputType.visiblePassword,
                            iconLook: IconButton(
                              onPressed: () => setState(() => _obscureNew = !_obscureNew), 
                              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, 
                              color: Colors.black,)),
                            ),
                            
                          const SizedBox(height: 16),

                          // Confirm password
                          InputField(
                            label: 'CONFIRM PASSWORD', 
                            hintText: 'Enter new password', 
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            keyboardType: TextInputType.visiblePassword,
                            iconLook: IconButton(
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), 
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, 
                              color: Colors.black,)),
                            ),                

                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Text(                            
                              _error!,
                              textAlign: TextAlign.left,
                              style: const TextStyle(color: AppColors.errorColor,fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                    // FINISH button
                    Button(
                      label: 'FINISH', 
                      onPressed: _finish, 
                      loading: _loading
                    ),
                    
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
