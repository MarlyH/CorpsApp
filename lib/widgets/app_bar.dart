import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart';

class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Icon? actionButton;
  final void Function()? actionOnTap;

  const ProfileAppBar({
    super.key,
    required this.title,
    this.actionButton,
    this.actionOnTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'WinnerSans',
          fontSize: 20,
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
        iconSize: 24,
      ),
      actions: actionButton != null
          ? [
              IconButton(
                onPressed: actionOnTap,
                icon: actionButton!,
              ),
            ]
          : null,
      elevation: 0,
      centerTitle: true,
    );
  }
}
