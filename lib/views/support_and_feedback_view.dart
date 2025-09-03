import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

class SupportAndFeedbackView extends StatefulWidget {
  const SupportAndFeedbackView({super.key});

  @override
  State<SupportAndFeedbackView> createState() => _SupportAndFeedbackViewState();
}

class _SupportAndFeedbackViewState extends State<SupportAndFeedbackView> {
  // TODO: change this to the actual support address
  static const String supportEmail = 'admin@admin.com';

  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController(text: 'Support & Feedback');
  final _messageCtrl = TextEditingController();

  bool _sending = false;

  // collected at runtime
  String _appName = 'App';
  String _appVersion = '0.0.0';
  String _buildNumber = '';
  String _deviceModel = 'Unknown device';
  String _osVersion = 'Unknown OS';

  @override
  void initState() {
    super.initState();
    _initMeta(); // load app/device info then set the template
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _initMeta() async {
    try {
      // App info
      final pkg = await PackageInfo.fromPlatform();
      _appName = pkg.appName.isNotEmpty ? pkg.appName : 'App';
      _appVersion = pkg.version;
      _buildNumber = pkg.buildNumber;

      // Device info
      final di = DeviceInfoPlugin();
      String deviceModel = 'Unknown device';
      String osVersion = 'Unknown OS';

      if (Platform.isAndroid) {
        final info = await di.androidInfo;
        final manu = (info.manufacturer ?? '').trim();
        final model = (info.model ?? '').trim();
        deviceModel = [manu, model].where((s) => s.isNotEmpty).join(' ');
        osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await di.iosInfo;
        deviceModel = info.utsname.machine ?? info.model ?? 'iOS Device';
        osVersion = 'iOS ${info.systemVersion}';
      } else if (Platform.isMacOS) {
        final info = await di.macOsInfo;
        deviceModel = info.model ?? 'Mac';
        osVersion = '${info.osRelease}';
      } else if (Platform.isWindows) {
        final info = await di.windowsInfo;
        deviceModel = 'Windows PC';
        osVersion = '${info.productName} ${info.displayVersion ?? info.buildLabEx ?? ''}'.trim();
      } else if (Platform.isLinux) {
        final info = await di.linuxInfo;
        deviceModel = info.prettyName ?? 'Linux';
        osVersion = '${info.id} ${info.versionId ?? ''}'.trim();
      } else {
        // Fallback (Web or others)
        deviceModel = 'Unknown / Web';
        osVersion = 'Unknown';
      }

      setState(() {
        _deviceModel = deviceModel;
        _osVersion = osVersion;
        _messageCtrl.text = _defaultTemplate(); // populate template after we know meta
      });
    } catch (_) {
      // If anything goes wrong, still show a sensible template
      setState(() {
        _messageCtrl.text = _defaultTemplate();
      });
    }
  }

  String _defaultTemplate() {
    // Build “App / Device” footer inline to help your support triage quickly
    final appLine = '$_appName v$_appVersion'
        '${_buildNumber.isNotEmpty ? ' (build $_buildNumber)' : ''}';
    final deviceLine = '$_deviceModel • $_osVersion';

    return [
      'Hi team,',
      '',
      "I'd like to report an issue / share feedback:",
      '',
      '— What I expected:',
      '— What happened instead:',
      '— Steps to reproduce:',
      '— Frequency (always/sometimes/once):',
      '',
      'Thanks!',
      '',
      '— — —',
      'Diagnostic',
      'App: $appLine',
      'Device: $deviceLine',
    ].join('\n');
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final to = supportEmail;
      final subject = _subjectCtrl.text;
      final body = _messageCtrl.text;

      // try native mail app via mailto:
      final mailUri = Uri(
        scheme: 'mailto',
        path: to,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(mailUri)) {
        final ok = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }

      // Gmail Web compose
      final gmailUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(to)}'
        '&su=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(gmailUri)) {
        final ok = await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }

      // Outlook Web compose
      final outlookUri = Uri.parse(
        'https://outlook.office.com/mail/deeplink/compose'
        '?to=${Uri.encodeComponent(to)}'
        '&subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(outlookUri)) {
        final ok = await launchUrl(outlookUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }

      // Clipboard fallback
      _copyToClipboard(to: to, subject: subject, body: body);
      _showSnack(
        'Could not open an email app. A ready-to-send message was copied to your clipboard.',
      );
    } catch (_) {
      _copyToClipboard(
        to: supportEmail,
        subject: _subjectCtrl.text,
        body: _messageCtrl.text,
      );
      _showSnack(
        'Something went wrong. A ready-to-send message was copied to your clipboard.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copyToClipboard({
    required String to,
    required String subject,
    required String body,
  }) {
    final formatted = 'To: $to\nSubject: $subject\n\n$body';
    Clipboard.setData(ClipboardData(text: formatted));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Support & Feedback',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Need help or have feedback?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Send us a message and we’ll get back to you. "
                  "Edit the subject and message below — the template includes your app/device info.",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),

                // Clickable email link
                InkWell(
                  onTap: _sending ? null : _sendEmail,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.email, color: Color(0xFF4C85D0)),
                      SizedBox(width: 8),
                      Text(
                        supportEmail,
                        style: TextStyle(
                          color: Color(0xFF4C85D0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Subject input
                TextFormField(
                  controller: _subjectCtrl,
                  style: const TextStyle(color: Colors.black),
                  decoration: _decoration('Subject'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Message input (pre-populated with template including version/device)
                TextFormField(
                  controller: _messageCtrl,
                  style: const TextStyle(color: Colors.black),
                  minLines: 6,
                  maxLines: 12,
                  decoration: _decoration('Message'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 24),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendEmail,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Opening…' : 'Send Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C85D0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      textStyle: const TextStyle(
                        fontFamily: 'WinnerSans',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color.fromARGB(255, 255, 255, 255),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF40C4FF)),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}


  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle:  TextStyle(color: Color.fromARGB(255, 0, 0, 0), 
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
    ),
    hintStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: const Color.fromARGB(255, 255, 255, 255),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white24),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFF40C4FF)),
      borderRadius: BorderRadius.circular(12),
    ),
  );

// this is a old but posible avenue to go down if you decide to have server side api backend calls and routing of emails to applicable people

// import 'package:flutter/material.dart';

// class SupportAndFeedbackView extends StatefulWidget {
//   const SupportAndFeedbackView({super.key});

//   @override
//   _SupportAndFeedbackViewState createState() =>
//       _SupportAndFeedbackViewState();
// }

// class _SupportAndFeedbackViewState extends State<SupportAndFeedbackView> {
//   final List<String> _types = [
//     'General Question',
//     'Bug Report',
//     'Feature Request',
//     'Other',
//   ];

//   String _selectedType = 'General Question';
//   final TextEditingController _controller = TextEditingController();

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _submit() {
//     // TODO: wire up your submission logic
//     final text = _controller.text.trim();
//     if (text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter some feedback'),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//       return;
//     }
//     // Example placeholder:
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Feedback submitted!'),
//         backgroundColor: Colors.green,
//       ),
//     );
//     Navigator.pop(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         elevation: 0,
//         leading: const BackButton(color: Colors.white),
//         centerTitle: true,
//         title: const Text(
//           'SUPPORT AND FEEDBACK',
//           style: TextStyle(
//             fontFamily: 'WinnerSans',
//             fontSize: 20,            // tweak as needed
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: EdgeInsets.fromLTRB(
//             16,
//             16,
//             16,
//             MediaQuery.of(context).padding.bottom + 16,
//           ),
//           child: Column(
//             children: [
//               // Dropdown
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: Colors.white12,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: DropdownButtonHideUnderline(
//                   child: DropdownButton<String>(
//                     value: _selectedType,
//                     dropdownColor: Colors.grey[900],
//                     style: const TextStyle(color: Colors.white),
//                     items: _types
//                         .map((t) => DropdownMenuItem(
//                               value: t,
//                               child: Text(t, style: const TextStyle(color: Colors.white70)),
//                             ))
//                         .toList(),
//                     onChanged: (v) {
//                       if (v != null) setState(() => _selectedType = v);
//                     },
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // Feedback text area
//               Expanded(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white12,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   child: TextField(
//                     controller: _controller,
//                     maxLines: null,
//                     expands: true,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       hintText: 'Enter your question or feedback here',
//                       hintStyle: const TextStyle(color: Colors.white38),
//                       border: InputBorder.none,
//                     ),
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // Submit button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _submit,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(24),
//                     ),
//                   ),
//                   child: const Text(
//                     'SUBMIT',
//                     style: TextStyle(
//                       color: Colors.white,
//                       letterSpacing: 1.2,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
