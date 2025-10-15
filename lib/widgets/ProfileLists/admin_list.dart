import 'package:corpsapp/views/banned_users_view.dart';
import 'package:corpsapp/views/change_user_role_view.dart';
import 'package:corpsapp/views/manage_events_view.dart';
import 'package:corpsapp/views/manage_locations_view.dart';
import 'package:corpsapp/views/report_generation_view.dart';
import 'package:corpsapp/views/show_account_users.dart';
import 'package:corpsapp/widgets/ProfileLists/list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdminList extends StatelessWidget {


  const AdminList({
    super.key,

  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoListSection.insetGrouped(
          margin: EdgeInsets.symmetric(vertical: 8),
          backgroundColor: Colors.transparent,
          children: [
            OptionTile(
              icon: Icons.event,
              label: "Manage Events",
              view: ManageEventsView(),
            ),

            OptionTile(
              icon: Icons.bar_chart_rounded,
              label: "Events History",
              view: ReportGenerationView(),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          margin: EdgeInsets.symmetric(vertical: 8),
          backgroundColor: Colors.transparent,
          children: [
            OptionTile(
              icon: Icons.person_2_outlined, 
              label: 'User Management', 
              view: ManageUsersView()
            ),

            OptionTile(
              icon: Icons.block,
              label: "Ban Management",
              view: BannedUsersView(),
            ),

            OptionTile(
              icon: Icons.admin_panel_settings,
              label: "Roles Management",
              view: ChangeUserRoleView(),
            ),

            OptionTile(
              icon: Icons.location_on,
              label: "Location Management",
              view: ManageLocationsView(),
            ),
          ],
        ),      
      ],
    );
  }
}
