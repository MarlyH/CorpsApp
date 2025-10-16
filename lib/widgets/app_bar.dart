import 'package:corpsapp/fragments/profile_fragment.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';

class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget{
  final String title;

  const ProfileAppBar ({
    super.key,
    required this.title
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
        title:  Text(
          title,
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back),
          iconSize: 24,
        ),
        elevation: 0,
        centerTitle: true,
    );
  }
}

