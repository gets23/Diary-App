import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamification_model.dart';

class AuthController {
  final Box _userBox = Hive.box('userBox');
  final Box _profileBox = Hive.box('profileBox');

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Login Logic
  Future<bool> login(String username, String password) async {
    final userData = _userBox.get(username);
    if (userData != null && userData['password'] == _hashPassword(password)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loggedInUser', username);
      return true;
    }
    return false;
  }

  // Register Logic
  Future<String?> register(String email, String username, String password) async {
    // Validasi sederhana
    final emailExists = _userBox.values.any((u) => (u as Map)['email'] == email);
    if (emailExists) return "Email sudah terdaftar.";
    if (_userBox.containsKey(username)) return "Username sudah digunakan.";

    // Simpan User Credential
    await _userBox.put(username, {
      'email': email,
      'password': _hashPassword(password),
    });

    // Inisialisasi Gamification Profile untuk User Baru
    final initialProfile = GamificationProfile(
      xp: 0, level: 1, streak: 1, 
      lastLoginDate: DateTime.now(), 
      hasLoggedFirstTime: false
    );
    await _profileBox.put(username, initialProfile.toMap());

    return null; // Null artinya sukses
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}