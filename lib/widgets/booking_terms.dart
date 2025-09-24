import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/widgets/button.dart';

class TermsView extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onAgree;

  const TermsView({
    super.key,
    required this.onCancel,
    required this.onAgree,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TERMS AND CONDITIONS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'WinnerSans',
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Registering Multiple People: You may register more than one person for a single-session, however you will have to repeat the process from the start for each person. (This prevents people abusing the FREE registration process, and signing up for all the tickets for a laugh.)',
                      style: TextStyle(color: Colors.white, height: 1.4, fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '• Kids Aged 8 to 11 years will only be allowed to play G and PG rated Games. We are unable to provide tailored experiences for individual kids if you do not approve of your child playing “Recommended Classifications” such as PG rated games, as it will mean your children will not be able to participate in the same experience as everyone else in the room. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                      style: TextStyle(color: Colors.white, height: 1.4, fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '• Teens Ages 12 to 15 years will be allowed to play M rated games, which is an Unrestricted Rated Classification, and is not enforced by law. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                      style: TextStyle(color: Colors.white, height: 1.4, fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '• By participating in our events, you understand and accept that you and/or your child participate at your own risk and release the event organizers and venue from any liability.',
                      style: TextStyle(color: Colors.white, height: 1.4, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                IntrinsicWidth(
                  child: Button(
                    onPressed: onCancel,
                    label: 'CANCEL',
                    buttonColor: AppColors.disabled,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Button(
                    onPressed: onAgree,
                    label: 'Agree & Continue',
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
