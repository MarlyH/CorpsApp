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
  final _idCtl   = TextEditingController();
  final _nameCtl = TextEditingController();

  File?   _pickedImage;
  bool    _isLoading      = false;
  String? _currentImageUrl;

  List<Map<String, dynamic>> _locations     = [];
  Map<String, dynamic>?     _singleLocation;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _showSnack(String msg, {bool isError = false}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: isError ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading       = true;
      _singleLocation  = null;
      _currentImageUrl = null;
    });
    try {
      final resp = await AuthHttpClient.getLocations();
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        setState(() => _locations = data.cast());
      } else {
        _showSnack('Failed to load (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchById() async {
    final id = int.tryParse(_idCtl.text);
    if (id == null) {
      _showSnack('Enter valid ID', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.getLocation(id);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _singleLocation  = data;
          _locations       = [];
          _nameCtl.text    = data['name'] as String;
          _currentImageUrl = data['mascotImgSrc'] as String?;
        });
      } else if (resp.statusCode == 404) {
        _showSnack('Not found', isError: true);
      } else {
        _showSnack('Error ${resp.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final resp = await AuthHttpClient.createLocation(
        name: _nameCtl.text.trim(),
        imageFile: _pickedImage,
      );

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        _showSnack('Created');
        _clearForm();
        await _fetchAll();
      } else {
        _showSnack('Failed (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _update() async {
    final id = int.tryParse(_idCtl.text);
    if (id == null || !_formKey.currentState!.validate()) {
      _showSnack('Valid ID & name required', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final resp = await AuthHttpClient.updateLocation(
        id: id,
        name: _nameCtl.text.trim(),
        imageFile: _pickedImage,
      );

      if (resp.statusCode == 200) {
        _showSnack('Updated');
        await _fetchAll();
      } else {
        _showSnack('Failed (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final id = int.tryParse(_idCtl.text);
    if (id == null) {
      _showSnack('Enter valid ID', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final resp = await AuthHttpClient.deleteLocation(id);
      if (resp.statusCode == 204 || resp.statusCode == 200) {
        _showSnack('Deleted');
        _clearForm();
        await _fetchAll();
      } else if (resp.statusCode == 404) {
        _showSnack('Not found', isError: true);
      } else {
        _showSnack('Failed (${resp.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _idCtl.clear();
    _nameCtl.clear();
    setState(() {
      _pickedImage     = null;
      _singleLocation  = null;
      _currentImageUrl = null;
    });
  }

  Widget _buildList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: _locations.length,
      itemBuilder: (_, i) {
        final loc = _locations[i];
        return Card(
          color: loc['locationId'].toString() == _idCtl.text
              ? Colors.blueGrey
              : Colors.white10,
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
              _idCtl.text = loc['locationId'].toString();
              _fetchById();
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAll,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isLoading ? null : _fetchById,
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
                  child: Image.network(_currentImageUrl!,
                      height: 120, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _idCtl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'ID (tap list or type)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        if (_pickedImage != null)
                          const Icon(Icons.check, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_singleLocation == null) ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _create,
                        child: const Text('CREATE'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _update,
                        child: const Text('UPDATE'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _delete,
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
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              if (_singleLocation == null) _buildList(),
            ],
          ),
        ),
      ),
    );
  }
}
