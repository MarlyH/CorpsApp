import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EventBrowserAppBar extends StatelessWidget {
  final String? filterLocation;
  final ValueChanged<String?> onLocationChanged;
  final List<String> allLocations;
  final VoidCallback onDropdownOpen;

  /// Filters row (session/date) that snaps with the location row.
  final PreferredSizeWidget? bottom;

  const EventBrowserAppBar({
    super.key,
    required this.filterLocation,
    required this.onLocationChanged,
    required this.allLocations,
    required this.onDropdownOpen,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final smallScreen = screenWidth < 360;
    final double baseFontSize = smallScreen ? 22 : 30;
    const double _toolbarH = 56;

    // Rebuild dropdown when list changes (prevents stale internal state)
    final dropdownKey = ValueKey('loc-dd-${allLocations.join("|")}');

    Widget _centeredLabel(String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'WinnerSans',
              color: Colors.white,
              fontSize: baseFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SvgPicture.asset(
          'assets/icons/dropdown.svg',
          width: smallScreen ? 20 : 24,
          height: smallScreen ? 20 : 24,
        ),
      ],
    );

    return SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      floating: true,
      snap: false,
      pinned: false,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: _toolbarH,
      title: ScrollGuard(
        height: _toolbarH,
        child: Center(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              key: dropdownKey,
              value: filterLocation,
              isExpanded: true,
              onTap: onDropdownOpen,
              onChanged: onLocationChanged,
              dropdownColor: AppColors.background,
              alignment: Alignment.center,
              icon: const SizedBox.shrink(),

              // Centered hint (text and chevron)
              hint: _centeredLabel('All Locations'),

              // Menu items (centered text only in the menu)
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Center(
                    child: Text(
                      'All Locations',
                      style: TextStyle(
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
                        overflow: TextOverflow.ellipsis,
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

              // Centered selected display (text and chevron)
              selectedItemBuilder: (BuildContext context) {
                return <Widget>[
                  _centeredLabel('All Locations'),
                  ...allLocations.map((value) => _centeredLabel(value.toUpperCase())),
                ];
              },
            ),
          ),
        ),
      ),

      // Filters row under the location row (pass a PreferredSize; as set in the HomeFragment)
      bottom: bottom,
    );
  }
}

/// Public, reusable guard that prevents vertical drag in header areas
/// from starting a scroll, but still lets child controls handle taps/gestures.
/// - `deferToChild`: children win; empty gaps fall back to this absorber.
/// - `onVerticalDragDown`: grabs the gesture before the scroll view can.
class ScrollGuard extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final double? height;

  const ScrollGuard({super.key, required this.child, this.height});

  @override
  Size get preferredSize => Size.fromHeight(height ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onVerticalDragDown: (_) {},   // claim drag before scroll view
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) {},
        onVerticalDragEnd: (_) {},
        child: child,
      ),
    );
  }
}
