// lib/views/policies_view.dart

import 'package:flutter/material.dart';

class PoliciesView extends StatelessWidget {
  const PoliciesView({super.key});

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
                // TODO: push Terms & Conditions view
              }),
              _buildTile('Privacy Policy', () {
                // TODO: push Privacy Policy view
              }),
            ]),

            // Child Protection section
            _buildSectionHeader('Child Protection'),
            _buildPolicyGroup([
              _buildTile('Child Protection Policy', () {
                // TODO: push Child Protection Policy view
              }),
              _buildTile('Child Protection Prevention Framework', () {
                // TODO: push Prevention Framework view
              }),
              _buildTile('Health and Safety Manual', () {
                // TODO: push Health & Safety Manual view
              }),
              _buildTile('Code of Conduct for Interacting with Children', () {
                // TODO: push Code of Conduct view
              }),
            ]),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
