import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/Modals/add_child.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/booking_terms.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../models/event_summary.dart' show EventSummary, friendlySession;
import '../models/event_detail.dart' show EventDetail;
import '../models/child_model.dart';
import 'package:intl/intl.dart';

class MedicalItem {
  MedicalItem({required this.name, this.notes = '', this.isAllergy = false});
  String name;
  String notes;
  bool isAllergy;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'notes': notes.trim(),
        'isAllergy': isAllergy,
      };
}

class BookingFlow extends StatefulWidget {
  final EventSummary event;
  const BookingFlow({super.key, required this.event});

  @override
  _BookingFlowState createState() => _BookingFlowState();
}

class _BookingFlowState extends State<BookingFlow> {
  int _step = 0;
  int? _selectedSeat;
  String? _selectedChildId;
  bool? _allowAlone; // null = not chosen yet

  List<ChildModel> _children = [];
  late Future<EventDetail> _detailFut;
  String? _mascotUrl; // ← URL from GET /api/locations/{id}

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _detailFut = _loadEventDetail();

    // If we don't need the full flow (no attendee step), force false
    if (!_needsFullFlow) {
      _allowAlone = false;
    }
  }


  String _format12h(String? raw, ) {
    if (raw == null) return '—';
    final s = raw.trim();
    if (s.isEmpty) return '—';
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(s);
    if (m == null) return s; // fallback if unexpected
    final h = int.tryParse(m.group(1)!) ?? 0;
    final min = int.tryParse(m.group(2)!) ?? 0;
    final dt = DateTime(2000, 1, 1, h, min);
    return DateFormat('h:mm a',).format(dt); // e.g., 1:05 PM
  }

  Future<void> _loadChildren() async {
    try {
      final resp = await AuthHttpClient.fetchChildren();
      final list = jsonDecode(resp.body) as List<dynamic>;
      setState(() {
        _children =
            list.cast<Map<String, dynamic>>().map(ChildModel.fromJson).toList();
      });
    } catch (_) {}
  }

  Future<EventDetail> _loadEventDetail() async {
  final resp = await AuthHttpClient.get(
    '/api/events/${widget.event.eventId}',
  );

  if (resp.statusCode == 200) {
    final jsonData = jsonDecode(resp.body) as Map<String, dynamic>;
    final detail = EventDetail.fromJson(jsonData);

    // Assign locationMascotImgSrc to _mascotUrl
    final mascotUrl = jsonData['locationMascotImgSrc'] as String?;
    if (mascotUrl != null &&
        mascotUrl.isNotEmpty) {
      _mascotUrl = mascotUrl;
    } else {
      _mascotUrl = null;
    }

    return detail;
  } else {
    throw Exception('Failed to load event detail: ${resp.statusCode}');
  }
}

  bool get _needsFullFlow {
    final age = context.read<AuthProvider>().userProfile?['age'] as int? ?? 0;
    return age >= 16;
  }

  void _next() async {
  final last = _needsFullFlow ? 3 : 2;

  if (_step < last) {
    setState(() => _step++);
  } else {
    _submitBooking();
  }
}

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitBooking() async {
    final isChild = _selectedChildId != null;
    final canLeave = _needsFullFlow ? (_allowAlone ?? false) : false;

    final dto = {
      'eventId': widget.event.eventId,
      'seatNumber': _selectedSeat,
      'isForChild': isChild,
      'childId': isChild ? int.parse(_selectedChildId!) : null,
      'canBeLeftAlone': canLeave, // guaranteed non-null, false for short flow
    };

    try {
      await AuthHttpClient.post('/api/booking', body: dto);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking successful!'),
          backgroundColor: Colors.white,
        ),
      );

      Navigator.pop(context, true);
    } catch (errorMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage.toString()),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // fullFlow has 4 pages, under16 has 3
    final totalSteps = _needsFullFlow ? 4 : 3;
    // only hide nav on Terms (step 0)
    //final showNav = _step > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: AppPadding.screen.copyWith(bottom:MediaQuery.of(context).padding.bottom + 8),
          child: Column(
          children: [
            if (_step > 0)
              _buildHeader(),
   
            // content
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  // always Terms first
                  TermsView(onCancel: _back, onAgree: _next),
                  _SeatPickerSheet(
                    futureDetail: _detailFut,
                    initialSelected: _selectedSeat,
                    eventTotalSeats: widget.event.totalSeats,
                    onSeatPicked: (seat) {
                      setState(() {
                        _selectedSeat = seat;
                      });
                    }, 
                  ),
                  if (_needsFullFlow) _attendeeView(),
                  _confirmView(),
                ],
              ),
            ),

            // BACK / NEXT bar
              Row(
                children: [
                  if (_step == 0) ...[
                    IntrinsicWidth(
                      child: Button(
                      label: 'CANCEL',
                      onPressed: _back,
                      isCancelOrBack: true,             
                      fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 16,
                      ),
                    ),
                    
                    const SizedBox(width: 12),

                    Expanded(
                      child: Button(
                        label: 'AGREE & CONTINUE',
                        onPressed: _next,
                        fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 16,
                      ),
                    ),

                  ] else ...[

                    // Both buttons take equal space
                    Expanded(
                      child: Button(
                        label: 'BACK',
                        onPressed: _back,
                        isCancelOrBack: true,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Button(
                        label: _step == totalSteps - 1 ? 'COMPLETE' : 'NEXT',
                        onPressed: (_step == 1 && _selectedSeat == null) ||
                                   (_needsFullFlow && _step == 2 && (_allowAlone == null || _selectedChildId == null))
                            ? null
                            : _next,
                      ),
                    ),
                  ],
                ],
              )
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final e = widget.event;
    final screenWidth = MediaQuery.of(context).size.width;
    final double avatarSize = screenWidth < 360 ? 80 : 140;

    Widget avatar;

    if (_mascotUrl == null) {
      avatar = Image.asset(
        'assets/logo/logo_transparent_1024px.png',
        width: avatarSize,
        height: avatarSize,
      );
    } else {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _mascotUrl!,
          height: avatarSize,
          width: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/logo/logo_transparent_1024px.png',
            width: avatarSize,
            height: avatarSize,
            color: Colors.white30,
          ),
        ),
      );
    }          

    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Column(
        children: [
          Row(
            children: [             
              avatar,
              const SizedBox(width: 16),
              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headerDate(e.startDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      friendlySession(e.sessionType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Text(
                          _format12h(e.startTime),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),

                        const Text(
                          ' • ',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        
                        Expanded(
                          child: FutureBuilder<EventDetail>(
                            future: _detailFut,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Text(
                                  'Loading...',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                );
                              } else if (snapshot.hasError) {
                                return const Text(
                                  '—',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                );
                              } else {
                                return Text(
                                  snapshot.data?.address ?? '—',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.visible,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white30, height: 1),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ... make sure you still have this helper below in the same file:
  String _headerDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }


  // ATTENDEE DETAILS
  Widget _attendeeView() {
    return SingleChildScrollView(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Attendee',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownMenu<String>(
                  key: ValueKey('${_selectedChildId ?? 'none'}|${_children.length}'),
                  width: MediaQuery.of(context).size.width,
                  initialSelection: _selectedChildId,
                  hintText: "Select Child",
                  textStyle: const TextStyle(
                    color: AppColors.normalText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  leadingIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.normalText,
                  ),
                  trailingIcon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.normalText,
                    size: 20,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: const TextStyle(
                      color: Color(0xFFA3A3A3),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  menuStyle: MenuStyle(                   
                    backgroundColor: WidgetStatePropertyAll(Colors.white),                   
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    padding: WidgetStatePropertyAll(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    elevation: WidgetStatePropertyAll(4),
                  ),
                  onSelected: (v) async {
                    if (v == 'ADD') {
                      setState(() => _selectedChildId = null);

                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => AddChildModal(
                          onChildAdded: (newChildId) async {
                            if (newChildId != null) {
                              await _loadChildren();
                              setState(() => _selectedChildId = newChildId);
                            }
                          },
                        ),
                      );
                    } else {
                      setState(() => _selectedChildId = v);
                    }
                  },
                  dropdownMenuEntries: [
                    for (final c in _children)
                      DropdownMenuEntry<String>(
                        value: c.childId.toString(),
                        label: '${c.firstName} ${c.lastName}',
                        style: ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(AppColors.normalText),
                        ),
                      ),
                    DropdownMenuEntry<String>(
                      value: 'ADD',
                      label: 'Add Child',
                      style: ButtonStyle(
                        alignment: Alignment.center,
                        foregroundColor: WidgetStatePropertyAll(AppColors.primaryColor),
                        textStyle: WidgetStatePropertyAll(
                          const TextStyle(fontWeight: FontWeight.bold),                       
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white30, height: 1),
            const SizedBox(height: 16),
            
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permission to Leave',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Text(
                    'Do you allow child to leave on their own after the event?',
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 4),

                  // Yes, allow child to leave                 
                  ListTile(
                    leading: Radio<bool?>(
                      value: false,                
                      groupValue: _allowAlone,     
                      onChanged: (v) async {
                        if (v == false) {
                          final ok = await _confirmPermissionChange(true); 
                          if (ok) setState(() => _allowAlone = false);     
                        }
                      },
                      activeColor: AppColors.primaryColor,
                    ),
                    onTap: () async {
                      // tap behavior: if already selected -> clear (null). Otherwise ask confirmation and set false.
                      if (_allowAlone == false) {
                        setState(() => _allowAlone = null); 
                      } else {
                        final ok = await _confirmPermissionChange(true);
                        if (ok) setState(() => _allowAlone = false);
                      }
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 0,
                    horizontalTitleGap: 4,
                    title: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Yes', 
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ', allow the child to leave on their own.',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // No, parent/guardian will collect
                  ListTile(
                    leading: Radio<bool?>(
                      value: true,                 
                      groupValue: _allowAlone,     
                      onChanged: (v) async {
                        if (v == true) {
                          final ok = await _confirmPermissionChange(false); 
                          if (ok) setState(() => _allowAlone = true);
                        }
                      },
                      activeColor: AppColors.primaryColor,
                    ),
                    onTap: () async {
                      if (_allowAlone == true) {
                        setState(() => _allowAlone = null); 
                      } else {
                        final ok = await _confirmPermissionChange(false);
                        if (ok) setState(() => _allowAlone = true);
                      }
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 0,
                    horizontalTitleGap: 4,
                    title: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'No', 
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ', an authorised parent/guardian must pick the child up.',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),                   
                  ),                                       
                ],
              ),           
          ],
        ),
    );
  }

  // CONFIRM
Widget _confirmView() {
  final selectedChild = _children.firstWhere(
    (c) => c.childId.toString() == _selectedChildId,
    orElse: () => ChildModel(
      childId: -1,
      firstName: '',
      lastName: '',
      dateOfBirth: '',
      emergencyContactName: '',
      emergencyContactPhone: '',
      age: 0,
      ageGroup: '',
      ageGroupLabel: ''
    ),
  );

  final childName = '${selectedChild.firstName} ${selectedChild.lastName}';

  return Center(
    child: Text(
      'About to book Ticket #$_selectedSeat\nfor $childName',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16),
    ),
  );
}

  Future<bool> _confirmPermissionChange(bool allowAlone) async {
    final title = allowAlone
        ? 'Allow Child to Leave Alone?'
        : 'Require Parent/Guardian to Pick Up?';

    final body = allowAlone
      ? 'You consent to your child leaving the venue on their own after the event concludes.\n\n'
        'Your Corps will not be responsible for the child’s safety once they leave the venue.'
      : 'Your child is not allowed to leave on their own and must be picked up by an authorised parent/guardian.\n\n'
        "The parent/guardian must present the ticket's QR code when picking them up at after the event.\n\n"
        'Your child will remain at the venue under supervision until they are claimed with the QR code.';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomAlertDialog(
        title: title,
        info: body,
        buttonAction: () => Navigator.of(ctx).pop(true),
        buttonLabel: 'Confirm',
        cancel: true,
      ),
    );

    return result == true;
  } 
}
 
class _SeatPickerSheet extends StatefulWidget {
  final Future<EventDetail> futureDetail;
  final int? initialSelected;
  final int eventTotalSeats; // from EventSummary (non-nullable)
  final ValueChanged<int> onSeatPicked;

  const _SeatPickerSheet({
    required this.futureDetail,
    required this.initialSelected,
    required this.eventTotalSeats,
    required this.onSeatPicked,
  });

  @override
  State<_SeatPickerSheet> createState() => _SeatPickerSheetState();
}

class _SeatPickerSheetState extends State<_SeatPickerSheet> {
  int? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header         
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select a Ticket Number',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),                             
              ],
            ),    

            const SizedBox(height: 4),  

            Text(
              'Select a lucky number to represent your ticket for this event. This number does not represent a physical seat.',
              style: TextStyle(
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),    

            const SizedBox(height: 16),
                                                                  
            // Content
            Expanded(
              child: FutureBuilder<EventDetail>(
                future: widget.futureDetail,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return const Center(
                      child: Text('Error loading Tickets',
                          style: TextStyle(color: AppColors.errorColor)),
                    );
                  }

                  final detail = snap.data!;
                  final availableSeats = detail.availableSeats.toSet();

                  // Determine total seats:
                  // Prefer EventDetail.totalSeats (if present) → EventSummary.totalSeats (passed in) → highest available seat number
                  int totalSeats = 0;
                  final int? detailTotal = detail.totalSeats; 
                  if (detailTotal != null && detailTotal > 0) {
                    totalSeats = detailTotal;
                  } else if (widget.eventTotalSeats > 0) {
                    totalSeats = widget.eventTotalSeats;
                  } else {
                    totalSeats = availableSeats.isNotEmpty
                        ? availableSeats.reduce((a, b) => a > b ? a : b)
                        : 0;
                  }

                  //this should never happen
                  if (totalSeats <= 0) {
                    return const Center(
                      child: Text('No tickets available',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Legend
                        Row(
                          children: const [
                            _LegendSwatch(color: Colors.white, border: Colors.white24),
                            SizedBox(width: 4),
                            Text('Available', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Color(0xFF67788E), border: Colors.white24),
                            SizedBox(width: 4),
                            Text('Taken', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Color(0xFF4C85D0), border: Colors.transparent),
                            SizedBox(width: 4),
                            Text('Selected', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),

                        // Grid (scrolls independently)
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.2,
                            ),

                            itemCount: totalSeats,
                            itemBuilder: (_, idx) {
                              final seat = idx + 1;
                              final available = availableSeats.contains(seat);
                              final selected = _picked == seat;

                              return _SeatTile(
                                seat: seat,
                                available: available,
                                selected: selected,
                                onTap: available
                                    ? () {
                                        setState(() => _picked = seat);
                                        widget.onSeatPicked(seat); 
                                      }
                                    : null,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),                                          
                      ],
                    );                
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// widgets used inside the sheet for the seat tiles and legend
class _SeatTile extends StatelessWidget {
  final int seat;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _SeatTile({
    required this.seat,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !available
        ? const Color(0xFF67788E)
        : (selected ? const Color(0xFF4C85D0) : Colors.white);
    final fg = !available
        ? const Color.fromARGB(255, 255, 255, 255)
        : (selected ? Colors.white : Colors.black87);
    final border = selected ? const Color(0xFF4C85D0) : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!available) const SizedBox(width: 6),
              Text(
                seat.toString(),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final Color border;
  const _LegendSwatch({required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
    );
  }
}


