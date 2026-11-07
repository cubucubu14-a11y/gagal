import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'kasir_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _branchController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settingsBox');
    _branchController.text = box.get('branchName') ?? '';
    _urlController.text = box.get('scriptUrl') ?? '';
  }

  void _saveSetup() {
    final branch = _branchController.text.trim();
    final url = _urlController.text.trim();

    if (branch.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Tab Sheet dan URL Apps Script wajib diisi!')),
      );
      return;
    }

    final box = Hive.box('settingsBox');
    box.put('branchName', branch);
    box.put('scriptUrl', url);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const KasirScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Awal Kasir'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan Nama Tab Sheet (Cabang) dan URL Apps Script lama Anda.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _branchController,
              decoration: const InputDecoration(labelText: 'Nama Tab Sheet (Contoh: CIRENG WOII)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL Google Apps Script', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: _saveSetup,
                child: const Text('Simpan & Mulai Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
