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

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'WinnerSans',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPolicyGroup(List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: tiles.map((tile) {
          return Column(
            children: [
              tile,
              if (tile != tiles.last)
                const Divider(color: Colors.white24, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTile(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.white),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'POLICIES',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // General section
            _buildSectionHeader('General'),
            _buildPolicyGroup([
              _buildTile('Terms & Conditions', () {
                _open(context, 'https://www.yourcorps.co.nz/terms-and-conditions');
              }),
              _buildTile('Privacy Policy', () {
                _open(context, 'https://www.yourcorps.co.nz/privacy-policy');
              }),
            ]),

            // Child Protection section
            _buildSectionHeader('Child Protection'),
            _buildPolicyGroup([
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
            ]),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
