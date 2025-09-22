import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Local model for medical items
class MedicalItem {
  MedicalItem({required this.name, this.notes = '', this.isAllergy = false});

  String name;
  String notes;
  bool isAllergy;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'notes': notes.trim(),
        'isAllergy': isAllergy,
      };
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  /// Steps:
  /// 0 = form, 1 = medical (conditionally shown for age 13-15), 2 = success
  int _step = 0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final userNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // UI state
  bool _obscure = true;
  bool _loading = false; // for network calls
  String? _error;

  // Resend cooldown (success screen)
  Timer? _resendTimer;
  Duration _cooldown = Duration.zero;
  bool _resending = false;

  // Medical step state
  bool _wantsMedical = false; // toggle in step 1
  final List<MedicalItem> _medicalItems = [];

  // Cache payload from form step -> used when finishing
  late Map<String, dynamic> _formPayload;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [
      firstNameCtrl,
      lastNameCtrl,
      userNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      passwordCtrl,
      confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers

  int? _computedAge() {
    final dob = DateTime.tryParse(dobCtrl.text.trim());
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    final beforeBirthday =
        (now.month < dob.month) || (now.month == dob.month && now.day < dob.day);
    if (beforeBirthday) age--;
    return age;
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void _startCooldown() {
    setState(() => _cooldown = const Duration(minutes: 5));
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final secs = _cooldown.inSeconds - 1;
      if (!mounted) return t.cancel();
      setState(() {
        if (secs > 0) {
          _cooldown = Duration(seconds: secs);
        } else {
          t.cancel();
          _cooldown = Duration.zero;
        }
      });
    });
  }

  // Replaces: String _cap(String s) => ...
  String _capName(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return s;

    final buf = StringBuffer();
    bool capNext = true; // capitalize at start and after space, hyphen, or apostrophe

    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (capNext && RegExp(r'[a-z]').hasMatch(ch)) {
        buf.write(ch.toUpperCase());
        capNext = false;
      } else {
        buf.write(ch);
        capNext = (ch == ' ' || ch == '-' || ch == '\'');
      }
    }
    return buf.toString();
  }


  String? _passwordComplexityError(String pwd) {
    if (pwd.length < 6) return 'Password must be at least 6 characters.';
    final hasDigit = RegExp(r'\d').hasMatch(pwd);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);
    if (!hasDigit) return 'Password must include at least one number.';
    if (!hasSpecial) return 'Password must include at least one special character.';
    return null;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Flow

  Future<void> _nextFromForm() async {
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    // Age guard for < 13
    final age = _computedAge();
    if (age != null && age < 13) {
      await showDialog(
        context: context,
        builder: (_) => const CustomAlertDialog(
          title: 'Parent or Guardian Required',
          info:
              'Accounts for users under the age of 13 must be created by a parent or legal guardian. '
              'Please have them register their own account to make bookings on your behalf.',
        ),
      );
      return;
    }

    // Password match
    if (passwordCtrl.text != confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    // Password complexity
    final pwdErr = _passwordComplexityError(passwordCtrl.text);
    if (pwdErr != null) {
      setState(() => _error = pwdErr);
      return;
    }

    // Build the base payload and hold it until FINISH
    _formPayload = {
      'firstName': _capName(firstNameCtrl.text),
      'lastName' : _capName(lastNameCtrl.text),
      'userName' : userNameCtrl.text.trim(),
      'email'    : emailCtrl.text.trim(),
      'dateOfBirth': dobCtrl.text.trim(),
      'password' : passwordCtrl.text,
      'phoneNumber': phoneCtrl.text.trim(),
    };


    // If age 13–15 → go to medical step; else send immediately
    if (age != null && age >= 13 && age < 16) {
      setState(() => _step = 1);
    } else {
      // 16+ → no medical page; send now
      await finish();
    }
  }

  Future<void> finish() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // In the medical step, if user toggled ON but added nothing, block
      if (_step == 1 && _wantsMedical && _medicalItems.isEmpty) {
        setState(() => _error = 'Please add at least one condition/allergy or switch the toggle off.');
        return;
      }

      // Only include medical fields if:
      // - we're on the medical step AND
      // - user toggled ON AND
      // - there is at least one item
      // Build medical payload based on step + toggle
      if (_step == 1) {
        if (_wantsMedical) {
          // Toggle ON → require items (the guard above ensures not empty)
          _formPayload['hasMedicalConditions'] = true;
          _formPayload['medicalConditions'] =
              _medicalItems.map((m) => m.toJson()).toList();
        } else {
          // Toggle OFF → explicitly say false, omit the list
          _formPayload['hasMedicalConditions'] = false;
          _formPayload.remove('medicalConditions');
        }
      } else {
        // Not on medical step (16+ or <13 blocked): omit both fields entirely
        _formPayload.remove('hasMedicalConditions');
        _formPayload.remove('medicalConditions');
      }

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
      final url = Uri.parse('$baseUrl/api/auth/register');

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_formPayload),
      );

      final text = resp.body;
      final Map<String, dynamic>? data =
          text.isNotEmpty ? jsonDecode(text) as Map<String, dynamic> : null;

      if (!mounted) return;

      if (resp.statusCode == 200) {
        setState(() {
          _step = 2;                 // success
          _cooldown = Duration.zero; // first show → no cooldown yet
        });
      } else if (resp.statusCode == 400 && (data?['errors'] != null)) {
        final errs = (data!['errors'] as Map<String, dynamic>)
            .values
            .expand((e) => List<String>.from(e))
            .join('\n');
        setState(() => _error = errs);
      } else {
        setState(() => _error = data?['message']?.toString() ?? 'Registration failed.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to connect to server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > Duration.zero || _resending) return;

    setState(() => _resending = true);
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$baseUrl/api/auth/resend-confirmation-email');

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailCtrl.text.trim()}),
      );
      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString() ??
          (resp.statusCode == 200 ? 'Verification email resent' : 'Failed to resend');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _startCooldown();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: switch (_step) {
          0 => _buildForm(),
          1 => _buildMedicalStep(),
          _ => _buildSuccess(),
        },
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: AppPadding.screen,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                if (Platform.isAndroid) const BackButton(color: Colors.white),
                const Text(
                  'REGISTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontFamily: 'WinnerSans',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                children: [
                  const TextSpan(text: 'Create an account to start booking free events!\n'),
                  const TextSpan(text: 'Already have one? '),
                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.pushNamed(context, '/login'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: InputField(
                    label: 'First Name',
                    hintText: 'e.g. John',
                    controller: firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: InputField(
                    label: 'Last Name',
                    hintText: 'e.g. Smith',
                    controller: lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InputField(
              label: 'Username',
              hintText: 'Choose a unique username',
              controller: userNameCtrl,
            ),
            const SizedBox(height: 20),
            InputField(
              label: 'Email',
              hintText: 'example@example.com',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$';
                final regex = RegExp(pattern);
                if (v == null || !regex.hasMatch(v.trim())) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 20),
            InputField(
              label: 'Phone Number',
              hintText: 'e.g. 021 123 4567',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
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
              hintText: 'At least 6 chars, 1 number, 1 special',
              controller: passwordCtrl,
              obscureText: _obscure,
              keyboardType: TextInputType.visiblePassword,
              iconLook: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.black),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: include at least one number and one special character (e.g., ! @ # \$ %).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            InputField(
              label: 'Confirm Password',
              hintText: 'Re-enter password',
              controller: confirmCtrl,
              keyboardType: TextInputType.visiblePassword,
              obscureText: _obscure,
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFFF0033))),
              const SizedBox(height: 12),
            ],
            Button(
              label: 'NEXT',
              loading: _loading,
              onPressed: () {
                if (_loading) return;
                _nextFromForm();
              },
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
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launcher.launchUrl(
                            Uri.parse('https://www.yourcorps.co.nz/terms-and-conditions'),
                            mode: launcher.LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launcher.launchUrl(
                            Uri.parse('https://www.yourcorps.co.nz/privacy-policy'),
                            mode: launcher.LaunchMode.externalApplication,
                          ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildMedicalStep() {
    return Padding(
      padding: AppPadding.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Text(
              'MEDICAL INFO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'WinnerSans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Text(
            'Because your age is between 13 and 15, you can optionally provide any '
            'medical conditions or allergies that may help staff on event day.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _wantsMedical,
            onChanged: (v) => setState(() => _wantsMedical = v),
            activeColor: Colors.blueAccent,
            title: const Text('Has medical conditions or allergies?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text('If enabled, add one or more items below.',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),

          if (_wantsMedical) ...[
            Expanded(
              child: _medicalItems.isEmpty
                  ? const Center(
                      child: Text('No items added yet.',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.separated(
                      itemCount: _medicalItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = _medicalItems[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B1B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (item.isAllergy)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6.0),
                                            child: Icon(Icons.warning_amber_rounded,
                                                size: 16, color: Colors.amber),
                                          ),
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.notes.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(item.notes,
                                          style:
                                              const TextStyle(color: Colors.white70)),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editMedicalItem(i),
                                icon: const Icon(Icons.edit, color: Colors.white70),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  _medicalItems.removeAt(i);
                                }),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _addMedicalItem,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('ADD CONDITION/ALLERGY',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const Spacer(),

          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Color(0xFFFF0033))),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('BACK', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Button(
                  label: 'FINISH',
                  loading: _loading,
                  onPressed: () {
                    if (_loading) return;
                    finish(); // fire-and-forget; Button expects VoidCallback
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      color: AppColors.background,
      padding: AppPadding.screen,
      child: Column(
        children: [
          const Spacer(),
          SvgPicture.asset(
            'assets/icons/sent.svg',
            width: 180,
            height: 180,
            colorFilter:
                const ColorFilter.mode(Color(0xFF4C85D0), BlendMode.srcIn),
          ),
          const SizedBox(height: 36),
          const Text(
            'Verification Email Sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'WinnerSans',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A verification link has been sent to your email.\n'
            'Please check your inbox or spam to activate your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          if (_cooldown > Duration.zero)
            Text('Resend email in ${_formatDuration(_cooldown)}',
                style: const TextStyle(color: Colors.white, fontSize: 14))
          else
            GestureDetector(
              onTap: _resend,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive email? ",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(width: 4),
                  if (_resending)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Text('Resend',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: 64),
          Button(
            label: 'DONE',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Medical item add/edit sheet

  Future<void> _addMedicalItem() async {
    final created = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _MedicalEditor(),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (created != null && mounted) {
      setState(() => _medicalItems.add(created));
    }
  }

  Future<void> _editMedicalItem(int index) async {
    final updated = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _MedicalEditor(initial: _medicalItems[index]),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _medicalItems[index] = updated);
    }
  }
}

// Editor used in bottom sheet
class _MedicalEditor extends StatefulWidget {
  const _MedicalEditor({this.initial});
  final MedicalItem? initial;

  @override
  State<_MedicalEditor> createState() => _MedicalEditorState();
}

class _MedicalEditorState extends State<_MedicalEditor> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  bool _isAllergy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
    _isAllergy = widget.initial?.isAllergy ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Medical Condition / Allergy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Name (required)'),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _notes,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: _dec('Notes (optional)'),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _isAllergy,
          onChanged: (v) => setState(() => _isAllergy = v),
          activeColor: Colors.amber,
          title: const Text('This is an allergy',
              style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Enable if this item is an allergy (e.g., peanuts, bee stings).',
            style: TextStyle(color: Colors.white70),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_name.text.trim().isEmpty) return;
                    Navigator.pop(
                      context,
                      MedicalItem(
                        name: _name.text.trim(),
                        notes: _notes.text.trim(),
                        isAllergy: _isAllergy,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
        // extra safe area at the very bottom so it never hugs the edge
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// Platform date picker
Future<DateTime?> _pickDate(BuildContext context) async {
  if (Platform.isAndroid) {
    return showDatePicker(
      context: context,
      initialDate: DateTime(2008, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
  } else if (Platform.isIOS) {
    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext builder) {
        DateTime tempPickedDate = DateTime(2008, 1, 1);
        return Container(
          height: 300,
          color: AppColors.background,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempPickedDate,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime picked) {
                    tempPickedDate = picked;
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(tempPickedDate),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(builder).padding.bottom),
            ],
          ),
        );
      },
    );
  }
  return null;
}
