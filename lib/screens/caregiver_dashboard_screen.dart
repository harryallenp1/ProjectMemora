import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../models/user.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  @override
  _CaregiverDashboardScreenState createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  final db = DatabaseService();
  List<User> _users = [];
  List<Item> _items = [];
  User? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    final users = await db.getAllUsers();
    setState(() => _users = users);
  }

  Future<void> _loadItemsForUser(User user) async {
    final items = await db.getItemsByUserId(user.id!);
    setState(() {
      _selectedUser = user;
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Caregiver Dashboard"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          DropdownButton<User>(
            dropdownColor: Colors.deepPurple,
            hint: const Text("Select Patient", style: TextStyle(color: Colors.white)),
            value: _selectedUser,
            items: _users.map((user) {
              return DropdownMenuItem<User>(
                value: user,
                child: Text(user.username, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (user) {
              if (user != null) _loadItemsForUser(user);
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text("No items found", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(item.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("At: ${item.location}", style: const TextStyle(color: Colors.white54)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
