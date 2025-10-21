import 'package:corpsapp/models/session_type_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EventsSort extends StatefulWidget {
  final SessionType? session;
  final bool dateAsc;
  final bool dateDesc;
  final void Function(SessionType?, bool, bool) onChanged;

  const EventsSort({
    super.key,
    this.session,
    required this.dateAsc,
    required this.dateDesc,
    required this.onChanged,
  });

  @override
  State<EventsSort> createState() => _EventsSortState();
}

class _EventsSortState extends State<EventsSort> {
  late bool ascending;

  @override
  void initState() {
    super.initState();
    // default to descending if both are false, or use widget’s values
    if (widget.dateDesc) {
      ascending = false;
    } else {
      ascending = widget.dateAsc;
    }
  }

  void _toggleSort() {
    setState(() {
      ascending = !ascending;
    });

    widget.onChanged(
      widget.session,
      ascending,      // dateAsc
      !ascending,     // dateDesc
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleSort,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 4),

          SvgPicture.asset(
            ascending
                ? 'assets/icons/sort_asc.svg'
                : 'assets/icons/sort_desc.svg',
            width: 24,
            height: 24,
          ),        
        ],
      ),
    );
  }
}
