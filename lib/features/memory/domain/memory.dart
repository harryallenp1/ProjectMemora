/// Domain layer – Memory Domain subsystem.
///
/// A personal memory (photo, person and story) that a caregiver adds for a
/// patient. UC-03: Personalized Memory and Emotional Support.
class Memory {
  final String? memoryId;
  final String patientId;
  final String title;
  final String personName;
  final String relationship;
  final String story;
  final String? photoUrl;
  final String createdBy;
  final DateTime dateAdded;

  const Memory({
    this.memoryId,
    required this.patientId,
    required this.title,
    required this.personName,
    required this.relationship,
    required this.story,
    this.photoUrl,
    required this.createdBy,
    required this.dateAdded,
  });

  /// Text that is read aloud to the patient, e.g.
  /// "This is Anna, your daughter. Anna's wedding. You walked her down the aisle."
  String toNarration() {
    final parts = <String>[];
    final name = personName.trim();
    final rel = relationship.trim();
    if (name.isNotEmpty) {
      parts.add(rel.isNotEmpty ? 'This is $name, your $rel.' : 'This is $name.');
    }
    if (title.trim().isNotEmpty) parts.add(_asSentence(title));
    if (story.trim().isNotEmpty) parts.add(_asSentence(story));
    return parts.join(' ');
  }

  static String _asSentence(String text) {
    final t = text.trim();
    if (t.endsWith('.') || t.endsWith('!') || t.endsWith('?')) return t;
    return '$t.';
  }

  Memory copyWith({String? memoryId}) => Memory(
        memoryId: memoryId ?? this.memoryId,
        patientId: patientId,
        title: title,
        personName: personName,
        relationship: relationship,
        story: story,
        photoUrl: photoUrl,
        createdBy: createdBy,
        dateAdded: dateAdded,
      );

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'title': title,
        'personName': personName,
        'relationship': relationship,
        'story': story,
        'photoUrl': photoUrl,
        'createdBy': createdBy,
        'dateAdded': dateAdded.toIso8601String(),
      };

  factory Memory.fromMap(Map<String, dynamic> map, {String? id}) => Memory(
        memoryId: id ?? map['memoryId'] as String?,
        patientId: (map['patientId'] ?? '') as String,
        title: (map['title'] ?? '') as String,
        personName: (map['personName'] ?? '') as String,
        relationship: (map['relationship'] ?? '') as String,
        story: (map['story'] ?? '') as String,
        photoUrl: map['photoUrl'] as String?,
        createdBy: (map['createdBy'] ?? '') as String,
        dateAdded: DateTime.tryParse((map['dateAdded'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
