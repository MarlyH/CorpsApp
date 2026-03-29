import 'package:corpsapp/services/auth_http_client.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/material.dart';

class AdminBroadcastNotificationView extends StatefulWidget {
  const AdminBroadcastNotificationView({super.key});

  @override
  State<AdminBroadcastNotificationView> createState() =>
      _AdminBroadcastNotificationViewState();
}

class _AdminBroadcastNotificationViewState
    extends State<AdminBroadcastNotificationView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await AuthHttpClient.sendBroadcastNotification(
        title: title.isEmpty ? null : title,
        message: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent to all push-enabled users.'),
          backgroundColor: Colors.green,
        ),
      );
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfileAppBar(title: 'Send Notification'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Broadcast a custom push notification to users who have push enabled.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              InputField(
                label: 'Title (Optional)',
                hintText: 'Your Corps Update',
                controller: _titleController,
                isRequired: false,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              InputField(
                label: 'Message',
                hintText: 'Enter your notification message',
                controller: _messageController,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              Button(
                label: 'Send Notification',
                onPressed: _sending ? null : _sendBroadcast,
                loading: _sending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
