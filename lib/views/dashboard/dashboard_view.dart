import 'dart:io'; // Tambahkan ini untuk File Image
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/gamification_controller.dart';
import '../../controllers/book_controller.dart';
import '../../utils/constants.dart';
import '../books/book_detail_view.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onNavigateToSearch;
  final VoidCallback onNavigateToCollection;

  const DashboardView({
    super.key,
    required this.onNavigateToSearch,
    required this.onNavigateToCollection,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String? _username;
  final _gameController = GamificationController();
  final _bookController = BookController();
  
  // Future untuk rekomendasi agar tidak reload terus
  Future<List<dynamic>>? _recommendationFuture;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('loggedInUser');
    
    if (mounted) {
      setState(() {
        _username = user;
        if (user != null) {
          _recommendationFuture = _bookController.getRecommendations(user);
        }
      });
    }
    
    if (user != null) {
      await _gameController.updateStreak(user);
    }
  }

  // --- LOGIC: SIMPAN BUKU DARI REKOMENDASI ---
  void _showBookDetailBottomSheet(Map<String, dynamic> bookData) {
    // Parsing data dasar untuk display
    final vol = bookData['volumeInfo'];
    final title = vol['title'] ?? 'Tanpa Judul';
    final author = (vol['authors'] as List?)?.join(', ') ?? 'Penulis Tidak Diketahui';
    final desc = vol['description'] ?? 'Tidak ada deskripsi.';
    final imgUrl = vol['imageLinks']?['thumbnail'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imgUrl.isNotEmpty
                          ? Image.network(imgUrl, width: 100, fit: BoxFit.cover)
                          : Container(width: 100, height: 150, color: Colors.grey[300], child: const Icon(Icons.book)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(author, style: const TextStyle(color: textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (_username != null) {
                                // Panggil Controller untuk simpan
                                final error = await _bookController.saveBook(bookData, _username!);
                                if (mounted) {
                                  Navigator.pop(ctx); // Tutup sheet
                                  if (error == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Buku ditambahkan ke koleksi!"), backgroundColor: accentGreen));
                                    // Refresh Dashboard/Collection logic if needed
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: accentYellow));
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Simpan ke Koleksi"),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
                          )
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Sinopsis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(desc, style: const TextStyle(height: 1.5, color: textPrimary), textAlign: TextAlign.justify),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPER: Achievement Terdekat ---
  Widget _buildNearestAchievement() {
    final achievement = _gameController.getNearestAchievement(_username!);
    final double progress = achievement['progress'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentYellow.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: accentYellow.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: accentYellow),
              const SizedBox(width: 8),
              const Text("Target Berikutnya", style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12)),
              const Spacer(),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: accentYellow)),
            ],
          ),
          const SizedBox(height: 8),
          Text(achievement['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
          Text(achievement['desc'], style: const TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[100],
              color: accentYellow,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${achievement['current']} / ${achievement['target']}", 
              style: const TextStyle(fontSize: 10, color: textSecondary)
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: List Buku Horizontal ---
  Widget _buildHorizontalBookList(List<dynamic> books, {bool isLocal = false}) {
    if (books.isEmpty) return const SizedBox();

    return SizedBox(
      height: 220, // Agak tinggiin dikit biar muat
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          String title, cover, hiveKey;
          
          if (isLocal) {
            title = book.title;
            cover = book.coverUrl;
            hiveKey = "${_username}_${book.id}";
          } else {
            final info = book['volumeInfo'];
            title = info['title'] ?? 'Judul';
            cover = info['imageLinks']?['thumbnail'] ?? '';
            hiveKey = ""; 
          }

          return GestureDetector(
            // Logic Klik: Jika Lokal -> Buka Detail, Jika API -> Buka BottomSheet
            onTap: () {
              if (isLocal) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailView(hiveKey: hiveKey)));
              } else {
                _showBookDetailBottomSheet(book);
              }
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: cover.isNotEmpty 
                        ? Image.network(cover, height: 160, width: 120, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(height: 160, width: 120, color: Colors.grey[300], child: const Icon(Icons.broken_image)))
                        : Container(height: 160, width: 120, color: Colors.grey[300], child: const Icon(Icons.book)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Greeting (Sinkronisasi PFP)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Halo, Pembaca!', style: TextStyle(fontSize: 16, color: textSecondary)),
                      Text(_username!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  // Avatar Sinkron dengan Hive ProfileBox
                  ValueListenableBuilder(
                    valueListenable: Hive.box('profileBox').listenable(),
                    builder: (context, box, _) {
                      final profile = _gameController.getProfile(_username!);
                      return CircleAvatar(
                        radius: 25,
                        backgroundColor: primaryPurple,
                        backgroundImage: profile.profilePicturePath != null 
                            ? FileImage(File(profile.profilePicturePath!)) 
                            : null,
                        child: profile.profilePicturePath == null 
                            ? const Icon(Icons.person, color: Colors.white) 
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Gamification Card
            ValueListenableBuilder(
              valueListenable: Hive.box('profileBox').listenable(),
              builder: (context, box, _) {
                final profile = _gameController.getProfile(_username!);
                final nextXp = _gameController.getXpForNextLevel(profile.level);
                final progress = nextXp > 0 ? profile.xp / nextXp : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [primaryPurple, Color(0xFF8E7CFF)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [const Icon(Icons.shield, color: Colors.white, size: 16), const SizedBox(width: 6), Text("Level ${profile.level}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [const Icon(Icons.local_fire_department, color: accentYellow, size: 16), const SizedBox(width: 6), Text("${profile.streak} Hari", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(value: progress, backgroundColor: Colors.black12, color: accentYellow, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${profile.xp} XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text("$nextXp XP", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Achievement Terdekat
            ValueListenableBuilder(
              valueListenable: Hive.box('logBox').listenable(),
              builder: (context, _, __) {
                return _buildNearestAchievement();
              }
            ),

            // Buku Terbaru (Lokal)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Buku Terbaru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(onTap: widget.onNavigateToCollection, child: const Text("Lihat Semua", style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('bookBox').listenable(),
              builder: (context, box, _) {
                final books = _bookController.getUserBooks(_username!).take(3).toList();
                if (books.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text("Belum ada buku.", style: TextStyle(color: textSecondary)),
                          TextButton(onPressed: widget.onNavigateToSearch, child: const Text("Mulai Cari"))
                        ],
                      ),
                    ),
                  );
                }
                return _buildHorizontalBookList(books, isLocal: true);
              },
            ),

            // Rekomendasi Untukmu (API)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: const Text("Rekomendasi Untukmu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            FutureBuilder<List<dynamic>>(
              future: _recommendationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Belum ada rekomendasi. Baca lebih banyak buku!", style: TextStyle(color: textSecondary, fontStyle: FontStyle.italic)));
                }
                return _buildHorizontalBookList(snapshot.data!, isLocal: false);
              },
            ),

            const SizedBox(height: 100), // Padding Bawah agar tidak tertutup nav bar
          ],
        ),
      ),
    );
  }
}