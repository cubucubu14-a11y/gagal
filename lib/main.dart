import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'views/setup_screen.dart';
import 'views/kasir_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Buka box Hive untuk penyimpanan lokal offline-first
  await Hive.openBox('settingsBox');
  await Hive.openBox('transactionsBox');
  await Hive.openBox('deleteQueueBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settingsBox');
    final String? branchName = settingsBox.get('branchName');
    final String? scriptUrl = settingsBox.get('scriptUrl');

    // Cek apakah setup awal tab cabang & url sudah diisi
    final bool isSetupComplete = branchName != null && branchName.isNotEmpty && scriptUrl != null && scriptUrl.isNotEmpty;

    return MaterialApp(
      title: 'Kasir Woii',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: isSetupComplete ? const KasirScreen() : const SetupScreen(),
    );
  }
}
