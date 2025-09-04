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

  Future<void> _loadLocationById(int id) async {
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.getLocation(id);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        _editingLocation = data;
        _locations = [];
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
    if (!_formKey.currentState!.validate() || _editingLocation == null) {
      _showSnack('Location name is required', isError: true);
      return;
    }
    final locationId = _editingLocation!['locationId'] as int;
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.updateLocation(
        id: locationId,
        name: _nameController.text.trim(),
        imageFile: _pickedImage,
      );
      if (resp.statusCode == 200) {
        _showSnack('Location updated successfully');
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
    if (_editingLocation == null) {
      _showSnack('No location selected', isError: true);
      return;
    }
    final locationId = _editingLocation!['locationId'] as int;
    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.deleteLocation(locationId);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _showSnack('Location deleted successfully');
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
          // Show ID only when editing an existing location
          if (isEditing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Location ID: ${_editingLocation!['locationId']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            validator:
                (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              if (_pickedImage != null)
                const Icon(Icons.check, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 24),

          // ─── CREATE / UPDATE / DELETE / CLEAR ─────
          if (!isEditing) ...[
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, child) {
                final hasContent = value.text.trim().isNotEmpty;
                return ElevatedButton(
                  onPressed: _isLoading || !hasContent ? null : _createLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: const Text('CREATE'),
                );
              },
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
              onPressed:
                  _isLoading
                      ? null
                      : () async {
                        final confirmed =
                            await showDialog<bool>(
                              context: context,
                              builder:
                                  (_) => const _DeleteLocationConfirmDialog(),
                            ) ??
                            false;
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: _locations.length,
      itemBuilder: (ctx, i) {
        final loc = _locations[i];
        final isSelected =
            _editingLocation != null &&
            _editingLocation!['locationId'] == loc['locationId'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white10,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading:
                loc['mascotImgSrc'] != null
                    ? CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        loc['mascotImgSrc'] as String,
                      ),
                    )
                    : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                      ),
                    ),
            title: Text(
              loc['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'ID: ${loc['locationId']}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.edit, color: Colors.white70),
            onTap: () => _loadLocationById(loc['locationId'] as int),
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
        title: const Text(
          'Location Management',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        leading:
            _editingLocation != null
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _clearForm();
                    _loadAllLocations();
                  },
                )
                : null,
        actions: [
          if (_editingLocation == null)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'How to Use',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Creating a Location:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '1. Click the + button to start\n'
                                '2. Enter the location name\n'
                                '3. Optionally add an image\n'
                                '4. Click CREATE',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Editing a Location:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '1. Click on any location in the list\n'
                                '2. Modify the name or image\n'
                                '3. Click UPDATE to save changes',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Deleting a Location:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '1. Select a location to edit\n'
                                '2. Click DELETE\n'
                                '3. Type "delete" to confirm',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'GOT IT',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllLocations,
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
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
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
      title: const Text(
        "Delete Location",
        style: TextStyle(color: Colors.white),
      ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
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
              color:
                  isValid
                      ? Colors.redAccent
                      : Colors.redAccent.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }
}
