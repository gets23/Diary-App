import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // WAJIB ADA: Untuk simpan permanen
import 'package:path/path.dart' as path; // WAJIB ADA: Untuk manipulasi nama file

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

  // FITUR FIX: Simpan Foto Permanen & SnackBar
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      
      if (pickedFile != null && _username != null) {
        // 1. Ambil folder dokumen aplikasi (Permanen)
        final directory = await getApplicationDocumentsDirectory();
        final fileName = path.basename(pickedFile.path); // Ambil nama file asli
        final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName'); // Copy ke folder permanen

        // 2. Simpan path BARU (yang permanen) ke Hive
        await _gameController.updateProfilePicture(_username!, savedImage.path);
        
        setState((){}); // Refresh UI

        // 3. Tampilkan SnackBar (Feedback Poin 2)
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto profil berhasil diperbarui!"), backgroundColor: accentGreen)
          );
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengganti foto."), backgroundColor: errorRed)
        );
      }
    }
  }

  // LOGIC: Logout dengan Konfirmasi
  Future<void> _confirmLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Apakah kamu yakin ingin keluar dari akun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            onPressed: () async {
              Navigator.pop(ctx); 
              await _authController.logout();
              if(mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (r)=>false);
              }
            }, 
            child: const Text("Keluar")
          ),
        ],
      )
    );
  }

  // DATA: Detail Achievement
  List<Map<String, dynamic>> _getAchievementList(String user) {
    final books = _bookController.getUserBooks(user);
    final finished = books.where((b) => b.status == 'Finished').length;
    final totalPages = books.fold(0, (p, c) => p + c.currentPage);
    final logs = Hive.box('logBox').values.where((l) => (l as Map)['username'] == user && l['latitude'] != null);
    
    return [
      { 'title': 'Kutu Buku Pemula', 'desc': 'Selesaikan 1 buku', 'isUnlocked': finished >= 1 },
      { 'title': 'Kolektor', 'desc': 'Koleksi 5 buku di library', 'isUnlocked': books.length >= 5 },
      { 'title': 'Maraton Pemula', 'desc': 'Baca total 1000 halaman', 'isUnlocked': totalPages >= 1000 },
      { 'title': 'Penjelajah', 'desc': 'Catat log dengan lokasi (LBS)', 'isUnlocked': logs.isNotEmpty },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Profil Saya"), automaticallyImplyLeading: false),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('profileBox').listenable(),
        builder: (context, box, _) {
          final profile = _gameController.getProfile(_username!);
          final achievements = _getAchievementList(_username!);
          
          final books = _bookController.getUserBooks(_username!);
          final finishedCount = books.where((b) => b.status == 'Finished').length;
          final totalPages = books.fold(0, (p, c) => p + c.currentPage);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // --- 1. HEADER PROFIL ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: primaryPurple, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                child: Column(children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                        child: CircleAvatar(
                          radius: 50, backgroundColor: Colors.white,
                          backgroundImage: profile.profilePicturePath != null 
                            ? FileImage(File(profile.profilePicturePath!)) 
                            : null,
                          child: profile.profilePicturePath == null ? const Icon(Icons.person, color: Colors.grey, size: 50) : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: accentYellow, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_username!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Level ${profile.level}", style: const TextStyle(fontSize: 16, color: accentYellow, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: profile.xp / _gameController.getXpForNextLevel(profile.level), 
                      backgroundColor: Colors.black12, 
                      color: accentYellow
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("${profile.xp} / ${_gameController.getXpForNextLevel(profile.level)} XP", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 20),

              // --- 2. STATISTIK ---
              Row(
                children: [
                  Expanded(child: _buildStatCard("Buku Tamat", "$finishedCount", Icons.menu_book)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard("Halaman", "$totalPages", Icons.pages)),
                ],
              ),
              const SizedBox(height: 24),
              
              // --- 3. LIST PENCAPAIAN ---
              Align(alignment: Alignment.centerLeft, child: Text("Pencapaian", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary))),
              const SizedBox(height: 12),
              ...achievements.map((item) {
                bool isUnlocked = item['isUnlocked'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: isUnlocked ? Colors.white : Colors.grey.shade50,
                  elevation: isUnlocked ? 2 : 0,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isUnlocked ? accentYellow.withOpacity(0.2) : Colors.grey[200], shape: BoxShape.circle),
                      child: Icon(Icons.emoji_events, color: isUnlocked ? accentYellow : Colors.grey, size: 24),
                    ),
                    title: Text(item['title'], style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? textPrimary : Colors.grey)),
                    subtitle: Text(item['desc'], style: TextStyle(fontSize: 12, color: textSecondary)),
                    trailing: isUnlocked ? const Icon(Icons.check_circle, color: accentGreen) : const Icon(Icons.lock, color: Colors.grey, size: 16),
                  ),
                );
              }),

              const SizedBox(height: 24),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: errorRed.withOpacity(0.1),
                leading: const Icon(Icons.logout, color: errorRed),
                title: const Text("Keluar Akun", style: TextStyle(color: errorRed, fontWeight: FontWeight.bold)),
                onTap: _confirmLogout,
              ),
              const SizedBox(height: 40),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryPurple, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
          Text(label, style: const TextStyle(fontSize: 12, color: textSecondary)),
        ],
      ),
    );
  }
}