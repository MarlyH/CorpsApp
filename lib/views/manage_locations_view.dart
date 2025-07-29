import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_http_client.dart';
class ManageLocationsView extends StatefulWidget {
  const ManageLocationsView({super.key});

  @override
  State<ManageLocationsView> createState() => _ManageLocationsViewState();
}

class _ManageLocationsViewState extends State<ManageLocationsView> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();

  File? _pickedImage;
  bool _isLoading = false;
  String? _currentImageUrl;
  Map<String, dynamic>? _editingLocation;
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadAllLocations();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllLocations() async {
    setState(() {
      _isLoading = true;
      _editingLocation = null;
      _currentImageUrl = null;
    });
    try {
      final resp = await AuthHttpClient.getLocations();
      final data = jsonDecode(resp.body) as List<dynamic>;
      setState(() => _locations = data.cast<Map<String, dynamic>>());
    } catch (e) {
      _showSnack('Error loading locations: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocationById(String idText) async {
    final id = int.tryParse(idText);
    if (id == null) {
      _showSnack('Please enter a valid ID', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.getLocation(id);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        _editingLocation = data;
        _locations = [];
        _idController.text = data['locationId'].toString();
        _nameController.text = data['name'] as String? ?? '';
        _currentImageUrl = data['mascotImgSrc'] as String?;
      });
    } catch (e) {
      _showSnack('Error loading location: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLocation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.createLocation(
        name: _nameController.text.trim(),
        imageFile: _pickedImage,
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _showSnack('Location created');
        _clearForm();
        await _loadAllLocations();
      } else {
        _showSnack('Failed to create (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocation() async {
    final id = int.tryParse(_idController.text);
    if (id == null || !_formKey.currentState!.validate()) {
      _showSnack('Valid ID & name required', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.updateLocation(
        id: id,
        name: _nameController.text.trim(),
        imageFile: _pickedImage,
      );
      if (resp.statusCode == 200) {
        _showSnack('Location updated');
        await _loadAllLocations();
      } else {
        _showSnack('Failed to update (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLocation() async {
    final id = int.tryParse(_idController.text);
    if (id == null) {
      _showSnack('Enter valid ID', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.deleteLocation(id);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _showSnack('Location deleted');
        _clearForm();
        await _loadAllLocations();
      } else {
        _showSnack('Failed to delete (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _clearForm() {
    _idController.clear();
    _nameController.clear();
    setState(() {
      _pickedImage = null;
      _editingLocation = null;
      _currentImageUrl = null;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: isError ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildForm() {
    final isEditing = _editingLocation != null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── ID Field ──────────────────────────────
          const Text(
            'ID (tap list or type)',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _idController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'e.g. 42',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Name Field ────────────────────────────
          const Text(
            'Name',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Location name',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // ─── Image Picker ──────────────────────────
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image, color: Colors.black),
                label: Text(
                  _pickedImage != null ? 'Change Image' : 'Pick Image',
                  style: const TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              if (_pickedImage != null)
                const Icon(Icons.check, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 24),

          // ─── CREATE / UPDATE / DELETE / CLEAR ─────
          if (!isEditing) ...[
            ElevatedButton(
              onPressed: _isLoading ? null : _createLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('CREATE'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _isLoading ? null : _updateLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('UPDATE'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => const _DeleteLocationConfirmDialog(),
                      ) ?? false;
                      if (confirmed) _deleteLocation();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('DELETE'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _clearForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('CLEAR'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      itemCount: _locations.length,
      itemBuilder: (ctx, i) {
        final loc = _locations[i];
        final isSelected = loc['locationId'].toString() == _idController.text;
        return Card(
          color: isSelected ? Colors.blueGrey : Colors.white10,
          child: ListTile(
            leading: loc['mascotImgSrc'] != null
                ? CircleAvatar(
                    backgroundImage:
                        NetworkImage(loc['mascotImgSrc'] as String),
                  )
                : const Icon(Icons.location_on, color: Colors.white70),
            title: Text(loc['name'] as String,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text('ID: ${loc['locationId']}',
                style: const TextStyle(color: Colors.white70)),
            onTap: () {
              _idController.text = loc['locationId'].toString();
              _loadLocationById(_idController.text);
            },
          ),
        );
      },
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Location Management',
          style: const TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,            // tweak as needed
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllLocations,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isLoading
                ? null
                : () => _loadLocationById(_idController.text),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _currentImageUrl!,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildForm(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              if (_editingLocation == null) _buildList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A delete‐confirmation dialog that only enables DELETE once you type “DELETE”.
class _DeleteLocationConfirmDialog extends StatefulWidget {
  const _DeleteLocationConfirmDialog({super.key});

  @override
  State<_DeleteLocationConfirmDialog> createState() =>
      _DeleteLocationConfirmDialogState();
}

class _DeleteLocationConfirmDialogState
    extends State<_DeleteLocationConfirmDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _ctrl.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Delete Location", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type “delete” to confirm permanent deletion of this location.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'delete',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("CANCEL", style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.pop(context, true) : null,
          child: Text(
            "DELETE",
            style: TextStyle(
              color: isValid
                  ? Colors.redAccent
                  : Colors.redAccent.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }
}
