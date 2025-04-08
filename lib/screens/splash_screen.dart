import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
   const SplashScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/brain_network.jpg", height: 200),
              const SizedBox(height: 20),
              const Text("Memora",
                  style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
              const Text("RECALL. ORGANIZE. THRIVE",
                  style: TextStyle(letterSpacing: 2, color: Colors.white54)),
              const SizedBox(height: 100),
              const Text("Touch to Continue", style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}
