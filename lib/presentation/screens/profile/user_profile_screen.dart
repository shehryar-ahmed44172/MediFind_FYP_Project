import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Picture
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Full Name'),
                    subtitle: Text('John Doe'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Email'),
                    subtitle: Text('john@example.com'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Phone Number'),
                    subtitle: Text('+1-555-0123'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Role'),
                    subtitle: Text('Patient'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Additional Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    title: Text('City'),
                    subtitle: Text('New York'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('State'),
                    subtitle: Text('NY'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Country'),
                    subtitle: Text('United States'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Edit Button
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }
}
