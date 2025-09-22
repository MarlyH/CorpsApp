import 'dart:convert';
import 'package:flutter/material.dart';
import '/services/auth_http_client.dart';

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
            primary: Colors.blue,
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
      builder: (ctx) => SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16,
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
    if (item != null && mounted) {
      setState(() => _medicalItems.add(item));
    }
  }

  Future<void> _editMedicalItem(int index) async {
    final updated = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _MedicalEditor(initial: _medicalItems[index]),
        ),
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Add Child',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _firstName,
                  label: 'First Name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                _field(
                  controller: _lastName,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                _field(
                  controller: _dob,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: _pickDate,
                ),
                _field(
                  controller: _contactName,
                  label: 'Emergency Contact Name',
                  icon: Icons.contact_phone_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                _field(
                  controller: _contactPhone,
                  label: 'Emergency Contact Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _hasMedical,
                  onChanged: (v) => setState(() => _hasMedical = v),
                  activeColor: Colors.blueAccent,
                  title: const Text('Has medical conditions or allergies?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('If enabled, add one or more items below.',
                      style: TextStyle(color: Colors.white70)),
                ),
                if (_hasMedical) ...[
                  const SizedBox(height: 8),
                  _medicalItems.isEmpty
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
                          itemCount: _medicalItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final it = _medicalItems[i];
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
                                              child: Text(it.name,
                                                  style: const TextStyle(
                                                      color: Colors.white, fontWeight: FontWeight.w600)),
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
                                    onPressed: () => _editMedicalItem(i),
                                    icon: const Icon(Icons.edit, color: Colors.white70),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _medicalItems.removeAt(i)),
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
                      onPressed: _addMedicalItem,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('ADD CONDITION/ALLERGY',
                          style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('SAVE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            textCapitalization: textCapitalization,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.black54),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
        ],
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
                  child: const Text('SAVE'),
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
