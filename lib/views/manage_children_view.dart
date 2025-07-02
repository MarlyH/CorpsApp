import 'dart:convert';
import 'package:flutter/material.dart';
import '/models/child_model.dart';
import '/services/auth_http_client.dart';

class ManageChildrenView extends StatefulWidget {
  const ManageChildrenView({super.key});

  @override
  State<ManageChildrenView> createState() => _ManageChildrenViewState();
}

class _ManageChildrenViewState extends State<ManageChildrenView> {
  List<ChildModel> children = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Future<void> fetchChildren() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final res = await AuthHttpClient.get('/api/child');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          children = data.map((e) => ChildModel.fromJson(e)).toList();
        });
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to load children.';
        throw Exception('Server responded with ${res.statusCode}: $msg');
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteChild(int childId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Delete Child", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this child?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await AuthHttpClient.delete('/api/child/$childId');

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Child deleted successfully.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.grey),
        );
        fetchChildren();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to delete.';
        throw Exception('Server error: $msg');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
    }
  }

  void navigateToCreate() async {
    await Navigator.pushNamed(context, '/children/create');
    fetchChildren();
  }

  void navigateToEdit(ChildModel child) async {
    await Navigator.pushNamed(context, '/children/edit', arguments: child);
    fetchChildren();
  }

  @override
  Widget build(BuildContext context) {
    // Define a dark, grayscale theme for just this view:
    final grayscaleTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.black,
        textColor: Colors.white,
        iconColor: Colors.white,
        subtitleTextStyle: TextStyle(color: Colors.grey),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.white,
      ),
      dividerColor: Colors.grey,
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.grey[900],
        textStyle: const TextStyle(color: Colors.white),
      ),
    );

    return Theme(
      data: grayscaleTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text("Manage Children")),
        floatingActionButton: FloatingActionButton(
          onPressed: navigateToCreate,
          child: const Icon(Icons.add),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : error != null
                ? Center(child: Text("Error: $error", style: const TextStyle(color: Colors.redAccent)))
                : children.isEmpty
                    ? const Center(child: Text("No children added.", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: fetchChildren,
                        color: Colors.white,
                        backgroundColor: Colors.black,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: children.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, index) {
                            final child = children[index];
                            return ListTile(
                              title: Text("${child.firstName} ${child.lastName}"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("DOB: ${child.dateOfBirth}"),
                                  Text("Group: ${child.ageGroupLabel}"),
                                  Text("Contact: ${child.emergencyContactName} (${child.emergencyContactPhone})"),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') navigateToEdit(child);
                                  if (value == 'delete') deleteChild(child.childId);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
