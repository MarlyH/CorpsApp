import 'package:flutter/material.dart';

class OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? view;
  final VoidCallback? onTap;

  const OptionTile({
    super.key,
    required this.icon,
    required this.label,
    this.view,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap ??
          () {
            if (view != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => view!),
              );
            }
          },
    );
  }
}
