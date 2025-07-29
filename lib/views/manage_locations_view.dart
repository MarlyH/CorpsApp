// lib/views/manage_locations_view.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_http_client.dart';

class ManageLocationsView extends StatefulWidget {
  const ManageLocationsView({Key? key}) : super(key: key);

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
          TextFormField(
            controller: _idController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'ID (tap list or type)',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
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
              if (_pickedImage != null) const Icon(Icons.check, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 24),
          if (!isEditing) ...[
            ElevatedButton(
              onPressed: _isLoading ? null : _createLocation,
              child: const Text('CREATE'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _isLoading ? null : _updateLocation,
              child: const Text('UPDATE'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _deleteLocation,
              child: const Text('DELETE'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _clearForm,
              child: const Text('CLEAR'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Colors.white54),
              ),
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      itemCount: _locations.length,
      itemBuilder: (ctx, i) {
        final loc = _locations[i];
        final isSelected = loc['locationId'].toString() == _idController.text;
        return Card(
          color: isSelected ? Colors.blueGrey : Colors.white10,
          child: ListTile(
            leading: loc['mascotImgSrc'] != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(loc['mascotImgSrc'] as String),
                  )
                : const Icon(Icons.location_on, color: Colors.white70),
            title: Text(loc['name'] as String, style: const TextStyle(color: Colors.white)),
            subtitle: Text('ID: ${loc['locationId']}', style: const TextStyle(color: Colors.white70)),
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
        title: const Text('Manage Locations'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadAllLocations),
          IconButton(icon: const Icon(Icons.search), onPressed: _isLoading ? null : () => _loadLocationById(_idController.text)),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_currentImageUrl!, height: 120, fit: BoxFit.cover),
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
