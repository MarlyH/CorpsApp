import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EventBrowserAppBar extends StatelessWidget {
  final String? filterLocation;
  final Function(String?) onLocationChanged;
  final List<String> allLocations;
  final VoidCallback onDropdownOpen;

  const EventBrowserAppBar({
    super.key,
    required this.filterLocation,
    required this.onLocationChanged,
    required this.allLocations,
    required this.onDropdownOpen,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final smallScreen = screenWidth < 360;

    final double baseFontSize = smallScreen ? 24 : 32;

    return SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 8,
      shadowColor: AppColors.background,
      floating: true,
      snap: true,
      pinned: false,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: AppPadding.screen,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: filterLocation,
            isExpanded: true,
            onTap: onDropdownOpen,
            onChanged: onLocationChanged,
            dropdownColor: AppColors.background,
            alignment: Alignment.center, // ensure vertical centering
            icon: SvgPicture.asset(
              'assets/icons/dropdown.svg',
              width: smallScreen ? 20 : 24,
              height: smallScreen ? 20 : 24,
            ),

            // Hint when nothing is selected
            hint: Center(
              child: Text(
                'All Locations',
                style: TextStyle(
                  fontFamily: 'WinnerSans',
                  color: Colors.white,
                  fontSize: baseFontSize,
                ),
              ),
            ),

            // Dropdown items
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Center(
                  child: Text(
                    'All Locations',
                    style: const TextStyle(
                      fontFamily: 'WinnerSans',
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              ...allLocations.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Center(
                    child: Text(
                      value.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'WinnerSans',
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Custom display for the selected value
            selectedItemBuilder: (BuildContext context) {
              return [
                Center(
                  child: Text(
                    'All Locations',
                    style: TextStyle(
                      fontFamily: 'WinnerSans',
                      color: Colors.white,
                      fontSize: baseFontSize,
                    ),
                  ),
                ),
                ...allLocations.map(
                  (value) => Center(
                    child: Text(
                      value.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'WinnerSans',
                        color: Colors.white,
                        fontSize: baseFontSize,
                      ),
                    ),
                  ),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }
}
