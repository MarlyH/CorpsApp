import 'dart:convert';
import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_http_client.dart';

class ManageLocationsView extends StatefulWidget {
  const ManageLocationsView({super.key});

  @override
  State<ManageLocationsView> createState() => _ManageLocationsViewState();
}

class _ManageLocationsViewState extends State<ManageLocationsView> {
  final _nameController = TextEditingController();

  bool _isLoading = false;
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


    Future<void> _createLocation(String name, [File? image]) async {
      setState(() => _isLoading = true);
      try {
        final resp = await AuthHttpClient.createLocation(
          name: name.trim(),
          imageFile: image,
        );
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          _showSnack('Location created');
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.normalText)),
        backgroundColor: isError ? AppColors.errorColor : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildList() {
  return _isLoading
    ? Center(child: CircularProgressIndicator(color: Colors.white))
    : CupertinoListSection.insetGrouped(
      margin: EdgeInsets.all(0),
      backgroundColor: Colors.transparent,
      children: _locations.map((loc) {
        return CupertinoListTile(
          leadingSize: 46,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          leading: loc['mascotImgSrc'] != null
              ? CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(
                    loc['mascotImgSrc'] as String,
                  ),
                  backgroundColor: Colors.transparent,              
                )
              : CircleAvatar(
                  radius: 24,   
                  backgroundColor: Colors.transparent,            
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                  ),
                ),
          title: Text(
            loc['name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),       
          trailing: const Icon(Icons.navigate_next, color: Colors.white70),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: AppColors.background,
              builder: (_) => EditLocationModal(
                location: loc,
                onUpdate: (id, name, image) async {
                  await AuthHttpClient.updateLocation(id: id, name: name, imageFile: image);
                  await _loadAllLocations();
                  _showSnack('Location updated');
                },
                onDelete: (id) async {
                  await AuthHttpClient.deleteLocation(id);
                  await _loadAllLocations();
                  _showSnack('Location deleted');
                },
              ),
            );
          },
        );
    }).toList(),
  ); 
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfileAppBar(
        title: 'Location Management', 
        actionButton: Icon(Icons.refresh), 
        actionOnTap: _isLoading ? null : _loadAllLocations,
        specialBackAction: _editingLocation != null ? () { _loadAllLocations(); } : null,
      ),     
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Button(
                label: 'New Location', 
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: AppColors.background,
                  builder: (_) => CreateLocationModal(onCreate: _createLocation),
                )
              ),

              const SizedBox(height: 16),
              
              _buildList(),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateLocationModal extends StatefulWidget {
  final Future<void> Function(String name, File? image) onCreate;

  const CreateLocationModal({super.key, required this.onCreate});

  @override
  State<CreateLocationModal> createState() => _CreateLocationModalState();
}

class _CreateLocationModalState extends State<CreateLocationModal> {
  final TextEditingController nameController = TextEditingController();
  bool _isLoading = false;
  File? _pickedImage;


  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    await widget.onCreate(name, _pickedImage);
    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }


  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: AppPadding.screen.copyWith(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              const Text(
                'Create New Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'WinnerSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              if (_pickedImage != null) ... [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _pickedImage!,
                      width: 188,
                      height: 188,
                      fit: BoxFit.cover,
                    )                     
                  ),
                ),
              ],
                
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(             
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, color: AppColors.normalText),
                    label: Text(
                      _pickedImage != null ? 'Change Image' : 'Pick Image',
                      style: const TextStyle(color: AppColors.normalText),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              InputField(
                hintText: 'Enter the location name',
                label: 'Location Name',
                controller: nameController,
              ),

              const SizedBox(height: 24),

              Button(
                label: 'Create',
                onPressed: _isLoading ? null : _handleCreate,
                loading: _isLoading,
              ), 

              const SizedBox(height: 16),         
            ],
          ),
        ),       
      ),
    );
  }
}

class EditLocationModal extends StatefulWidget {
  final Map<String, dynamic> location;
  final Future<void> Function(int id, String name, File? image) onUpdate;
  final Future<void> Function(int id) onDelete;

  const EditLocationModal({
    super.key,
    required this.location,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<EditLocationModal> createState() => _EditLocationModalState();
}

class _EditLocationModalState extends State<EditLocationModal> {
  late TextEditingController nameController;
  File? _pickedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.location['name'] ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _handleUpdate() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    await widget.onUpdate(widget.location['locationId'], name, _pickedImage);
    if (mounted) Navigator.pop(context);
    setState(() => _isLoading = false);
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteLocationConfirmDialog(),
    ) ?? false;
    if (!confirmed) return;

    setState(() => _isLoading = true);
    await widget.onDelete(widget.location['locationId']);
    if (mounted) Navigator.pop(context);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.location['mascotImgSrc'] as String?;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: AppPadding.screen.copyWith(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Edit Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'WinnerSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // ─── Current Image ────────────────────────────────
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _pickedImage != null
                      ? Image.file(_pickedImage!, width: 188, height: 188, fit: BoxFit.cover)
                      : (imageUrl != null
                          ? Image.network(imageUrl, width: 188, height: 188, fit: BoxFit.cover)
                          : Container(
                              width: 188,
                              height: 188,
                              color: Colors.white12,
                              child: const Icon(Icons.image_not_supported, color: Colors.white54),
                            )),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, color: AppColors.normalText),
                    label: Text(
                      _pickedImage != null ? 'Change Image' : 'Pick Image',
                      style: const TextStyle(color: AppColors.normalText),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              InputField(
                hintText: 'Enter the location name',
                label: 'Location Name',
                controller: nameController,
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Button(
                      label: 'Delete',
                      onPressed: _isLoading ? null : _handleDelete,
                      isCancelOrBack: true,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Button(
                      label: 'Update',
                      onPressed: _isLoading ? null : _handleUpdate,
                      loading: _isLoading,
                    ),
                  ),                             
                ],
              ),            

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A delete‐confirmation dialog that only enables DELETE once you type “DELETE”.
class _DeleteLocationConfirmDialog extends StatefulWidget {
  const _DeleteLocationConfirmDialog({Key? key}) : super(key: key);

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
    return CustomAlertDialog(
      title: 'Delete Location', 
      info: 'Are you sure you want to delete this location?',
      cancel: true,
      buttonLabel: 'Confirm',
      buttonAction: () => Navigator.pop(context, true),
    );
  }
}
