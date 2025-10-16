import 'package:corpsapp/views/ban_appeal_view.dart';
import 'package:corpsapp/views/manage_children_view.dart';
import 'package:corpsapp/views/medical_conditions_view.dart';
import 'package:corpsapp/widgets/ProfileLists/list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class UserList extends StatelessWidget {
  final int age;
  final bool isSuspended;

  const UserList({
    super.key,
    required this.age,
    required this.isSuspended
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoListSection.insetGrouped(
          margin: EdgeInsets.symmetric(vertical: 8),
          backgroundColor: Colors.transparent,
          children: [
            if (age < 16) ... [
              OptionTile(
                icon: Icons.healing,
                label: "Medical Info",
                view: MedicalConditionsView()
              )
            ] else ... [
              OptionTile(
                icon: Icons.child_care,
                label: "My Children",
                view: ManageChildrenView()
              ),
            ],
            if (isSuspended) ... [
              OptionTile(
                icon: Icons.gavel, 
                label: 'Ban Appeal',
                view: BanAppealView())
            ]
          ],
        ),
      ],
    );
  }
}
