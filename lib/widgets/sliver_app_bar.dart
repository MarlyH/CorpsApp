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
    return SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 8,
      shadowColor: Colors.black54,
      floating: true,
      snap: true,
      pinned: false,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 0,

      // Toolbar with padding
      title: Padding(
        padding: AppPadding.screen,
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: filterLocation,
                  icon: SvgPicture.asset(
                    'assets/icons/dropdown.svg',
                    width: 24,
                    height: 24,
                  ),
                  dropdownColor: Colors.grey[900],
                  isExpanded: true,
                  onTap: onDropdownOpen,

                  //use as palceholder when nothings on the list
                  hint: const Text(
                    'All Locations',
                    style: TextStyle(
                      fontFamily: 'WinnerSans',
                      color: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                  
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'All Locations',
                        style: TextStyle(
                          fontFamily: 'WinnerSans',
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    ...allLocations.map(
                      (value) => DropdownMenuItem<String?>(
                        value: value,
                        child: Text(
                          value.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'WinnerSans',
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: onLocationChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
