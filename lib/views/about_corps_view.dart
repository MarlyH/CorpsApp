// lib/views/about_corps_view.dart

import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCorpsView extends StatelessWidget {
  const AboutCorpsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'ABOUT CORPS',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 24, 
          ),
        ),
      ),
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
                      'assets/logo/logo_transparent_1024px.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),

                    const Text(
                      'Corps App',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 4),
                    
                    const Text(
                      'Version v1.0.0',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w300 ),
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
                  trailing: const Icon(
                    Icons.keyboard_arrow_right,                
                  ),
                  onTap: () async {
                    const String googleStoreUrl =
                        'https://play.google.com/store/apps/details?id=com.example.corpsapp'; 
                    const String appleStoreUrl = ''; // TODO: fill url once app is live

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
                          content: Text('Could not open the store page.'),
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

                      Text("Copyright Your Corps® Limited 2025", style: TextStyle(fontSize: 12)),                                     
                    ],
                  ),  
                  Text('All rights reserved.', style: TextStyle(fontSize: 12))                 
                ],               
              ),       
            ],
          ),
        )
      ),
    );
  }
}
