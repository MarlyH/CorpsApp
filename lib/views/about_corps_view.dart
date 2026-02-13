import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCorpsView extends StatelessWidget {
  const AboutCorpsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'About Corps'),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo/launch_logo.png',
                      height: 256,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 8),

                    // Version from pubspec via package_info_plus
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text(
                            'Version …',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                            ),
                          );
                        }
                        final info = snapshot.data!;
                        // e.g. "1.0.0+3" where "1.0.0" is from pubspec version, "+3" is build number
                        // final versionText = 'Version v${info.version}+${info.buildNumber}';
                        final versionText = 'v${info.version}';
                        return Text(
                          versionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Rate our app button
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF242424),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: const Text(
                    'Rate our app',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () async {
                    const String googleStoreUrl =
                        'https://play.google.com/store/apps/details?id=com.example.corpsapp'; 
                    const String appleStoreUrl = 'https://apps.apple.com/app/id6756507205?action=write-review'; //

                    final Uri? url = Platform.isAndroid
                        ? Uri.parse(googleStoreUrl)
                        : (appleStoreUrl.isNotEmpty ? Uri.parse(appleStoreUrl) : null);

                    if (url == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('The app is not yet available on the App Store.'),
                        ),
                      );
                      return;
                    }

                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open the store page. Please try searching for the app manually in the app store.'),
                        ),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copyright, size: 12),

                      const SizedBox(width: 2),

                      Text(
                        "Your Corps Limited.", 
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Text('CORPS® and the Cyclone Logo are registered trademarks. All rights reserved.', 
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
