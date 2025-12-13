import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class NoInternetOverlay extends StatelessWidget {
  const NoInternetOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colors      = theme.colorScheme;
    final textTheme   = theme.textTheme;
    final cardRadius  = BorderRadius.circular(12.0);
    const horizMargin = 32.0;
    const vertPad     = 24.0;

    return Stack(
      children: [
        // full-screen tappable background
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              color: colors.background.withOpacity(0.75),
            ),
          ),
        ),

        // centered card
        Center(
          child: Card(
            color:        theme.cardColor,
            elevation:    theme.cardTheme.elevation ?? 4,
            shape:        RoundedRectangleBorder(borderRadius: cardRadius),
            margin:       const EdgeInsets.symmetric(horizontal: horizMargin),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(vertPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    'NO INTERNET CONNECTION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'WinnerSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Body
                  Text(
                    'Please check your network and choose an option below.',
                    style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      // Quit (outlined)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.onSurface),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: cardRadius),
                          ),
                          onPressed: () {
                            SystemNavigator.pop();
                            exit(0);
                          },
                          child: const Text('Quit'),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Retry
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: cardRadius),
                          ),
                          onPressed: () {
                            MyApp.navigatorKey.currentState!
                                .pushReplacementNamed('/landing');
                          },
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
