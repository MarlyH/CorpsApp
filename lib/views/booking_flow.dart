import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/Modals/add_child.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/booking_terms.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/event_header.dart';
import 'package:corpsapp/widgets/seat_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../models/event_summary.dart' show EventSummary;
import '../models/event_detail.dart' show EventDetail;
import '../models/child_model.dart';

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
              EventHeader(event: widget.event, detailFuture: _detailFut, mascotUrl: _mascotUrl),
   
            // content
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  // always Terms first
                  TermsView(onCancel: _back, onAgree: _next),
                  SeatPickerSheet(
                    isReserveFlow: false,
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
                        label: 'AGREE',
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


