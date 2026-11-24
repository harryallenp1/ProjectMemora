import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/i_memory_repository.dart';
import '../domain/memory.dart';
import '../domain/memory_reaction.dart';
import '../domain/mood_entry.dart';

/// Infrastructure layer – Persistence subsystem.
///
/// Cloud Firestore implementation of [IMemoryRepository] (Repository / Adapter).
class FirestoreMemoryRepository implements IMemoryRepository {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final String moodCollectionPath;
  final String reactionCollectionPath;

  FirestoreMemoryRepository({
    FirebaseFirestore? firestore,
    this.collectionPath = 'memories',
    this.moodCollectionPath = 'moodEntries',
    this.reactionCollectionPath = 'memoryReactions',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _memories =>
      _firestore.collection(collectionPath);

  @override
  Future<List<Memory>> findByPatient(String patientId) async {
    final snapshot =
        await _memories.where('patientId', isEqualTo: patientId).get();
    return snapshot.docs
        .map((doc) => Memory.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  @override
  Future<Memory?> findById(String memoryId) async {
    final doc = await _memories.doc(memoryId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Memory.fromMap(data, id: doc.id);
  }

  @override
  Future<Memory> save(Memory memory) async {
    final id = memory.memoryId;
    if (id == null) {
      final ref = await _memories.add(memory.toMap());
      return memory.copyWith(memoryId: ref.id);
    }
    await _memories.doc(id).set(memory.toMap());
    return memory;
  }

  @override
  Future<void> saveMood(MoodEntry entry) async {
    await _firestore.collection(moodCollectionPath).add(entry.toMap());
  }

  // Filtered by patient only and then by date on the device, so Firestore
  // needs no composite index. Fine at capstone scale (a few hundred entries).
  @override
  Future<List<MoodEntry>> findMoods(String patientId,
      {required DateTime since}) async {
    final snapshot = await _firestore
        .collection(moodCollectionPath)
        .where('patientId', isEqualTo: patientId)
        .get();
    return snapshot.docs
        .map((doc) => MoodEntry.fromMap(doc.data(), id: doc.id))
        .where((m) => !m.timestamp.isBefore(since))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> saveReaction(MemoryReaction reaction) async {
    await _firestore.collection(reactionCollectionPath).add(reaction.toMap());
  }

  @override
  Future<List<MemoryReaction>> findReactions(String patientId) async {
    final snapshot = await _firestore
        .collection(reactionCollectionPath)
        .where('patientId', isEqualTo: patientId)
        .get();
    return snapshot.docs.map((d) => MemoryReaction.fromMap(d.data())).toList();
  }
}
