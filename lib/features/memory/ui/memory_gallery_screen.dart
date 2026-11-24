import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/memory.dart';
import '../domain/memory_reaction.dart';
import '../memory_module.dart';
import 'memory_view_model.dart';

/// UI layer – Patient Screens subsystem.
///
/// "My Memories": large, high-contrast memory cards. Tapping a card reads the
/// memory aloud. The mood row lets the patient say how they feel.
class MemoryGalleryScreen extends StatefulWidget {
  final String patientId;
  final MemoryViewModel? viewModel;

  const MemoryGalleryScreen({
    super.key,
    required this.patientId,
    this.viewModel,
  });

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  late final MemoryViewModel viewModel;

  static const _moods = <String, IconData>{
    'Happy': Icons.sentiment_very_satisfied,
    'Calm': Icons.spa,
    'Anxious': Icons.sentiment_neutral,
    'Sad': Icons.sentiment_dissatisfied,
    'Confused': Icons.help_outline,
  };

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel ?? MemoryModule.createViewModel();
    viewModel.addListener(_onViewModelChanged); // Observer
    onOpen(widget.patientId);
  }

  @override
  void dispose() {
    viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> onOpen(String patientId) async {
    await viewModel.loadMemories(patientId);
    // Alternate flow A1: the ML model predicts a difficult hour.
    final offer = await viewModel.checkProactiveComfort(patientId);
    if (!mounted || offer == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Would you like to look at a memory?',
            style: TextStyle(color: Colors.white, fontSize: 24)),
        content: Text(
          offer.memory.personName.isNotEmpty
              ? 'Here is ${offer.memory.personName}.'
              : offer.memory.title,
          style: const TextStyle(color: Colors.white70, fontSize: 20),
        ),
        actions: [
          TextButton(
            child: const Text('Not now', style: TextStyle(fontSize: 18)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text('Yes, show me', style: TextStyle(fontSize: 18)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      viewModel.playStory(offer.memory);
      await _showMemory(offer.memory, heading: 'Here is a happy memory');
      await _askHowYouFeel(offer.memory, moodBefore: 'anxious');
    }
  }

  Future<void> onMemoryTapped(Memory memory) async {
    viewModel.playStory(memory);
    await _showMemory(memory, heading: memory.personName);
  }

  Future<void> onMoodSelected(String mood) async {
    final comfort = await viewModel.recordMood(widget.patientId, mood);
    if (!mounted) return;
    if (comfort != null) {
      await _showMemory(comfort, heading: 'Here is a happy memory');
      await _askHowYouFeel(comfort, moodBefore: mood);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for telling me you feel $mood.')),
      );
    }
  }

  /// Feedback for the recommender: did this memory help?
  Future<void> _askHowYouFeel(Memory memory, {required String moodBefore}) async {
    if (!mounted) return;
    final answer = await showDialog<ReactionType>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Do you feel better?',
            style: TextStyle(color: Colors.white, fontSize: 26)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _reactionButton(ReactionType.better, 'Better',
                Icons.sentiment_very_satisfied, Colors.green),
            _reactionButton(ReactionType.same, 'The same',
                Icons.sentiment_neutral, Colors.blueGrey),
            _reactionButton(ReactionType.worse, 'Worse',
                Icons.sentiment_dissatisfied, Colors.orange),
          ],
        ),
      ),
    );
    if (answer != null) {
      await viewModel.recordReaction(
          widget.patientId, memory, moodBefore, answer);
    }
  }

  Widget _reactionButton(
      ReactionType type, String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 56),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 18)),
      onPressed: () => Navigator.of(context).pop(type),
    );
  }

  Future<void> _showMemory(Memory memory, {required String heading}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          heading.isEmpty ? memory.title : heading,
          style: const TextStyle(color: Colors.white, fontSize: 26),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 200, child: _photo(memory.photoUrl)),
              ),
              const SizedBox(height: 16),
              Text(
                memory.toNarration(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.volume_up),
            label: const Text('Hear again'),
            onPressed: () => viewModel.playStory(memory),
          ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _photo(String? url) {
    const placeholder = Center(
      child: Icon(Icons.photo, size: 64, color: Colors.white38),
    );
    if (url == null || url.isEmpty) return placeholder;
    if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (_, __, ___) => placeholder);
    }
    final file = File(url);
    if (!file.existsSync()) return placeholder;
    return Image.file(file, fit: BoxFit.cover, width: double.infinity);
  }

  @override
  Widget build(BuildContext context) => render();

  Widget render() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Memories'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          _moodRow(),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _moodRow() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          const Text(
            'How are you feeling?',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _moods.entries
                .map((e) => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(110, 48),
                      ),
                      icon: Icon(e.value),
                      label: Text(e.key, style: const TextStyle(fontSize: 16)),
                      onPressed: () => onMoodSelected(e.key),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = viewModel.errorMessage;
    if (error != null) {
      return Center(
        child: Text(error, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    final memories = viewModel.memories;
    if (memories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No memories yet. Ask your caregiver to add some photos and stories.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: memories.length,
      itemBuilder: (_, index) {
        final memory = memories[index];
        return InkWell(
          onTap: () => onMemoryTapped(memory),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            color: Colors.grey[850],
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _photo(memory.photoUrl)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    memory.personName.isNotEmpty
                        ? memory.personName
                        : memory.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
