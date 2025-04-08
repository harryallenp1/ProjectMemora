import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item.dart';
import '../models/user.dart'; // 🔗 Needed for user linkage
import '../services/database_service.dart';

class AddItemScreen extends StatefulWidget {
  final User user; // 👤 Logged-in user passed from DashboardScreen

  const AddItemScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  final db = DatabaseService();

  File? _imageFile;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _saveItem() async {
    final newItem = Item(
      userId: widget.user.id!, // ✅ Link item to logged-in user
      name: _nameController.text,
      description: _descController.text,
      location: _locController.text,
      dateAdded: DateTime.now().toString(),
      imagePath: _imageFile?.path,
    );

    await db.insertItem(newItem);
    Navigator.pop(context); // 🔙 Back to dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Add Item"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📝 Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Item Name",
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),

            // 📝 Description
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Description",
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),

            // 📍 Location
            TextField(
              controller: _locController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Location",
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 20),

            // 🖼️ Image preview
            _imageFile == null
                ? const Text("No image selected", style: TextStyle(color: Colors.white38))
                : Image.file(_imageFile!, height: 150),

            const SizedBox(height: 10),

            // 📤 Image picker
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Pick Image"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),

            const SizedBox(height: 30),

            // ✅ Save button
            ElevatedButton(
              onPressed: _saveItem,
              child: const Text("Save Item"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
          ],
        ),
      ),
    );
  }
}
