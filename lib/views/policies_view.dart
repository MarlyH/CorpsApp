import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PoliciesView extends StatelessWidget {
  const PoliciesView({super.key});

  // Open a URL in the external browser
  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Widget _buildTile(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.white70),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Policies'),
      body: Padding(
        padding: AppPadding.screen,
        child: ListView(
          children: [
            // General section
            CupertinoListSection.insetGrouped(
              header: Text( 'GENERAL', style: TextStyle( fontFamily: 'WinnerSans', fontSize: 16 )),
              margin: EdgeInsets.all(0),
              backgroundColor: AppColors.background,
              hasLeading: false,
              children: [
                  _buildTile('Terms & Conditions', () {
                  _open(context, 'https://www.yourcorps.co.nz/terms-and-conditions');
                }),
                _buildTile('Privacy Policy', () {
                  _open(context, 'https://www.yourcorps.co.nz/privacy-policy');
                }),
              ],
            ),           

            const SizedBox(height: 16),

            // Child Protection section
            CupertinoListSection.insetGrouped(
              header: Text( 'CHILD PROTECTION', style: TextStyle( fontFamily: 'WinnerSans', fontSize: 16 )),
              margin: EdgeInsets.all(0),
              backgroundColor: AppColors.background,
              hasLeading: false,
              children: [
                _buildTile('Child Protection Policies', () {
                  _open(context, 'https://www.yourcorps.co.nz/child-protection-policies');
                }),
              ],
            ),  
          ],
        ),
      ),
    );
  }
}
