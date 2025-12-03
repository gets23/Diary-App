import 'package:hive_flutter/hive_flutter.dart';
import '../models/log_model.dart';
import '../models/book_model.dart';

class LogController {
  final Box _logBox = Hive.box('logBox');
  final Box _bookBox = Hive.box('bookBox');

  // CREATE (Tambah Log Baru)
  Future<void> addLog(ReadingLog log, String hiveKeyBook, double price) async {
    // Simpan ke Hive (otomatis pakai toMap dari Model)
    await _logBox.add(log.toMap());
    
    // Update progress di buku terkait
    await _updateBookProgress(hiveKeyBook, log.pageLogged, price);
  }

  // UPDATE (Edit Log yang sudah ada)
  Future<void> updateLog(int logKey, ReadingLog newLog, String hiveKeyBook, double price) async {
    // Timpa data lama dengan data baru
    await _logBox.put(logKey, newLog.toMap());
    
    // Update progress buku (karena halaman mungkin berubah)
    await _updateBookProgress(hiveKeyBook, newLog.pageLogged, price);
  }

  // DELETE (Hapus Log)
  Future<void> deleteLog(int logKey) async {
    await _logBox.delete(logKey);
    // Note: Idealnya kita cek log sebelumnya untuk rollback halaman buku, 
    // tapi untuk MVP, membiarkan halaman terakhir tetap tersimpan di buku juga tidak masalah.
  }

  // Helper Private: Update Status & Halaman Buku
  Future<void> _updateBookProgress(String hiveKeyBook, int page, double price) async {
    final data = _bookBox.get(hiveKeyBook);
    if (data != null) {
      final book = Book.fromMap(Map<dynamic, dynamic>.from(data));
      
      // Update data buku
      book.currentPage = page;
      book.price = price;
      
      // Cek status selesai
      if (book.currentPage >= book.pageCount && book.pageCount > 0) {
        book.status = 'Finished';
      } else {
        book.status = 'Reading Now';
      }
      
      // Simpan balik ke Hive
      await _bookBox.put(hiveKeyBook, book.toMap());
    }
  }

  // READ (Ambil Log untuk Buku Tertentu + Key-nya buat Edit/Hapus)
  List<Map<String, dynamic>> getLogsWithKeys(String bookId, String username) {
    List<Map<String, dynamic>> results = [];
    
    for (var key in _logBox.keys) {
      final map = Map<dynamic, dynamic>.from(_logBox.get(key) as Map);
      final log = ReadingLog.fromMap(map);
      
      // Filter punya siapa & buku apa
      if (log.bookId == bookId && log.username == username) {
        results.add({'key': key, 'log': log});
      }
    }
    
    // Sort dari yang paling baru (Descending)
    // PERBAIKAN: Menggunakan 'createdAt' bukan 'timestamp'
    results.sort((a, b) {
      final logA = a['log'] as ReadingLog;
      final logB = b['log'] as ReadingLog;
      return logB.createdAt.compareTo(logA.createdAt);
    });
    
    return results;
  }
}