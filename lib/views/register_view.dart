import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:flutter_svg/flutter_svg.dart';


/// Two-step registration + success flow with resend countdown.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  _RegisterViewState createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  int _step = 0; // 0 = form, 1 = success

  final _formKey      = GlobalKey<FormState>();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl  = TextEditingController();
  final userNameCtrl  = TextEditingController();
  final emailCtrl     = TextEditingController();
  final dobCtrl       = TextEditingController();
  final passwordCtrl  = TextEditingController();
  final confirmCtrl   = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _resending = false;

  String? _error;

  // Resend‐confirmation cooldown
  Timer? _resendTimer;
  Duration _cooldown = Duration.zero;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in [
      firstNameCtrl,
      lastNameCtrl,
      userNameCtrl,
      emailCtrl,
      dobCtrl,
      passwordCtrl,
      confirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  void _startCooldown() {
    setState(() => _cooldown = Duration(minutes: 5));
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final secs = _cooldown.inSeconds - 1;
      if (secs > 0) {
        setState(() => _cooldown = Duration(seconds: secs));
      } else {
        t.cancel();
        setState(() => _cooldown = Duration.zero);
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
        _error = null;
      });
      
    if (!_formKey.currentState!.validate()) return;

    // Age check
    final dob = DateTime.tryParse(dobCtrl.text);
    if (dob != null) {
      final now = DateTime.now();
      final age = now.year -
          dob.year -
          ((now.month < dob.month ||
                  (now.month == dob.month && now.day < dob.day))
              ? 1
              : 0);
      if (age < 13) {
        await showDialog(
          context: context,
          builder: (context) => CustomAlertDialog(
            title: 'Parent or Guardian Required',
            info: 'Accounts for users under the age of 13 must be created by a parent or legal guardian. '
                  'Please have them register their own account to make bookings on your behalf.'
          ),
        );
        return;
      }
    }

    // Password match
    if (passwordCtrl.text != confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
    });

    //Capitalsie names
    String capitalize(String input) {
      if (input.isEmpty) return input;
      return input[0].toUpperCase() + input.substring(1).toLowerCase();
    }

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url     = Uri.parse('$baseUrl/api/auth/register');
    final body    = jsonEncode({
      'firstName':   capitalize(firstNameCtrl.text.trim()),
      'lastName':    capitalize(lastNameCtrl.text.trim()),
      'userName':    userNameCtrl.text.trim(),
      'email':       emailCtrl.text.trim(),
      'dateOfBirth': dobCtrl.text.trim(),
      'password':    passwordCtrl.text,
    });

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        // go straight to success without starting cooldown
        setState(() {
          _step = 1;
          _cooldown = Duration.zero;
        });
      } else {
        if (resp.statusCode == 400 && data['errors'] != null) {
          final errs = (data['errors'] as Map<String, dynamic>)
              .values
              .expand((e) => List<String>.from(e))
              .join('\n');
          setState(() => _error = errs);
        } else {
          setState(() =>
              _error = data['message']?.toString() ?? 'Registration failed');
        }
      }
    } catch (_) {
      setState(() => _error = 'Failed to connect to server');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > Duration.zero || _resending) return;

    setState(() => _resending = true);//start spinner

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url     = Uri.parse('$baseUrl/api/auth/resend-confirmation-email');

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailCtrl.text.trim()}),
      );
      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString() ??
          (resp.statusCode == 200
              ? 'Verification email resent'
              : 'Failed to resend');

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _startCooldown();
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
    } finally {
      setState(() => _resending = false); // stop spinner
    }
  }

  Widget _buildForm() {
    return Padding(
      padding: AppPadding.screen,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (Platform.isAndroid) 
                const BackButton(color: Colors.white),

              const Text('REGISTER',
                  style: TextStyle(
                      color: Colors.white, 
                      fontSize: 28, 
                      fontFamily: 'WinnerSans', 
                      fontWeight: FontWeight.bold)
                      ),
            ]),

            const SizedBox(height: 24),

            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4,),
                children: [
                  const TextSpan(
                    text: 'Create an account to start booking free events!\n',
                  ),
                
                  TextSpan(
                    text: 'Already have one? ',
                    style: const TextStyle(), 
                  ),

                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none, 
                    ),

                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushNamed(context, '/login');
                      },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(children: [
              Expanded(
                child: InputField(
                    label: 'First Name', 
                    hintText: 'e.g. John',
                    controller: firstNameCtrl),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: InputField(
                    label: 'Last Name', 
                    hintText: 'e.g. Smith',
                    controller: lastNameCtrl),
              ),
            ]),

            const SizedBox(height: 20),

            InputField(
                label: 'Username', 
                hintText: 'Choose a unique username',
                controller: userNameCtrl),

            const SizedBox(height: 20),

            InputField(
                label: 'Email',
                hintText: 'example@example.com',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$';
                  final regex = RegExp(pattern);
                  if (v == null || !regex.hasMatch(v.trim())) {
                    return 'Invalid email';
                  }
                  return null;
                },
            ),
            
            const SizedBox(height: 20),

            InputField(
              label: 'Date of Birth',
              hintText: 'Select your date of birth',
              controller: dobCtrl,
              onTap: () async {
                final dt = await _pickDate(context);
                if (dt != null) {
                  dobCtrl.text = dt.toIso8601String().split('T').first;
                }
              },

              iconLook: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SvgPicture.asset(
                  'assets/icons/calendar.svg',
                  width: 12,
                  height: 12,
                  colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                ),
              ),
            ),

            const SizedBox(height: 20),

            InputField(
              label: 'Password',
              hintText: 'Must be at least 6 characters',
              controller: passwordCtrl,
              obscureText: _obscure,
              keyboardType: TextInputType.visiblePassword,
              iconLook: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),

            const SizedBox(height: 20),

            InputField(
                label: 'Confirm Password',
                hintText: 'Re-enter password',
                controller: confirmCtrl,
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscure),

            const SizedBox(height: 20),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFFF0033))),
            ], 

            const SizedBox(height: 20 ),

            Button(
              label: 'NEXT',
              onPressed: _submit,
              loading: _loading,
            ),

            const SizedBox(height: 24),

            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                children: [
                  const TextSpan(text: 'By registering, you agree to our '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(decoration: TextDecoration.underline, color: Colors.white, fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse('https://www.yourcorps.co.nz/terms-and-conditions'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(decoration: TextDecoration.underline, color: Colors.white, fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse('https://www.yourcorps.co.nz/privacy-policy'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                ],
              ),
            ),          
          ]),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      color: AppColors.background,
      padding: AppPadding.screen,
      child: Column(
        children: [
          const Spacer(flex: 1),
          SvgPicture.asset('assets/icons/sent.svg',
          width: 180,
          height: 180,
          colorFilter: const ColorFilter.mode( Color(0xFF4C85D0), BlendMode.srcIn)
          ),

          const SizedBox(height: 36),

          const Text(
            'Verification Email Sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white, 
              fontSize: 24, 
              fontFamily: 'WinnerSans', 
              fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),
          
          const Text(
            'A verification link has been sent to your email.\n'
            'Please check your inbox or spam to activate your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),

          const Spacer(flex: 1),

          // _cooldown is zero on first display, so this link is active immediately
          if (_cooldown > Duration.zero)
            Text('Resend email in ${_formatDuration(_cooldown)}',
                style: const TextStyle(color: Colors.white, fontSize: 14))
          else
            GestureDetector(
              onTap: _resend,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive email? ",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  
                  const SizedBox(width: 4),

                  if (_resending)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Text(
                      'Resend',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 64),

          Button(
            label: 'DONE', 
            onPressed: () => Navigator.of(context).pop()
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _step == 0 ? _buildForm() : _buildSuccess()),
    );
  }
}

Future<DateTime?> _pickDate(BuildContext context) async {
  DateTime? dt;

  if (Platform.isAndroid) {
    dt = await showDatePicker(
      context: context,
      initialDate: DateTime(1980, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
  } else if (Platform.isIOS) {
    dt = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext builder) {
        DateTime tempPickedDate = DateTime(1980, 1, 1);

        return Container(
          height: 300,
          color: AppColors.background,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: DateTime(1980, 1, 1),
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime picked) {
                    tempPickedDate = picked;
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(tempPickedDate);
                },
              child: const Text(
                  "Done",
                  style: TextStyle(
                    color: CupertinoColors.activeBlue, 
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),              
              ),
            ],
          ),
        );
      },
    );
  }

  return dt;
}
