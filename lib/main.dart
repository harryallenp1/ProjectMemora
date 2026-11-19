import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/splash_screen.dart'; // Import your splash screen
import 'features/memory/memory_module.dart'; // UC-03 memories

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 TEMP: Delete memora.db to force re-creation with updated schema
  final dbPath = await getDatabasesPath();
  await deleteDatabase(join(dbPath, 'memora.db'));

  await MemoryModule.init(); // UC-03: wire memory service

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Memora',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // Set SplashScreen as the starting screen
    );
  }
}
