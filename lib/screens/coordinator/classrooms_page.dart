import 'package:flutter/material.dart';

class ClassroomsPage extends StatelessWidget {
  const ClassroomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classrooms'),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        itemCount: 10, // Example classroom count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.class_outlined),
              title: Text('Classroom CS-${100 + index}'),
              subtitle: Text('Block A'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                // Navigate to classroom details page
              },
            ),
          );
        },
      ),
    );
  }
}
