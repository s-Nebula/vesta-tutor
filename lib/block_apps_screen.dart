import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockAppsScreen extends StatefulWidget {
  final String childId;

  const BlockAppsScreen({super.key, required this.childId});

  @override
  State<BlockAppsScreen> createState() => _BlockAppsScreenState();
}

class _BlockAppsScreenState extends State<BlockAppsScreen> {
  final TextEditingController _packageController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  
  Future<void> _blockApp(String packageName) async {
    if (packageName.isEmpty) return;

    await _db.collection('configuraciones').doc(widget.childId).set({
      'apps_bloqueadas': FieldValue.arrayUnion([packageName])
    }, SetOptions(merge: true));

    _packageController.clear();
  }

  
  Future<void> _unblockApp(String packageName) async {
    await _db.collection('configuraciones').doc(widget.childId).update({
      'apps_bloqueadas': FieldValue.arrayRemove([packageName])
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloquear Aplicaciones'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            
            TextField(
              controller: _packageController,
              decoration: InputDecoration(
                labelText: 'Nombre de paquete (ej. com.instagram.android)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _blockApp(_packageController.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aplicaciones actualmente bloqueadas:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('configuraciones').doc(widget.childId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('No hay configuraciones'));
                  }

                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  List<dynamic> blockedApps = data['apps_bloqueadas'] ?? [];

                  if (blockedApps.isEmpty) {
                    return const Center(child: Text('No hay apps bloqueadas.'));
                  }

                  return ListView.builder(
                    itemCount: blockedApps.length,
                    itemBuilder: (context, index) {
                      String appPackage = blockedApps[index];
                      return Card(
                        child: ListTile(
                          title: Text(appPackage),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _unblockApp(appPackage),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}