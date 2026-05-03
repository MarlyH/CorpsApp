import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart';

class TermsView extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onAgree;

  const TermsView({
    super.key,
    required this.onCancel,
    required this.onAgree,
  });

  Widget _sectionText(
    String text, {
    bool bold = false,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.6,
        fontWeight: bold ? FontWeight.bold : FontWeight.w400,
      ),
    );
  }

  Widget _bulletText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Booking Agreement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontFamily: 'WinnerSans',
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionText(
                        'By continuing, you confirm that you have read and agree to the event Terms and Conditions.',
                        bold: true,
                      ),
                      const SizedBox(height: 16),
                      _sectionText(
                        'Below is a brief summary of some key terms at the time of publishing. Full, up-to-date terms and details on how events work can be found in the app under Profile → Policies → Terms and Conditions.',
                      ),
                      const SizedBox(height: 20),
                      _bulletText(
                        '• Cancel if you cannot attend or strikes may apply (Bookings → Ticket → Scroll down → Cancel)',
                      ),
                      _bulletText(
                        '• You may register multiple participants, but each must be registered separately',
                      ),
                      _bulletText(
                        '• Game content: Ages 8–11 G–PG, Ages 12–15 M, Ages 16+ approved restricted titles',
                      ),
                      _bulletText(
                        '• Parents or guardians must register participants under 16',
                      ),
                      _bulletText(
                        '• Wristbands are issued to participants registered for collection. Participants will not be allowed to leave without the booking QR code. The booking QR code may be shared with another authorised guardian for collection',
                      ),
                      _bulletText(
                        '• Provide an emergency contact and any relevant health information',
                      ),
                      _bulletText(
                        '• Ages 8–11 are not permitted to leave the venue',
                      ),
                      _bulletText(
                        '• Ages 12–15 may leave the venue unless issued a wristband',
                      ),
                      _bulletText(
                        '• Ages 16+ may leave the venue at their own discretion',
                      ),
                      _bulletText(
                        '• Late arrival may result in loss of your spot',
                      ),
                      _bulletText(
                        '• Respect others, staff, and equipment at all times, or you may be asked to leave',
                      ),
                      _bulletText(
                        '• Only registered participants may enter the gaming area. Others may only enter if approved and escorted by staff. Staff may require anyone to leave the gaming area or venue',
                      ),
                      _bulletText(
                        '• Participation is at your own risk',
                      ),
                      _bulletText(
                        '• Your information is used to manage the event',
                      ),
                      _bulletText(
                        '• Photos and videos may be taken and used for marketing and promotional purposes',
                      ),
                      const SizedBox(height: 8),
                      _sectionText(
                        'By clicking Agree and registering for the event, you confirm that you have read, acknowledged, and agree to all terms. If you do not agree, please do not register.',
                        bold: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}