// lib/views/medical_conditions_view.dart
import 'dart:convert';
import 'package:corpsapp/models/medical_item.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/medical_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class MedicalConditionsView extends StatefulWidget {
  const MedicalConditionsView({super.key});

  @override
  State<MedicalConditionsView> createState() => _MedicalConditionsViewState();
}

class _MedicalConditionsViewState extends State<MedicalConditionsView> {
  bool _hasConditions = true;
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

      //final has = (data['hasMedicalConditions'] as bool?) ?? true;
      final list = (data['medicalConditions'] as List?) ?? const [];

      setState(() {
        _hasConditions = true;
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
    if (_saving) return;
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
    } catch (e) {
      _snack(_prettyErr(e), err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAddSheet({MedicalItem? existing, int? index}) async {
    final result = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: MedicalEditor(initial: existing),  
      ),
    );

    if (result == null) return;

    setState(() {
      if (index != null && index >= 0 && index < _items.length) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });

    await _save();
  }


  Future<void> _confirmDelete(int index) async {
    final item = _items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomAlertDialog(
        title: 'Remove Condition/Allergy', 
        info: 'Are you sure you wish to remove condition or allergy: ${item.name}',
        cancel: true,
        buttonAction: () => Navigator.pop(ctx, true),
        buttonLabel: 'Delete',
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _items.removeAt(index));
    }

    await _save();
  }
  
  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: err ? AppColors.errorColor : Colors.green),
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Medical'),
      body: Padding(
        padding: AppPadding.screen,
        child: SafeArea(
          bottom: true,
          child: _loading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Explanation banner
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'This information is shared with staff members so they can respond effectively if needed.',
                      style: TextStyle(color: Colors.white70),
                    ),                  
                  ),

                  const SizedBox(height: 16),

                  Button(label: 'Add Condition / Allergy', onPressed: _openAddSheet),

                  const SizedBox(height: 16),
                  
                  _items.isEmpty 
                    ? const Center(child: Text('No conditions or allergies added yet.'))
                    : Expanded(
                        child: ListView(
                            children: [
                              for (final group in [
                                {'title': 'Allergies', 'filter': true},
                                {'title': 'Medical Conditions', 'filter': false},
                              ])
                                if (_items.any((it) => it.isAllergy == group['filter'])) ...[
                                  CupertinoListSection.insetGrouped(
                                    margin: EdgeInsets.all(0),
                                    backgroundColor: AppColors.background,
                                    hasLeading: false,                 
                                    header: Text(group['title'] as String),
                                    children: _items
                                        .where((it) => it.isAllergy == group['filter'])
                                        .map((it) {
                                          final index = _items.indexOf(it);
                                          return Dismissible(
                                            key: ValueKey('${group['title']}-$index-${it.name}'),
                                            direction: DismissDirection.endToStart,
                                            onDismissed: (_) => _confirmDelete(index),
                                            child: _ConditionCard(
                                              item: it,
                                              onEdit: () => _openAddSheet(
                                                existing: it,
                                                index: index,
                                              ),                                            
                                              onDelete: () => _confirmDelete(index),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                  const SizedBox(height: 16), 
                                ],
                            ],
                      ),
                    )
                ],
              ),
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
    return ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        subtitle: item.notes.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.notes, style: const TextStyle(color: Colors.white)),
              ),
        trailing: PopupMenuButton<String>(
          color: AppColors.background,
          iconColor: Colors.white,
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
    );
  }
}
