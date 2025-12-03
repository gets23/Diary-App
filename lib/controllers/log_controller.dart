import 'package:hive_flutter/hive_flutter.dart';
import '../models/log_model.dart';
import '../models/book_model.dart';

class LogController {
  final Box _logBox = Hive.box('logBox');
  final Box _bookBox = Hive.box('bookBox');

  // --- CREATE (Tambah Log Baru) ---
  // Cocok dengan panggilan di View: addLog(log, hiveKey, price)
  Future<void> addLog(ReadingLog log, String hiveKeyBook, double price) async {
    // Simpan ke Hive
    await _logBox.add(log.toMap());
    
    // Update progress buku
    await _updateBookProgress(hiveKeyBook, log.pageLogged, price);
  }

  // --- UPDATE (Edit Log) ---
  // DIPERBAIKI: Parameter disesuaikan dengan LogEntryView
  Future<void> updateLog(ReadingLog newLog, String hiveKeyBook) async {
    // 1. Cari Key Hive berdasarkan ID unik Log (UUID)
    var keyToUpdate;
    for (var key in _logBox.keys) {
      final val = _logBox.get(key);
      // Pastikan val adalah Map dan cek ID-nya
      if (val != null && val is Map && val['id'] == newLog.id) {
        keyToUpdate = key;
        break;
      }
    }

    // 2. Jika ketemu, timpa datanya
    if (keyToUpdate != null) {
      await _logBox.put(keyToUpdate, newLog.toMap());
      
      // 3. Update halaman di buku (Harga kita skip/opsional di update)
      await _updateBookProgress(hiveKeyBook, newLog.pageLogged, null);
    }
  }

  // --- DELETE (Hapus Log) ---
  // DIPERBAIKI: Mencari berdasarkan ID log (String), bukan Key (int) agar konsisten
  Future<void> deleteLog(String logId, String hiveKeyBook) async {
    var keyToDelete;
    // Cari key-nya dulu
    for (var key in _logBox.keys) {
      final val = _logBox.get(key);
      if (val != null && val is Map && val['id'] == logId) {
        keyToDelete = key;
        break;
      }
    }

    if (keyToDelete != null) {
      await _logBox.delete(keyToDelete);
      // Opsional: Kita bisa tambahkan logika untuk memundurkan halaman buku 
      // jika log terakhir dihapus, tapi untuk sekarang biarkan saja.
    }
  }

  // --- HELPER: Update Status & Halaman Buku ---
  Future<void> _updateBookProgress(String hiveKeyBook, int page, double? price) async {
    final data = _bookBox.get(hiveKeyBook);
    if (data != null) {
      // Pastikan konversi tipe data aman
      final book = Book.fromMap(Map<String, dynamic>.from(data));
      
      // Update halaman
      book.currentPage = page;
      
      // Update harga HANYA jika ada nilai baru (tidak null)
      if (price != null) {
        book.price = price;
      }
      
      // Cek status selesai (Logic Otomatis)
      if (book.currentPage >= book.pageCount && book.pageCount > 0) {
        book.status = 'Finished';
      } else {
        // Jika sebelumnya finished tapi diedit jadi kurang, kembalikan ke Reading
        book.status = 'Reading Now';
      }
      
      // Simpan balik ke Hive
      await _bookBox.put(hiveKeyBook, book.toMap());
    }
  }

  // --- READ (Ambil Log untuk Buku Tertentu) ---
  List<Map<String, dynamic>> getLogsWithKeys(String bookId, String username) {
    List<Map<String, dynamic>> results = [];
    
    for (var key in _logBox.keys) {
      final rawData = _logBox.get(key);
      if (rawData == null) continue;

      final map = Map<String, dynamic>.from(rawData as Map);
      final log = ReadingLog.fromMap(map);
      
      // Filter punya siapa & buku apa
      if (log.bookId == bookId && log.username == username) {
        results.add({'key': key, 'log': log}); // Key tetap dikembalikan untuk referensi internal jika butuh
      }
    }
    
    // Sort dari yang paling baru (Descending by createdAt)
    results.sort((a, b) {
      final logA = a['log'] as ReadingLog;
      final logB = b['log'] as ReadingLog;
      return logB.createdAt.compareTo(logA.createdAt);
    });
    
    return results;
  }
}