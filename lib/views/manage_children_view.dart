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
      setState(() => error = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Managing Children", style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a Child:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('• Tap the + button\n• Fill in the details\n• Save to add', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('Edit/Delete a Child:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('• Tap on the child\n• Modify details or delete\n• Save changes', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _goCreate() async {
    await Navigator.pushNamed(context, '/children/create');
    fetchChildren();
  }

  Future<void> _goEdit(ChildModel child) async {
    await Navigator.pushNamed(context, '/children/edit', arguments: child);
    fetchChildren();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'MY CHILDREN',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _showHelp),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else if (error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text("Error: $error", style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: children.isEmpty
                            ? Column(
                                children: [
                                  Card(
                                    color: Colors.white10,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      title: const Text('Add Child', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                      trailing: const Icon(Icons.add, color: Colors.white70),
                                      onTap: _goCreate,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person_outline, color: Colors.white70, size: 48),
                                          SizedBox(height: 16),
                                          Text("No children added yet", style: TextStyle(color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: children.length + 1,
                                itemBuilder: (_, index) {
                                  if (index == children.length) {
                                    return Card(
                                      margin: const EdgeInsets.only(top: 16),
                                      color: Colors.white10,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        title: const Text('Add Child', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                        trailing: const Icon(Icons.add, color: Colors.white70),
                                        onTap: _goCreate,
                                      ),
                                    );
                                  }
                                  final child = children[index];
                                  return InkWell(
                                    onTap: () => _goEdit(child),
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: Colors.white10,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        title: Text(
                                          "${child.firstName} ${child.lastName}",
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                        ),
                                        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
