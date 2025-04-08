class Item {
  final int? id;
  final int userId; // ✅ Link to patient
  final String name;
  final String description;
  final String? imagePath;
  final String? location;
  final String? dateAdded;

  Item({
    this.id,
    required this.userId, // required now
    required this.name,
    required this.description,
    this.imagePath,
    this.location,
    this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'location': location,
      'dateAdded': dateAdded,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      description: map['description'],
      imagePath: map['imagePath'],
      location: map['location'],
      dateAdded: map['dateAdded'],
    );
  }
}
