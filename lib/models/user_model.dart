// lib/models/user_model.dart
class UserModel {
  final String username;
  final String email;
  final String password;
  final String? profilePicturePath; // Path lokal foto profil

  UserModel({
    required this.username,
    required this.email,
    required this.password,
    this.profilePicturePath,
  });

  factory UserModel.fromMap(Map<dynamic, dynamic> map, String usernameKey) {
    return UserModel(
      username: usernameKey,
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      profilePicturePath: map['profilePicturePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'profilePicturePath': profilePicturePath,
    };
  }
}