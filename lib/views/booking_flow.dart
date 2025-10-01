import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
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

String _cap(String s) =>
    s.split(RegExp(r'\s+'))
     .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
     .join(' ');

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

  // On Attendee step in full flow, require a selection
  if (_needsFullFlow && _step == 2 && _allowAlone == null) {
    await _showPermissionInfoDialog();
    return;
  }

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
          content: Text('Booking successful'),
          backgroundColor: Colors.white,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
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
                      buttonColor: AppColors.disabled,
                      ),
                    ),
                    
                    const SizedBox(width: 12),

                    Expanded(
                      child: Button(
                        label: 'AGREE & CONTINUE',
                        onPressed: _next,
                      ),
                    ),

                  ] else ...[

                    // Both buttons take equal space
                    Expanded(
                      child: Button(
                        label: 'BACK',
                        onPressed: _back,
                        buttonColor: AppColors.disabled,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Button(
                        label: _step == totalSteps - 1 ? 'COMPLETE' : 'NEXT',
                        onPressed: (_step == 1 && _selectedSeat == null) ||
                                  (_needsFullFlow && _step == 2 && _allowAlone == null)
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
                  onSelected: (v) {
                    if (v == 'ADD') {
                      _showAddChildDialog();
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

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permission to Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Allow child to leave on their own after the event?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  // YES: child may leave on their own  -> (store inverted) _allowAlone = false
                  CheckboxListTile(
                    value: _allowAlone == false, // inverted binding
                    onChanged: (v) async {
                      if (v == true) {
                        final ok = await _confirmPermissionChange(true); // UI meaning = YES
                        if (ok) setState(() => _allowAlone = false);     // invert when storing
                      } else {
                        setState(() => _allowAlone = null); // uncheck -> no selection
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Yes, my child may leave on their own',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  // NO: parent/guardian will collect  -> (store inverted) _allowAlone = true
                  CheckboxListTile(
                    value: _allowAlone == true, // inverted binding
                    onChanged: (v) async {
                      if (v == true) {
                        final ok = await _confirmPermissionChange(false); // UI meaning = NO
                        if (ok) setState(() => _allowAlone = true);        // invert when storing
                      } else {
                        setState(() => _allowAlone = null); // uncheck -> no selection
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'No, an authorised parent/guardian will collect',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Authorised person must present the QR code for handover.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),

                  if (_allowAlone == null)
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        'Please choose one option to continue.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  // CONFIRM

  Widget _confirmView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'About to book ticket #$_selectedSeat\nfor ${widget.event.locationName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
  Future<bool> _confirmPermissionChange(bool allowAlone) async {
    final title = allowAlone
        ? 'Confirm: Child May Leave Alone'
        : 'Confirm: Guardian Pickup Required';

    final body = allowAlone
        ? const [
            Text(
              'By selecting YES, you consent to your child leaving the venue on their own after the event concludes.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              '• Your Corps is not responsible for the child’s safety once they leave the venue.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              '• Staff will perform a manual sign-out at conclusion.',
              style: TextStyle(height: 1.4),
            ),
          ]
        : const [
            Text(
              'By selecting NO, your child must be checked in and checked out by an authorised parent/guardian.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              '• The authorised person must scan the child’s QR code on entry and again when collecting at the end.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              '• Your child will remain at the venue under supervision until they are claimed with the QR code.',
              style: TextStyle(height: 1.4),
            ),
          ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    return result == true;
  }

  
  Future<void> _showPermissionInfoDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission to Leave'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please choose one option before continuing.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('YES – Child may leave on their own after the event.'),
              SizedBox(height: 4),
              Text('• You consent to your child leaving independently.', style: TextStyle(height: 1.4)),
              Text('• Your Corps is not responsible once they leave the venue.', style: TextStyle(height: 1.4)),
              Text('• Staff will perform a manual sign-out at conclusion.', style: TextStyle(height: 1.4)),
              SizedBox(height: 12),
              Text('NO – An authorised parent/guardian will collect.'),
              SizedBox(height: 4),
              Text('• The authorised person must scan the QR code to check in and check out.', style: TextStyle(height: 1.4)),
              Text('• The child remains at the venue until they are claimed with the QR code.', style: TextStyle(height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  // ADD CHILD DIALOG
  Future<void> _showAddChildDialog() async {
    final fn = TextEditingController();
    final ln = TextEditingController();
    final emName = TextEditingController();
    final emPhone = TextEditingController();
    DateTime? dob;

    // NEW: medical state for the dialog
    bool hasMedical = false;
    final List<MedicalItem> medicalItems = [];

    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setSb) {
            Future<void> addMedical() async {
              final item = await showModalBottomSheet<MedicalItem>(
                context: dialogCtx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom +
                          MediaQuery.of(ctx).padding.bottom +
                          16,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: const _MedicalEditor(),
                  ),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              );
              if (item != null) setSb(() => medicalItems.add(item));
            }

            Future<void> editMedical(int i) async {
              final updated = await showModalBottomSheet<MedicalItem>(
                context: dialogCtx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom +
                          MediaQuery.of(ctx).padding.bottom +
                          16,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: _MedicalEditor(initial: medicalItems[i]),
                  ),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              );
              if (updated != null) setSb(() => medicalItems[i] = updated);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Container(
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add New Child',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'WinnerSans',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // First Name
                        _label('First Name'),
                        TextField(
                          controller: fn,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.black),
                          decoration: _decWhite(
                            hint: 'e.g. Jane',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        _label('Last Name'),
                        TextField(
                          controller: ln,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.black),
                          decoration: _decWhite(
                            hint: 'e.g. Doe',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // DOB
                        _label('Date of Birth'),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: sbCtx,
                              initialDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
                              firstDate: DateTime(2005),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setSb(() => dob = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.black54),
                                const SizedBox(width: 12),
                                Text(
                                  dob == null
                                      ? 'Tap to select date'
                                      : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: dob == null ? Colors.black38 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Emergency Name
                        _label('Emergency Contact Name'),
                        TextField(
                          controller: emName,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.black),
                          decoration: _decWhite(
                            hint: 'e.g. John Doe',
                            icon: Icons.contact_phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Emergency Phone
                        _label('Emergency Contact Phone'),
                        TextField(
                          controller: emPhone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.black),
                          decoration: _decWhite(
                            hint: '(555) 123-4567',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MEDICAL TOGGLE
                        SwitchListTile.adaptive(
                          value: hasMedical,
                          onChanged: (v) => setSb(() => hasMedical = v),
                          activeColor: Colors.blueAccent,
                          title: const Text(
                            'Has medical conditions or allergies?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'If enabled, add one or more items below.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (hasMedical) ...[
                          const SizedBox(height: 8),
                          medicalItems.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121212),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: const Text(
                                    'No items yet. Tap "Add Condition/Allergy" to add one.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: medicalItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final it = medicalItems[i];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF121212),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (it.isAllergy)
                                                      const Padding(
                                                        padding: EdgeInsets.only(right: 6),
                                                        child: Icon(Icons.warning_amber_rounded,
                                                            size: 16, color: Colors.amber),
                                                      ),
                                                    Flexible(
                                                      child: Text(
                                                        it.name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (it.notes.trim().isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(it.notes, style: const TextStyle(color: Colors.white70)),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => editMedical(i),
                                            icon: const Icon(Icons.edit, color: Colors.white70),
                                          ),
                                          IconButton(
                                            onPressed: () => setSb(() => medicalItems.removeAt(i)),
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: addMedical,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('ADD CONDITION/ALLERGY', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Submit
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  // basic validation
                                  if (fn.text.trim().isEmpty ||
                                      ln.text.trim().isEmpty ||
                                      dob == null ||
                                      emName.text.trim().isEmpty ||
                                      emPhone.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please fill out all fields', style: TextStyle(color: Colors.black)),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  // medical validation
                                  if (hasMedical && medicalItems.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please add at least one condition/allergy or turn the toggle off.',
                                            style: TextStyle(color: Colors.black)),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  setSb(() => isSubmitting = true);
                                  try {
                                    final body = {
                                      'firstName': _cap(fn.text.trim()),
                                      'lastName': _cap(ln.text.trim()),
                                      'dateOfBirth': dob!.toIso8601String().split('T').first,
                                      'emergencyContactName': _cap(emName.text.trim()),
                                      'emergencyContactPhone': emPhone.text.trim(),
                                      'hasMedicalConditions': hasMedical,
                                      if (hasMedical)
                                        'medicalConditions': medicalItems.map((m) => m.toJson()).toList(),
                                    };

                                    final res = await AuthHttpClient.post('/api/child', body: body);

                                    // try to select newly created child if id returned
                                    int? newId;
                                    try {
                                      final j = jsonDecode(res.body);
                                      if (j is Map && j['childId'] != null) newId = (j['childId'] as num).toInt();
                                    } catch (_) {}

                                    await _loadChildren();
                                    if (newId != null) {
                                      setState(() => _selectedChildId = newId.toString());
                                    }
                                    Navigator.of(dialogCtx).pop();
                                  } catch (e) {
                                    setSb(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Could not add child: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : const Text('ADD CHILD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // small label + white input helper (keeps your current look)
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
  );

  InputDecoration _decWhite({required String hint, required IconData icon}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: Icon(icon, color: Colors.black54),
  );

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
            const SizedBox(height: 16),

            // Header         
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select a Ticket Number',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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

class _MedicalEditor extends StatefulWidget {
  const _MedicalEditor({this.initial});
  final MedicalItem? initial;

  @override
  State<_MedicalEditor> createState() => _MedicalEditorState();
}

class _MedicalEditorState extends State<_MedicalEditor> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  bool _isAllergy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
    _isAllergy = widget.initial?.isAllergy ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Medical Condition / Allergy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Name (required)'),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _notes,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: _dec('Notes (optional)'),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _isAllergy,
          onChanged: (v) => setState(() => _isAllergy = v),
          activeColor: Colors.amber,
          title: const Text('This is an allergy', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Enable if this item is an allergy (e.g., peanuts, bee stings).',
              style: TextStyle(color: Colors.white70)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_name.text.trim().isEmpty) return;
                    Navigator.pop(
                      context,
                      MedicalItem(
                        name: _name.text.trim(),
                        notes: _notes.text.trim(),
                        isAllergy: _isAllergy,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('SAVE', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}


