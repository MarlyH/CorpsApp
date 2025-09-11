import '../models/event_summary.dart' as event_summary;
import 'package:flutter/material.dart';

class FilterSheet extends StatefulWidget {
  final event_summary.SessionType? initialSession;
  final bool initialDateAsc;
  final bool initialDateDesc;
  final bool initialSeatsAsc;
  final bool initialSeatsDesc;
  final void Function(event_summary.SessionType?, bool, bool, bool, bool)
  onApply;

  const FilterSheet({
    this.initialSession,
    required this.initialDateAsc,
    required this.initialDateDesc,
    required this.initialSeatsAsc,
    required this.initialSeatsDesc,
    required this.onApply,
  });

  @override
  FilterSheetState createState() => FilterSheetState();
}

/// Helper for formatting session types.
String friendlySession(event_summary.SessionType type) {
  switch (type) {
    case event_summary.SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case event_summary.SessionType.Ages12to15:
      return 'Ages 12 to 15';
    default:
      return 'Ages 16+';
  }
}

class FilterSheetState extends State<FilterSheet> {
  late event_summary.SessionType? _session;
  late bool _dateAsc, _dateDesc, _seatsAsc, _seatsDesc;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _dateAsc = widget.initialDateAsc;
    _dateDesc = widget.initialDateDesc;
    _seatsAsc = widget.initialSeatsAsc;
    _seatsDesc = widget.initialSeatsDesc;
  }

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(c).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter & Sort',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const Divider(color: Colors.white54),

          // Session Type
          ListTile(
            title: const Text(
              'Session Ages',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: DropdownButton<event_summary.SessionType?>(
              dropdownColor: Colors.grey[800],
              value: _session,
              hint: const Text('All Ages', style: TextStyle(color: Colors.white)),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Ages', style: TextStyle(color: Colors.white)),
                ),
                for (var st in event_summary.SessionType.values)
                  DropdownMenuItem(
                    value: st,
                    child: Text(
                      friendlySession(st),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _session = v),
            ),
          ),

          // Date Ascending
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.blue,
            title: const Text(
              'Date Ascending',
              style: TextStyle(color: Colors.white70),
            ),
            value: _dateAsc,
            onChanged: (v) {
              setState(() {
                _dateAsc = v!;
                if (v) _dateDesc = false;
              });
            },
          ),
          // Date Descending
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.blue,
            title: const Text(
              'Date Descending',
              style: TextStyle(color: Colors.white70),
            ),
            value: _dateDesc,
            onChanged: (v) {
              setState(() {
                _dateDesc = v!;
                if (v) _dateAsc = false;
              });
            },
          ),

          // Seats Ascending
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.blue,
            title: const Text(
              'Seats Ascending',
              style: TextStyle(color: Colors.white70),
            ),
            value: _seatsAsc,
            onChanged: (v) {
              setState(() {
                _seatsAsc = v!;
                if (v) _seatsDesc = false;
              });
            },
          ),
          // Seats Descending
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.blue,
            title: const Text(
              'Seats Descending',
              style: TextStyle(color: Colors.white70),
            ),
            value: _seatsDesc,
            onChanged: (v) {
              setState(() {
                _seatsDesc = v!;
                if (v) _seatsAsc = false;
              });
            },
          ),

          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              widget.onApply(
                _session,
                _dateAsc,
                _dateDesc,
                _seatsAsc,
                _seatsDesc,
              );
              Navigator.of(context).pop();
            },
            child: const Text('APPLY'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}