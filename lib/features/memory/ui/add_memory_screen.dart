import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/memory.dart';
import '../memory_module.dart';
import 'memory_view_model.dart';

/// UI layer – Caregiver Screens subsystem.
///
/// The caregiver adds a personal memory (photo, person, story) for a patient.
class AddMemoryScreen extends StatefulWidget {
  final String patientId;
  final String caregiverName;
  final MemoryViewModel? viewModel;

  const AddMemoryScreen({
    super.key,
    required this.patientId,
    required this.caregiverName,
    this.viewModel,
  });

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  late final MemoryViewModel viewModel;
  final _title = TextEditingController();
  final _personName = TextEditingController();
  final _relationship = TextEditingController();
  final _story = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel ?? MemoryModule.createViewModel();
  }

  @override
  void dispose() {
    _title.dispose();
    _personName.dispose();
    _relationship.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _photoPath = image.path);
  }

  Future<void> submit(
    String title,
    String personName,
    String relationship,
    String story,
  ) async {
    setState(() => _saving = true);
    final saved = await viewModel.addMemory(Memory(
      patientId: widget.patientId,
      title: title.trim(),
      personName: personName.trim(),
      relationship: relationship.trim(),
      story: story.trim(),
      photoUrl: _photoPath,
      createdBy: widget.caregiverName,
      dateAdded: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory saved')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage ?? 'Could not save')),
      );
    }
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white38),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepPurpleAccent),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoPath;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Add a Memory'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: pickPhoto,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: photo == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('Tap to add a photo',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : Image.file(File(photo), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          _field(_personName, 'Person in the memory (e.g. Anna)'),
          _field(_relationship, 'Relationship (e.g. daughter)'),
          _field(_title, 'Title (e.g. Anna\'s wedding)'),
          _field(_story, 'Story to read aloud', lines: 4),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _saving
                ? null
                : () => submit(
                    _title.text, _personName.text, _relationship.text,
                    _story.text),
            child: Text(_saving ? 'Saving...' : 'Save Memory',
                style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
