import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/i_memory_repository.dart';
import '../domain/memory.dart';
import '../domain/mood_entry.dart';

/// Infrastructure layer – Persistence subsystem.
///
/// Cloud Firestore implementation of [IMemoryRepository] (Repository / Adapter).
class FirestoreMemoryRepository implements IMemoryRepository {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final String moodCollectionPath;

  FirestoreMemoryRepository({
    FirebaseFirestore? firestore,
    this.collectionPath = 'memories',
    this.moodCollectionPath = 'moodEntries',
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
}
