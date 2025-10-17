import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/cupertino.dart';
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
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'My Children'),     
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: AppPadding.screen,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.errorColor, size: 48),
                        const SizedBox(height: 16),
                        Text("Error: $error", style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                      ],
                    ),                  
                  ),
                )
              else
                if (children.isEmpty) ... [
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_outline, color: Colors.white70, size: 48),
                        SizedBox(height: 4),
                        Text("No children added yet", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ] else ... [
                  CupertinoListSection.insetGrouped(
                    backgroundColor: AppColors.background,
                    margin: EdgeInsets.all(0),
                    hasLeading: false,    
                    separatorColor: Colors.white30,               
                    children: [
                      ...children.map((child) {
                        return CupertinoListTile(
                          backgroundColor: Colors.white10,
                          title: Text(
                            "${child.firstName} ${child.lastName}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(
                            CupertinoIcons.chevron_forward,
                            color: Colors.white70,
                          ),
                          onTap: () => _goEdit(child),
                        );
                      }),
                    ],
                  )
                ],

              const SizedBox(height: 16),
                
              Button(label: 'Add Child', onPressed: _goCreate),                    
            ],
          ),
        ),      
      ),
    );
  }
}
