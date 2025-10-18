import 'dart:convert';
import 'package:corpsapp/models/medical_item.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:corpsapp/widgets/medical_editor.dart';
import 'package:flutter/material.dart';
import '/services/auth_http_client.dart';

class CreateChildView extends StatefulWidget {
  const CreateChildView({super.key});

  @override
  State<CreateChildView> createState() => _CreateChildViewState();
}

class _CreateChildViewState extends State<CreateChildView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  bool _isSaving = false;

  // medical
  bool _hasMedical = false;
  final List<MedicalItem> _medicalItems = [];

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  String _cap(String s) =>
      s.split(RegExp(r'\s+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dob.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_hasMedical && _medicalItems.isEmpty) {
      _snack('Please add at least one condition/allergy or turn the toggle OFF.', err: true);
      return;
    }

    setState(() => _isSaving = true);

    final body = {
      'firstName': _cap(_firstName.text.trim()),
      'lastName': _cap(_lastName.text.trim()),
      'dateOfBirth': _dob.text.trim(),
      'emergencyContactName': _cap(_contactName.text.trim()),
      'emergencyContactPhone': _contactPhone.text.trim(),
      'hasMedicalConditions': _hasMedical,
      if (_hasMedical)
        'medicalConditions': _medicalItems
            .where((m) => m.name.trim().isNotEmpty)
            .map((m) => m.toJson())
            .toList(),
    };

    try {
      final res = await AuthHttpClient.post('/api/child', body: body);
      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final msg = _extractMsg(res.body) ?? 'Failed to create child.';
        _snack(msg, err: true);
      }
    } catch (e) {
      _snack('Network error: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _extractMsg(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] != null) return j['message'].toString();
    } catch (_) {}
    return null;
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _addMedicalItem() async {
    final item = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (item != null && mounted) {
      setState(() => _medicalItems.add(item));
    }
  }

  Future<void> _editMedicalItem(int index) async {
    final updated = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(initial: _medicalItems[index]),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _medicalItems[index] = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Add Child'),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputField(
                  label: 'First Name', 
                  hintText: 'e.g. Jane', 
                  controller: _firstName,
                  prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
                ),    

                const SizedBox(height: 16),

                InputField(
                  label: 'Last Name', 
                  hintText: 'e.g. Doe', 
                  controller: _lastName,
                  prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
                ),

                const SizedBox(height: 16),

                InputField(
                  label: 'Date of Birth', 
                  hintText: 'Select date of birth',
                  controller: _dob,
                  onTap: _pickDate,
                  prefixIcon: Icon(Icons.calendar_today, color: Colors.black54),
                ),
                
                const SizedBox(height: 16),

                InputField(
                  label: 'Emergency Contact Full Name', 
                  hintText: 'e.g. John doe', 
                  controller: _contactName,
                  prefixIcon: Icon(Icons.contact_phone_outlined, color: Colors.black54),
                ),
              
                const SizedBox(height: 16),

                InputField(
                  label: 'Emergency Contact Phone Number', 
                  hintText: '021-555-1234', 
                  controller: _contactPhone,
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.black54),
                ),

                const SizedBox(height: 16),

                SwitchListTile.adaptive(
                  value: _hasMedical,
                  onChanged: (v) => setState(() => _hasMedical = v),
                  activeColor: AppColors.primaryColor,
                  title: const Text(
                    'Does child have any medical conditions or allergies?',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ), 
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 4),              

                if (_hasMedical) ...[
                  const SizedBox(height: 4),
                  Button(
                    label: 'Add condition / allergy', 
                    onPressed: _addMedicalItem,
                    buttonColor: Colors.transparent,
                    borderColor: Colors.white24,
                  ),

                  const SizedBox(height: 16),
                 
                  _medicalItems.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text(
                            'No medical conditions or allergies yet. Tap button above to add one.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _medicalItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final it = _medicalItems[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                                padding: EdgeInsets.only(right: 4),
                                                child: Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 16,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            Flexible(
                                              child: Text(
                                                it.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        //description
                                        if (it.notes.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(it.notes,
                                            style: const TextStyle(color: Colors.white70)
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _editMedicalItem(i),
                                    icon: const Icon(Icons.edit, color: Colors.white),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _medicalItems.removeAt(i)),
                                    icon: const Icon(Icons.delete_outline, color: AppColors.errorColor),
                                  ),
                                ],
                              ),                                         
                            );
                          },
                        ),
                ],

                const SizedBox(height: 16),

                Button(
                  label: 'Save', 
                  onPressed: _save,
                  loading: _isSaving,
                ),               
              ],
            ),
          ),
        ),
      ),
    );
  }
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