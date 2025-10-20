// lib/views/medical_conditions_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class MedicalItem {
  String name;
  String notes;
  bool isAllergy;
  MedicalItem({
    required this.name,
    this.notes = '',
    this.isAllergy = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'notes': notes,
        'isAllergy': isAllergy,
      };

  factory MedicalItem.fromJson(Map<String, dynamic> j) => MedicalItem(
        name: (j['name'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        isAllergy: (j['isAllergy'] as bool?) ?? false,
      );
}

class MedicalConditionsView extends StatefulWidget {
  const MedicalConditionsView({super.key});

  @override
  State<MedicalConditionsView> createState() => _MedicalConditionsViewState();
}

class _MedicalConditionsViewState extends State<MedicalConditionsView> {
  bool _hasConditions = false;
  final List<MedicalItem> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final res = await AuthHttpClient.get('/api/profile/medical');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final has = (data['hasMedicalConditions'] as bool?) ?? false;
      final list = (data['medicalConditions'] as List?) ?? const [];

      setState(() {
        _hasConditions = has;
        _items
          ..clear()
          ..addAll(list.whereType<Map<String, dynamic>>().map(MedicalItem.fromJson));
      });
    } catch (e) {
      _snack(_prettyErr(e), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_hasConditions && _items.isEmpty) {
      _snack('Please add at least one condition/allergy.', err: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthHttpClient.put(
        '/api/profile/medical',
        body: {
          'hasMedicalConditions': _hasConditions,
          'medicalConditions': _hasConditions
              ? _items.map((e) => e.toJson()).toList()
              : <Map<String, dynamic>>[],
        },
      );

      _snack('Medical details updated.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(_prettyErr(e), err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openAddSheet({MedicalItem? existing, int? index}) {
    showAddConditionSheet(
      context,
      initialName: existing?.name ?? '',
      initialNotes: existing?.notes ?? '',
      initialIsAllergy: existing?.isAllergy ?? false,
      onSave: (name, notes, isAllergy) {
        setState(() {
          final item = MedicalItem(name: name, notes: notes, isAllergy: isAllergy);
          if (index != null && index >= 0 && index < _items.length) {
            _items[index] = item;
          } else {
            _items.add(item);
          }
        });
      },
    );
  }

  void _deleteAt(int i) => setState(() => _items.removeAt(i));

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: err ? Colors.redAccent : Colors.green),
    );
    ;
  }

  String _prettyErr(Object e) {
    final s = e.toString();
    final m = RegExp(r'^Exception:\s*HTTP\s+(\d{3}):\s*(.*)$').firstMatch(s) ??
        RegExp(r'^HTTP\s+(\d{3}):\s*(.*)$').firstMatch(s);
    if (m != null) {
      final code = m.group(1) ?? '';
      final body = m.group(2) ?? '';
      try {
        final j = jsonDecode(body);
        if (j is Map && j['message'] != null) {
          return 'Error $code: ${j['message']}';
        }
      } catch (_) {}
      return 'Error $code: $body';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Medical Conditions',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Explanation banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Text(
                        'Add any relevant medical conditions or allergies. '
                        'This is shared with event staff so they can respond appropriately if needed. '
                        'Remember to tap SAVE before leaving this page to keep your changes.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                    ),
                  ),

                  // Toggle
                  SwitchListTile.adaptive(
                    value: _hasConditions,
                    onChanged: (v) => setState(() => _hasConditions = v),
                    title: const Text(
                      'I have medical conditions/allergies',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'If enabled, add each condition or allergy below.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    activeColor: const Color(0xFF4C85D0),
                  ),

                  // List / Empty
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: !_hasConditions
                          ? const _EmptyHint()
                          : _items.isEmpty
                              ? const _EmptyListCard()
                              : ListView.separated(
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final it = _items[i];
                                    return Dismissible(
                                      key: ValueKey('${it.name}-$i'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.delete, color: Colors.redAccent),
                                      ),
                                      onDismissed: (_) => _deleteAt(i),
                                      child: _ConditionCard(
                                        item: it,
                                        onEdit: () => _openAddSheet(existing: it, index: i),
                                        onDelete: () => _deleteAt(i),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),

                  // Add button
                  if (_hasConditions)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPad),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _openAddSheet,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('ADD CONDITION/ALLERGY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4C85D0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        'If you later develop any conditions or allergies, you can come back and update this at any time.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const SizedBox(
        height: 120,
        child: Center(
          child: Text('No conditions added yet', style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final MedicalItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConditionCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final chip = item.isAllergy
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent),
            ),
            child: const Text(
              'ALLERGY',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF4C85D0)),
            ),
            child: const Text(
              'CONDITION',
              style: TextStyle(
                color: Color(0xFF4C85D0),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          );

    return Card(
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            chip,
          ],
        ),
        subtitle: item.notes.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(item.notes, style: const TextStyle(color: Colors.white70)),
              ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF1C1C1C),
          iconColor: Colors.white70,
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.white))),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

/// Bottom Sheet with SafeArea + keyboard lift + "isAllergy" toggle
Future<void> showAddConditionSheet(
  BuildContext context, {
  String initialName = '',
  String initialNotes = '',
  bool initialIsAllergy = false,
  required void Function(String name, String notes, bool isAllergy) onSave,
}) async {
  final nameCtrl = TextEditingController(text: initialName);
  final notesCtrl = TextEditingController(text: initialNotes);
  bool isAllergy = initialIsAllergy;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        top: false, // protect bottom area
        child: LayoutBuilder(
          builder: (_, __) {
            final kb = MediaQuery.of(ctx).viewInsets.bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: kb),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      initialName.isEmpty ? 'Add Condition/Allergy' : 'Edit Condition/Allergy',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _sheetInput('Condition/Allergy name'),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: _sheetInput('Notes (optional)'),
                      style: const TextStyle(color: Colors.black),
                    ),

                    const SizedBox(height: 4),
                    StatefulBuilder(
                      builder: (context, setSB) => SwitchListTile.adaptive(
                        value: isAllergy,
                        onChanged: (v) => setSB(() => isAllergy = v),
                        title: const Text('This is an allergy', style: TextStyle(color: Colors.white)),
                        subtitle: const Text(
                          'Enable if this item is an allergy (e.g., peanuts, bee stings).',
                          style: TextStyle(color: Colors.white70),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.blueAccent,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              onSave(name, notesCtrl.text.trim(), isAllergy);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4C85D0),
                            ),
                            child: const Text('SAVE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

InputDecoration _sheetInput(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
