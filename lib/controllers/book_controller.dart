import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';
import '../utils/constants.dart'; // Pastikan GOOGLE_BOOKS_API_KEY ada di sini

class BookController {
  final Box _bookBox = Hive.box('bookBox');
  final Box _logBox = Hive.box('logBox');

  // --- 1. PENCARIAN CANGGIH (Filter Judul, Penulis, dll) ---
  Future<List<dynamic>> searchBooksFromApi(String query, {String filterType = 'general'}) async {
    if (query.trim().isEmpty) return [];

    // Construct Query sesuai Filter
    String q = query.trim();
    if (filterType == 'judul') q = 'intitle:$query';
    else if (filterType == 'penulis') q = 'inauthor:$query';
    else if (filterType == 'isbn') q = 'isbn:$query';
    else if (filterType == 'genre') q = 'subject:$query';

    try {
      // Menggunakan replaceAll untuk spasi agar URL valid
      final encodedQuery = q.replaceAll(' ', '+'); 
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$encodedQuery&key=$GOOGLE_BOOKS_API_KEY&maxResults=20&printType=books');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] ?? [];
      }
      return []; // Return kosong jika gagal, jangan throw error biar UI gak crash
    } catch (e) {
      // Silent error, kembalikan list kosong agar UI menampilkan placeholder "Tidak ditemukan"
      return [];
    }
  }

  // --- 2. FITUR REKOMENDASI & TRENDING ---
  
  // Default: Buku Fiksi Terbaru
  Future<List<dynamic>> getTrendingBooks() async {
    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=subject:fiction&orderBy=newest&key=$GOOGLE_BOOKS_API_KEY&maxResults=10&printType=books');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Rekomendasi Personal
  Future<List<dynamic>> getRecommendations(String username) async {
    final userBooks = getUserBooks(username);
    
    // 1. Jika User Belum Punya Buku -> Tampilkan Trending
    if (userBooks.isEmpty) return getTrendingBooks();

    // 2. Analisis Genre Terbanyak
    Map<String, int> genreCounts = {};
    for (var book in userBooks) {
      // Parsing: Ambil kata pertama dari "Fiction / Fantasy / Epic" -> "Fiction"
      String genre = book.category.split(' / ').first.trim();
      
      // Filter genre sampah/terlalu umum
      if (['N/A', 'General', 'Umum', ''].contains(genre)) continue;
      
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }

    // Jika setelah difilter tidak ada genre valid, kembali ke Trending
    if (genreCounts.isEmpty) return getTrendingBooks();

    // 3. Ambil Top Genre
    String topGenre = genreCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // 4. Fetch API berdasarkan Top Genre
    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=subject:$topGenre&orderBy=relevance&key=$GOOGLE_BOOKS_API_KEY&maxResults=10&printType=books');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> items = data['items'] ?? [];
        
        // Filter agar buku yang SUDAH ADA di library tidak muncul lagi di rekomendasi
        final myBookIds = userBooks.map((b) => b.id).toSet();
        items.removeWhere((item) => myBookIds.contains(item['id']));
        
        return items;
      }
    } catch (_) {}
    
    // Fallback terakhir
    return getTrendingBooks();
  }

  // --- 3. CRUD BUKU ---
  
  Future<String?> saveBook(Map<String, dynamic> apiData, String username) async {
    final String id = apiData['id'];
    final String hiveKey = "${username}_$id";

    // Cek Duplikasi
    if (_bookBox.containsKey(hiveKey)) return "Buku ini sudah ada di koleksimu.";

    final vol = apiData['volumeInfo'];
    
    // Parsing Harga (Robust)
    double price = 0.0;
    String currency = 'IDR';
    if (apiData['saleInfo'] != null && apiData['saleInfo']['listPrice'] != null) {
       price = (apiData['saleInfo']['listPrice']['amount'] ?? 0).toDouble();
       currency = apiData['saleInfo']['listPrice']['currencyCode'] ?? 'IDR';
    }

    final book = Book(
      id: id,
      title: vol['title'] ?? 'Tanpa Judul',
      authors: (vol['authors'] as List?)?.join(', ') ?? 'Penulis Tidak Diketahui',
      coverUrl: vol['imageLinks']?['thumbnail'] ?? '',
      pageCount: vol['pageCount'] ?? 0,
      description: vol['description'] ?? 'Tidak ada deskripsi.',
      category: (vol['categories'] as List?)?.first ?? 'Umum',
      currentPage: 0,
      status: 'To Read', // Default Status
      price: price,
      currency: currency,
      review: '',
      rating: 0,
      username: username,
    );

    await _bookBox.put(hiveKey, book.toMap());
    return null; // Null berarti sukses (tidak ada error message)
  }

  // Get Books dengan Filter Lokal
  List<Book> getUserBooks(String username, {String? filterGenre, String? filterStatus}) {
    var books = _bookBox.values
        .map((e) => Book.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .where((b) => b.username == username);

    // Filter Genre
    if (filterGenre != null && filterGenre != 'Semua') {
      // Matches partial string, e.g. "Fiction" matches "Fiction / Fantasy"
      books = books.where((b) => b.category.contains(filterGenre));
    }
    
    // Filter Status
    if (filterStatus != null && filterStatus != 'Semua') {
      String target = '';
      if (filterStatus == 'Selesai') target = 'Finished';
      else if (filterStatus == 'Sedang Baca') target = 'Reading Now';
      else if (filterStatus == 'Belum Baca') target = 'To Read';
      
      if (target.isNotEmpty) books = books.where((b) => b.status == target);
    }

    return books.toList().reversed.toList(); // Urutkan dari yang baru ditambahkan
  }

  Book? getBook(String hiveKey) {
    final data = _bookBox.get(hiveKey);
    if (data == null) return null;
    return Book.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<void> updateReview(String hiveKey, int rating, String review) async {
    final data = _bookBox.get(hiveKey);
    if (data != null) {
      final bookMap = Map<String, dynamic>.from(data as Map);
      bookMap['rating'] = rating;
      bookMap['review'] = review;
      await _bookBox.put(hiveKey, bookMap);
    }
  }

  Future<void> deleteBook(String hiveKey, String bookId, String username) async {
    await _bookBox.delete(hiveKey);
    
    // Hapus Log Terkait (Clean Up)
    final keysToDelete = _logBox.keys.where((k) {
      final l = Map<String, dynamic>.from(_logBox.get(k) as Map);
      return l['bookId'] == bookId && l['username'] == username;
    }).toList();
    
    for(var k in keysToDelete) {
      await _logBox.delete(k);
    }
  }
}