import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManageCaregiversScreen extends ConsumerStatefulWidget {
  const ManageCaregiversScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageCaregiversScreen> createState() =>
      _ManageCaregiversScreenState();
}

class _ManageCaregiversScreenState extends ConsumerState<ManageCaregiversScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final List<Map<String, String>> _caregivers = [];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _addCaregiver() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) return;

    setState(() {
      _caregivers.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });
      _nameController.clear();
      _emailController.clear();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caregiver added successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeCaregiver(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Caregiver'),
        content: const Text('Are you sure you want to remove this caregiver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _caregivers.removeWhere((c) => c['id'] == id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Caregiver removed'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child:
                const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCaregiverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Caregiver',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Caregiver Name',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Caregiver Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _addCaregiver,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add Caregiver',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Caregivers'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCaregiverSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Caregiver'),
      ),
      body: _caregivers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No caregivers added',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'Add trusted people to be notified\nwhen you trigger an SOS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              itemCount: _caregivers.length,
              itemBuilder: (ctx, i) {
                final cg = _caregivers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        cg['name']![0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                    title: Text(cg['name']!,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(cg['email']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => _removeCaregiver(cg['id']!),
                      tooltip: 'Remove caregiver',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
