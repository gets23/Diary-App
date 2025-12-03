class GamificationProfile {
  int xp;
  int level;
  int streak;
  DateTime lastLoginDate;
  bool hasLoggedFirstTime;
  String? profilePicturePath; // Fitur Baru: Foto Profil

  GamificationProfile({
    required this.xp,
    required this.level,
    required this.streak,
    required this.lastLoginDate,
    required this.hasLoggedFirstTime,
    this.profilePicturePath,
  });

  factory GamificationProfile.fromMap(Map<dynamic, dynamic> map) {
    return GamificationProfile(
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      streak: map['streak'] ?? 1,
      lastLoginDate: DateTime.parse(map['lastLoginDate'] ?? DateTime.now().toIso8601String()),
      hasLoggedFirstTime: map['hasLoggedFirstTime'] ?? false,
      profilePicturePath: map['profilePicturePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xp': xp,
      'level': level,
      'streak': streak,
      'lastLoginDate': lastLoginDate.toIso8601String(),
      'hasLoggedFirstTime': hasLoggedFirstTime,
      'profilePicturePath': profilePicturePath,
    };
  }
}