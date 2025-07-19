import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/location.dart';
import '../services/auth_http_client.dart';
import '../services/token_service.dart';

enum SessionType { Ages8to11, Ages12to15 }
const _sessionTypeValues = {
  SessionType.Ages8to11: 0,
  SessionType.Ages12to15: 1,
};

class CreateEventView extends StatefulWidget {
  const CreateEventView({super.key});
  @override
  State<CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  final _formKey    = GlobalKey<FormState>();
  final _addressCtl = TextEditingController();
  final _descCtl    = TextEditingController();
  final _seatsCtl   = TextEditingController();

  SessionType? _sessionType;
  Location?    _location;
  DateTime?    _eventDate;
  TimeOfDay?   _startTime;
  TimeOfDay?   _endTime;
  DateTime?    _availableDate;
  File?        _seatMapFile;

  bool _isLoading = false;
  List<Location> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await AuthHttpClient.fetchLocations();
      setState(() => _locations = locs);
    } catch (_) {
      // Optionally show an error
    }
  }

  Future<void> _pickSeatMap() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res?.files.single.path != null) {
      setState(() => _seatMapFile = File(res!.files.single.path!));
    }
  }

  Future<void> _pickDate({ required bool eventDate }) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate:  now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) {
      setState(() {
        if (eventDate) {
          _eventDate = d;
        } else {
          _availableDate = d;
        }
      });
    }
  }

  Future<void> _pickTime({ required bool start }) async {
    final now = TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: now);
    if (t != null) {
      setState(() {
        if (start) {
          _startTime = t;
        } else {
          _endTime = t;
        }
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  InputDecoration _inputDecoration({
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
  }) =>
    InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(8),
      ),
    );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sessionType == null ||
        _location == null ||
        _eventDate == null ||
        _startTime == null ||
        _endTime == null ||
        _availableDate == null
    ) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.'))
      );
      return;
    }

    if (_availableDate!.isAfter(_eventDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking date must be on or before event date.'))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
      final uri  = Uri.parse('$base/api/events');
      final req  = http.MultipartRequest('POST', uri);

      final token = await TokenService.getAccessToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';

      req.fields
        ..['locationId']      = _location!.id.toString()
        ..['sessionType']     = _sessionTypeValues[_sessionType]!.toString()
        ..['startDate']       = _fmtDate(_eventDate!)
        ..['startTime']       = _fmtTime(_startTime!)
        ..['endTime']         = _fmtTime(_endTime!)
        ..['availableDate']   = _fmtDate(_availableDate!)
        ..['totalSeats']      = _seatsCtl.text.trim()
        ..['address']         = _addressCtl.text.trim()
        ..['description']     = _descCtl.text.trim();

      if (_seatMapFile != null) {
        req.files.add(await http.MultipartFile.fromPath(
          'seatingMapImage',
          _seatMapFile!.path,
          filename: p.basename(_seatMapFile!.path),
        ));
      }

      final streamed = await req.send();
      final resp     = await http.Response.fromStream(streamed);
      final data     = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      final msg      = data?['message']
          ?? (resp.statusCode == 200 ? 'Event created!' : 'Error ${resp.statusCode}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.black)),
          backgroundColor: resp.statusCode == 200 ? Colors.white : Colors.redAccent,
        ),
      );
      if (resp.statusCode == 200) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent)
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('CREATE AN EVENT' ,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold , fontSize: 28, )),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Session Type
                const Text('Session Type', style: TextStyle(color: Colors.white70)),
                Row(children: [
                  Expanded(child: RadioListTile<SessionType>(
                    title: const Text('Ages 8–11', style: TextStyle(color: Colors.white)),
                    value: SessionType.Ages8to11,
                    groupValue: _sessionType,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() => _sessionType = v),
                  )),
                  Expanded(child: RadioListTile<SessionType>(
                    title: const Text('Ages 12–15', style: TextStyle(color: Colors.white)),
                    value: SessionType.Ages12to15,
                    groupValue: _sessionType,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() => _sessionType = v),
                  )),
                ]),

                const SizedBox(height: 16),
                // Location
                const Text('Location', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Location>(
                  decoration: _inputDecoration(hintText: 'Select city or town'),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  items: _locations.map((loc) => DropdownMenuItem<Location>(
                    value: loc,
                    child: Text(loc.name, style: const TextStyle(color: Colors.black)),
                  )).toList(),
                  value: _location,
                  onChanged: (v) => setState(() => _location = v),
                  validator: (v) => v == null ? 'Please select a location' : null,
                ),

                const SizedBox(height: 16),
                // Address
                const Text('Address', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressCtl,
                  decoration: _inputDecoration(hintText: 'Enter venue address'),
                  style: const TextStyle(color: Colors.black),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),

                const SizedBox(height: 16),
                // Date & Time section
                const Text('Date & Time', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                // Event Date
                TextFormField(
                  style: const TextStyle(color: Colors.black),
                  readOnly: true,
                  onTap: () => _pickDate(eventDate: true),
                  decoration: _inputDecoration(
                    hintText: 'Select the date the event will take place',
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.black54),
                  ),
                  controller: TextEditingController(
                    text: _eventDate == null ? '' : _fmtDate(_eventDate!),
                  ),
                  validator: (_) => _eventDate == null ? 'Required' : null,
                ),

                const SizedBox(height: 12),
                // Time range
                Row(children: [
                  Expanded(child: TextFormField(
                    style: const TextStyle(color: Colors.black),
                    readOnly: true,
                    onTap: () => _pickTime(start: true),
                    decoration: _inputDecoration(
                      hintText: 'Time',
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ),
                    controller: TextEditingController(
                      text: _startTime == null ? '' : _startTime!.format(context),
                    ),
                    validator: (_) => _startTime == null ? 'Req.' : null,
                  )),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to', style: TextStyle(color: Colors.white70)),
                  ),
                  Expanded(child: TextFormField(
                    style: const TextStyle(color: Colors.black),
                    readOnly: true,
                    onTap: () => _pickTime(start: false),
                    decoration: _inputDecoration(
                      hintText: 'Time',
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ),
                    controller: TextEditingController(
                      text: _endTime == null ? '' : _endTime!.format(context),
                    ),
                    validator: (_) => _endTime == null ? 'Req.' : null,
                  )),
                ]),

                const SizedBox(height: 12),
                // Booking Opens On
                TextFormField(
                  style: const TextStyle(color: Colors.black),
                  readOnly: true,
                  onTap: () => _pickDate(eventDate: false),
                  decoration: _inputDecoration(
                    hintText: 'Make booking available on',
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.black54),
                  ),
                  controller: TextEditingController(
                    text: _availableDate == null ? '' : _fmtDate(_availableDate!),
                  ),
                  validator: (_) => _availableDate == null ? 'Required' : null,
                ),

                const SizedBox(height: 16),
                // Seats map (optional)
                const Text('Seats map', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickSeatMap,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: _seatMapFile == null
                          ? const Text('Upload Seat Map',
                              style: TextStyle(color: Colors.black38))
                          : Text(p.basename(_seatMapFile!.path),
                              style: const TextStyle(color: Colors.black)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Total seats
                Row(children: [
                  const Expanded(
                    flex: 2,
                    child: Text('Total number of seats',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _seatsCtl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ),
                      style: const TextStyle(color: Colors.black),
                      validator: (v) {
                        if (v == null || int.tryParse(v.trim()) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),

                const SizedBox(height: 16),
                // Description
                const Text('Description', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtl,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hintText: 'Enter a description, additional notes or requirements for the event.',
                  ),
                  style: const TextStyle(color: Colors.black),
                ),

                const SizedBox(height: 24),
                // Create Event Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CREATE EVENT',
                            style: TextStyle(fontSize: 16, color: Colors.white
                            

                          ),
                  ),
                ),
                ),
              ],
          ),
        ),
      ),
    ),
    );
  }
}
