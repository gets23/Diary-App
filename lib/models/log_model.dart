class ReadingLog {
  final String id;
  final String bookId;
  final String title;
  final int pageLogged;
  final String notes;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String username;

  ReadingLog({
    required this.id,
    required this.bookId,
    required this.title,
    required this.pageLogged,
    required this.notes,
    this.imagePath,
    required this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.address,
    required this.username,
  });

  factory ReadingLog.fromMap(Map<dynamic, dynamic> map) {
    return ReadingLog(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback ID
      bookId: map['bookId'] ?? '',
      title: map['title'] ?? 'Catatan Harian',
      notes: map['notes'] ?? '',
      pageLogged: map['pageLogged'] ?? 0,
      imagePath: map['imagePath'],
      createdAt: map['createdAt'] ?? DateTime.now(),
      updatedAt: map['updatedAt'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
      username: map['username'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'notes': notes,
      'pageLogged': pageLogged,
      'imagePath': imagePath,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'username': username,
    };
  }
}

