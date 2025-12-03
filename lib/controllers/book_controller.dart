import 'dart:convert';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';
import '../utils/constants.dart';

class BookController {
  final Box _bookBox = Hive.box('bookBox');
  final Box _logBox = Hive.box('logBox');

  // --- 1. PENCARIAN CANGGIH (Filter Judul, Penulis, dll) ---
  Future<List<dynamic>> searchBooksFromApi(String query, {String filterType = 'general'}) async {
    String q = query;
    // Google Books API Filters
    if (filterType == 'judul') q = 'intitle:$query';
    else if (filterType == 'penulis') q = 'inauthor:$query';
    else if (filterType == 'isbn') q = 'isbn:$query';
    else if (filterType == 'genre') q = 'subject:$query';

    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$q&key=$GOOGLE_BOOKS_API_KEY&maxResults=20');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] ?? [];
      }
      throw Exception("Gagal mengambil data buku.");
    } catch (e) {
      throw Exception("Pastikan perangkat terhubung ke internet.");
    }
  }

  // --- 2. FITUR REKOMENDASI & TRENDING ---
  // Jika belum cari apa-apa, tampilkan ini
  Future<List<dynamic>> getTrendingBooks() async {
    // Kita ambil buku-buku 'Fiction' terbaru sebagai default trending
    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=subject:fiction&orderBy=newest&key=$GOOGLE_BOOKS_API_KEY&maxResults=10');
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

  // Rekomendasi berdasarkan genre yang sering disimpan user
  Future<List<dynamic>> getRecommendations(String username) async {
    final userBooks = getUserBooks(username);
    if (userBooks.isEmpty) return getTrendingBooks();

    // Hitung genre terbanyak
    Map<String, int> genreCounts = {};
    for (var book in userBooks) {
      // Bersihkan string genre agar akurat
      String genre = book.category.split(' / ').first.trim(); 
      if (genre == 'N/A' || genre.isEmpty) continue;
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }

    if (genreCounts.isEmpty) return getTrendingBooks();

    // Ambil top genre
    String topGenre = genreCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Fetch API berdasarkan top genre
    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=subject:$topGenre&key=$GOOGLE_BOOKS_API_KEY&maxResults=5');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] ?? [];
      }
    } catch (_) {}
    
    return [];
  }

  // --- 3. CRUD BUKU ---
  Future<String?> saveBook(Map<String, dynamic> apiData, String username) async {
    final String id = apiData['id'];
    final String hiveKey = "${username}_$id";

    if (_bookBox.containsKey(hiveKey)) return "Buku ini sudah ada di koleksimu.";

    final vol = apiData['volumeInfo'];
    
    // Parsing Harga (Google Books kadang kasih, kadang tidak)
    double price = 0.0;
    String currency = 'IDR';
    if (apiData['saleInfo'] != null && apiData['saleInfo']['listPrice'] != null) {
       price = (apiData['saleInfo']['listPrice']['amount'] ?? 0).toDouble();
       currency = apiData['saleInfo']['listPrice']['currencyCode'] ?? 'IDR';
    }

    final book = Book(
      id: id,
      title: vol['title'] ?? 'Tanpa Judul',
      authors: (vol['authors'] as List?)?.join(', ') ?? 'N/A',
      coverUrl: vol['imageLinks']?['thumbnail'] ?? '',
      pageCount: vol['pageCount'] ?? 0,
      description: vol['description'] ?? 'Tidak ada deskripsi.',
      category: (vol['categories'] as List?)?.first ?? 'Umum',
      currentPage: 0,
      status: 'To Read',
      price: price, // Harga otomatis jika ada
      currency: currency,
      review: '',
      rating: 0,
      username: username,
    );

    await _bookBox.put(hiveKey, book.toMap());
    return null;
  }

  // Get Books dengan Filter Lokal (Genre & Status)
  List<Book> getUserBooks(String username, {String? filterGenre, String? filterStatus}) {
    var books = _bookBox.values
        .map((e) => Book.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .where((b) => b.username == username);

    if (filterGenre != null && filterGenre != 'Semua') {
      books = books.where((b) => b.category.contains(filterGenre));
    }
    
    if (filterStatus != null && filterStatus != 'Semua') {
      // Mapping status UI ke status Model
      // UI: 'Selesai', 'Sedang Baca', 'Belum Baca'
      // Model: 'Finished', 'Reading Now', 'To Read'
      String target = '';
      if (filterStatus == 'Selesai') target = 'Finished';
      else if (filterStatus == 'Sedang Baca') target = 'Reading Now';
      else if (filterStatus == 'Belum Baca') target = 'To Read';
      
      if (target.isNotEmpty) books = books.where((b) => b.status == target);
    }

    return books.toList().reversed.toList(); // Terbaru di atas
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
  
  // Update Manual Harga/Status dari Detail Page
  Future<void> updateBookDetails(String hiveKey, Book updatedBook) async {
    await _bookBox.put(hiveKey, updatedBook.toMap());
  }

  Future<void> deleteBook(String hiveKey, String bookId, String username) async {
    await _bookBox.delete(hiveKey);
    // Hapus Log
    final keysToDelete = _logBox.keys.where((k) {
      final l = Map<String, dynamic>.from(_logBox.get(k) as Map);
      return l['bookId'] == bookId && l['username'] == username;
    }).toList();
    await _logBox.deleteAll(keysToDelete);
  }
}