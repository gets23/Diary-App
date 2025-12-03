// lib/models/book_model.dart
class Book {
  final String id;
  final String title;
  final String authors;
  final String coverUrl;
  final int pageCount;
  final String description;
  final String category; // Ini Genre
  int currentPage;
  String status; // 'To Read', 'Reading', 'Finished'
  
  // Harga (User Input)
  double price;
  String currency; // 'IDR', 'USD', 'EUR'
  
  String review;
  int rating;
  final String username;

  Book({
    required this.id,
    required this.title,
    required this.authors,
    required this.coverUrl,
    required this.pageCount,
    required this.description,
    required this.category,
    required this.currentPage,
    required this.status,
    required this.price,
    this.currency = 'IDR', // Default IDR
    required this.review,
    required this.rating,
    required this.username,
  });

  factory Book.fromMap(Map<dynamic, dynamic> map) {
    return Book(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Tanpa Judul',
      authors: map['authors'] ?? 'Unknown',
      coverUrl: map['coverUrl'] ?? '',
      pageCount: map['pageCount'] ?? 0,
      description: map['description'] ?? '',
      category: map['category'] ?? 'Umum',
      currentPage: map['currentPage'] ?? 0,
      status: map['status'] ?? 'To Read',
      price: (map['price'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'IDR',
      review: map['review'] ?? '',
      rating: map['rating'] ?? 0,
      username: map['username'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'pageCount': pageCount,
      'description': description,
      'category': category,
      'currentPage': currentPage,
      'status': status,
      'price': price,
      'currency': currency,
      'review': review,
      'rating': rating,
      'username': username,
    };
  }
}