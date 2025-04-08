import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';
import 'caregiver_login_screen.dart'; // ⬅️ Make sure you create this screen later

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final db = DatabaseService();

  Future<void> _handleLoginOrRegister() async {
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    User? user = await db.loginUser(username, password);

    if (user != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
    } else {
      await db.registerUser(User(username: username, password: password));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User Registered! Try login again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Text("👤", style: TextStyle(fontSize: 22)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CaregiverLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/brain_network.jpg", height: 100),
            const SizedBox(height: 20),
            const Text("Welcome Back!", style: TextStyle(color: Colors.white, fontSize: 22)),
            TextField(
              controller: usernameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Username", labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleLoginOrRegister,
              child: const Text("Login / Register"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
          ],
        ),
      ),
    );
  }
}
