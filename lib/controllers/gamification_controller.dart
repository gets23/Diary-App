import 'package:hive_flutter/hive_flutter.dart';
import '../models/gamification_model.dart';
import '../models/book_model.dart';
import '../services/notification_service.dart';

class GamificationController {
  final Box _profileBox = Hive.box('profileBox');
  final Box _bookBox = Hive.box('bookBox');
  final Box _logBox = Hive.box('logBox');
  final NotificationService _notificationService = NotificationService();

  GamificationProfile getProfile(String username) {
    final data = _profileBox.get(username);
    if (data == null) {
      return GamificationProfile(
        xp: 0, level: 1, streak: 1, 
        lastLoginDate: DateTime.now(), 
        hasLoggedFirstTime: false
      );
    }
    return GamificationProfile.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> _saveProfile(String username, GamificationProfile profile) async {
    await _profileBox.put(username, profile.toMap());
  }

  int getXpForNextLevel(int currentLevel) => currentLevel * 150;

  // --- LOGIC REWARDS ---
  Future<bool> processLogRewards(String username, Book book, int newPage) async {
    int earnedXp = 0;
    
    // 1. Ambil Profile saat ini
    var profile = getProfile(username);
    bool shouldTriggerFirstLogNotif = false;

    // 2. Cek Log Pertama
    if (!profile.hasLoggedFirstTime) {
      earnedXp += 50;
      profile.hasLoggedFirstTime = true;
      shouldTriggerFirstLogNotif = true;
    }

    // 3. Cek Buku Selesai
    bool isFinishedNow = newPage >= book.pageCount && book.pageCount > 0;
    bool wasNotFinished = book.status != 'Finished';

    if (isFinishedNow && wasNotFinished) {
       earnedXp += 200;
       if (book.pageCount >= 100) earnedXp += 100;
    }

    // 4. SIMPAN KE DATABASE
    bool didLevelUp = await _applyXpToProfile(username, profile, earnedXp);

    // 5. TRIGGER NOTIFIKASI (FIXED: Pakai showNotificationNow)
    if (shouldTriggerFirstLogNotif) {
      await _notificationService.requestPermissions();
      // PERBAIKAN DI SINI:
      await _notificationService.showNotificationNow(
        title: "Log Pertama!", 
        body: "Selamat! Kamu dapat +50 XP untuk log pertamamu."
      );
    }

    return didLevelUp;
  }

  // Fungsi publik untuk nambah XP manual
  Future<bool> addXp(String username, int amount) async {
    var profile = getProfile(username);
    return await _applyXpToProfile(username, profile, amount);
  }

  // Fungsi Internal
  Future<bool> _applyXpToProfile(String username, GamificationProfile profile, int amount) async {
    int currentLevel = profile.level;
    int currentXp = profile.xp + amount;
    int xpToNext = getXpForNextLevel(currentLevel);
    bool didLevelUp = false;

    while (currentXp >= xpToNext) {
      currentLevel++;
      currentXp -= xpToNext;
      didLevelUp = true;
      xpToNext = getXpForNextLevel(currentLevel);
    }

    profile.xp = currentXp;
    profile.level = currentLevel;

    await _saveProfile(username, profile);
    return didLevelUp;
  }

  Future<void> updateStreak(String username) async {
    var profile = getProfile(username);
    DateTime now = DateTime.now();
    DateTime lastLogin = DateTime(profile.lastLoginDate.year, profile.lastLoginDate.month, profile.lastLoginDate.day);
    DateTime today = DateTime(now.year, now.month, now.day);

    int diff = today.difference(lastLogin).inDays;
    
    if (diff == 1) {
      profile.streak++;
    } else if (diff > 1) {
      profile.streak = 1;
    }
    
    profile.lastLoginDate = now;
    await _saveProfile(username, profile);
  }

  Future<void> updateProfilePicture(String username, String path) async {
    var profile = getProfile(username);
    profile.profilePicturePath = path;
    await _saveProfile(username, profile);
  }

  // --- LOGIC ACHIEVEMENT TERDEKAT ---
  Map<String, dynamic> getNearestAchievement(String username) {
    final books = _bookBox.values.where((b) => (b as Map)['username'] == username).toList();
    final logs = _logBox.values.where((l) => (l as Map)['username'] == username).toList();
    
    int finishedCount = books.where((b) => b['status'] == 'Finished').length;
    int totalPagesRead = books.fold(0, (sum, b) => sum + ((b['currentPage'] ?? 0) as int));
    bool hasLBS = logs.any((l) => l['latitude'] != null);

    List<Map<String, dynamic>> targets = [
      {
        'title': 'Kutu Buku Pemula',
        'desc': 'Selesaikan 1 buku',
        'current': finishedCount,
        'target': 1,
        'isBool': false
      },
      {
        'title': 'Kolektor',
        'desc': 'Koleksi 5 buku',
        'current': books.length,
        'target': 5,
        'isBool': false
      },
      {
        'title': 'Maraton Pemula',
        'desc': 'Baca 1000 halaman',
        'current': totalPagesRead,
        'target': 1000,
        'isBool': false
      },
      {
        'title': 'Penjelajah',
        'desc': 'Check-in lokasi pertama',
        'current': hasLBS ? 1 : 0,
        'target': 1,
        'isBool': true
      }
    ];

    Map<String, dynamic> best = {};
    double maxProgress = -1.0;

    for (var t in targets) {
      double p = t['current'] / t['target'];
      if (p < 1.0 && p > maxProgress) {
        maxProgress = p;
        best = t;
        best['progress'] = p;
      }
    }

    if (best.isEmpty) {
        var unfinished = targets.firstWhere((t) => t['current'] < t['target'], orElse: () => {});
        if (unfinished.isNotEmpty) {
            best = unfinished;
            best['progress'] = (best['current'] / best['target']).toDouble();
        } else {
            return {
                'title': 'Master Pembaca', 
                'desc': 'Semua achievement tercapai!', 
                'progress': 1.0, 
                'target': 1, 
                'current': 1
            };
        }
    }
    
    return best;
  }
}