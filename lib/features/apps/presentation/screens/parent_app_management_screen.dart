import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParentAppManagementScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;

  const ParentAppManagementScreen({
    super.key,
    required this.familyId,
    required this.childId,
  });

  @override
  ConsumerState<ParentAppManagementScreen> createState() => _ParentAppManagementScreenState();
}

class _ParentAppManagementScreenState extends ConsumerState<ParentAppManagementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('App Management'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Simple search bar
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search apps...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),
          
          // App List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: ['YouTube', 'TikTok', 'Instagram', 'Games', 'Chrome']
                  .where((name) => _searchQuery.isEmpty || name.toLowerCase().contains(_searchQuery))
                  .map((appName) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(appName[0]),
                          ),
                          title: Text(appName),
                          subtitle: const Text('Tap to configure rules'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Configure rules for $appName')),
                            );
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}