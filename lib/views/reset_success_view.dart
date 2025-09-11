import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import 'login_view.dart';

class ResetSuccessView extends StatelessWidget {
  const ResetSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    // space at bottom for phones with gesture bars
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    // push content down a bit
                    const Spacer(),

                    // Success image
                    Center(
                      child: Image.asset(
                        'assets/success.png', // your graphic here
                        height: 360,
                      ),
                    ),

                    // Title
                    const Text(
                      'SUCCESS!!!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'WinnerSans'
                      ),
                    ),

                    // Subtitle
                    const Text(
                      'Your password has been successfully reset.\n'
                      'You may now log in with your new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    // fill remaining space
                    const Spacer(),
                  
                    // Back to Login button
                    Button(
                      label: 'BACK TO LOGIN', 
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => const LoginView(), 
                          ),
                          (_) => false
                        );                     
                      }
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
