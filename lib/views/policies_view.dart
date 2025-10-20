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
              header: Text( 'General', style: TextStyle( fontFamily: 'WinnerSans', fontSize: 16 )),
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
              header: Text( 'Child Protection', style: TextStyle( fontFamily: 'WinnerSans', fontSize: 16 )),
              margin: EdgeInsets.all(0),
              backgroundColor: AppColors.background,
              hasLeading: false,
              children: [
                _buildTile('Child Protection Policy', () {
                  _open(context, 'https://www.yourcorps.co.nz/_files/ugd/ff8734_5d58ed0ed7f74328aa1dc0524ef00410.pdf');
                }),
                _buildTile('Child Protection Prevention Framework', () {
                  _open(context, 'https://www.yourcorps.co.nz/_files/ugd/ff8734_13c2b4f95fca4ac9abc97661e8387e27.pdf');
                }),
                _buildTile('Health and Safety Manual', () {
                  _open(context, 'https://www.yourcorps.co.nz/_files/ugd/ff8734_d193389476e34ac89da4ab0dd1067afc.pdf');
                }),
                _buildTile('Code of Conduct for Interacting with Children', () {
                  _open(context, 'https://www.yourcorps.co.nz/_files/ugd/ff8734_57085482bbd8423dbbea34e8989bd4eb.pdf');
                }),
              ],
            ),  
          ],
        ),
      ),
    );
  }
}
