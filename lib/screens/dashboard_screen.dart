import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import 'add_item_screen.dart';
import '../widgets/voice_command_widget.dart'; // 🎙 Voice feature

class DashboardScreen extends StatefulWidget {
  final User user; // 👤 Logged-in user
  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Item> _items = [];
  final db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadItems(); // 🔁 Load only items linked to this user
  }

  Future<void> _loadItems() async {
    final items = await db.getItemsByUserId(widget.user.id!); // 🎯 Scoped items
    setState(() => _items = items);
  }

  void _deleteItem(int id) async {
    await db.deleteItem(id);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Welcome, ${widget.user.username}'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(user: widget.user), // ✅ Pass user
                ),
              );
              _loadItems(); // 🔃 Refresh after adding
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.memory, size: 100, color: Colors.white54),
                  const SizedBox(height: 20),
                  const Text(
                    "Let's start tracking your memories!",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  VoiceCommandWidget(), // 🎤 Real voice command interface
                ],
              ),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final item = _items[index];
                return ListTile(
                  leading: item.imagePath != null
                      ? Image.file(
                          File(item.imagePath!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.photo, color: Colors.white38),
                  title: Text(
                    item.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "At: ${item.location}",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteItem(item.id!),
                  ),
                );
              },
            ),
    );
  }
}
