import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/gamification_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/book_controller.dart';
import '../../utils/constants.dart';
import '../auth/login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String? _username;
  final _gameController = GamificationController();
  final _bookController = BookController();
  final _authController = AuthController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _username = p.getString('loggedInUser')));
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if(f != null && _username != null) {
      await _gameController.updateProfilePicture(_username!, f.path);
      setState((){});
    }
  }

  // FITUR: Perhitungan Statistik untuk Achievements
  Map<String, bool> _calculateAchievements(String user) {
    final books = _bookController.getUserBooks(user);
    final finished = books.where((b) => b.status == 'Finished').length;
    final totalPages = books.fold(0, (p, c) => p + c.currentPage);
    // Cek LBS: kita perlu akses log box manual disini untuk cek latitude
    final logs = Hive.box('logBox').values.where((l) => (l as Map)['username'] == user && l['latitude'] != null);
    
    return {
      'Kutu Buku Pemula': finished >= 1,
      'Kolektor': books.length >= 5,
      'Maraton Pemula': totalPages >= 1000,
      'Penjelajah': logs.isNotEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text("Profil Saya"), automaticallyImplyLeading: false),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('profileBox').listenable(),
        builder: (context, box, _) {
          final profile = _gameController.getProfile(_username!);
          final achievements = _calculateAchievements(_username!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: primaryPurple, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50, backgroundColor: Colors.white,
                      backgroundImage: profile.profilePicturePath != null ? FileImage(File(profile.profilePicturePath!)) : null,
                      child: profile.profilePicturePath == null ? const Icon(Icons.camera_alt, color: primaryPurple, size: 30) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_username!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Level ${profile.level}", style: const TextStyle(fontSize: 16, color: accentYellow, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: profile.xp / _gameController.getXpForNextLevel(profile.level), backgroundColor: Colors.white24, color: accentYellow),
                  const SizedBox(height: 4),
                  Text("${profile.xp} / ${_gameController.getXpForNextLevel(profile.level)} XP", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 24),
              
              // FITUR: Achievements List Dikembalikan
              Align(alignment: Alignment.centerLeft, child: Text("Pencapaian", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary))),
              const SizedBox(height: 12),
              ...achievements.entries.map((e) => Card(
                color: e.value ? Colors.white : Colors.grey.shade100,
                child: ListTile(
                  leading: Icon(e.value ? Icons.emoji_events : Icons.lock, color: e.value ? accentYellow : Colors.grey, size: 32),
                  title: Text(e.key, style: TextStyle(fontWeight: FontWeight.bold, color: e.value ? textPrimary : Colors.grey)),
                  subtitle: Text(e.value ? "Telah dibuka" : "Belum terbuka", style: TextStyle(fontSize: 12, color: e.value ? accentGreen : textSecondary)),
                ),
              )),

              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.logout, color: errorRed),
                title: const Text("Keluar", style: TextStyle(color: errorRed, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await _authController.logout();
                  if(mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (r)=>false);
                },
              )
            ]),
          );
        },
      ),
    );
  }
}