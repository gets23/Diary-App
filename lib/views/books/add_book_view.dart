import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/book_controller.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';

class AddBookView extends StatefulWidget {
  const AddBookView({super.key});
  @override
  State<AddBookView> createState() => _AddBookViewState();
}

class _AddBookViewState extends State<AddBookView> {
  final _searchCtl = TextEditingController();
  final _bookController = BookController();
  final _notifService = NotificationService(); 
  
  List<dynamic> _results = [];
  bool _isLoading = false;
  String? _username;
  
  // Filter Chips
  final List<String> _filters = ['Judul', 'Penulis', 'ISBN', 'Genre'];
  String _selectedFilter = 'Judul';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _username = p.getString('loggedInUser')));
    _notifService.init(); 
    _loadTrending(); 
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final data = await _bookController.getTrendingBooks();
      if (mounted) setState(() => _results = data);
    } catch (_) {} 
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    if (_searchCtl.text.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() { _isLoading = true; _results = []; });
    try {
      String type = 'general';
      if (_selectedFilter == 'Judul') type = 'judul';
      else if (_selectedFilter == 'Penulis') type = 'penulis';
      else if (_selectedFilter == 'ISBN') type = 'isbn';
      else if (_selectedFilter == 'Genre') type = 'genre';

      final res = await _bookController.searchBooksFromApi(_searchCtl.text, filterType: type);
      if (mounted) setState(() => _results = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mencari buku."), backgroundColor: errorRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBookDetailSheet(dynamic book) {
    final info = book['volumeInfo'];
    final title = info['title'] ?? 'Tanpa Judul';
    final desc = info['description'] ?? 'Tidak ada sinopsis.';
    final authors = (info['authors'] as List?)?.join(', ') ?? 'Penulis Tidak Diketahui';
    final img = info['imageLinks']?['thumbnail'] ?? '';
    final genre = (info['categories'] as List?)?.first ?? 'Umum';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: img.isNotEmpty ? Image.network(img, width: 100, height: 150, fit: BoxFit.cover) : Container(width: 100, height: 150, color: Colors.grey[300], child: const Icon(Icons.book, size: 40))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(genre, style: const TextStyle(fontSize: 10, color: primaryPurple, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(authors, style: const TextStyle(color: textSecondary)),
                  ]))
                ],
              ),
              const SizedBox(height: 24),
              const Text("Sinopsis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(color: textPrimary, height: 1.6), textAlign: TextAlign.justify),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: accentGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () { Navigator.pop(context); _save(book); },
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text("TAMBAH KE KOLEKSI", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(dynamic bookData) async {
    if (_username == null) return;
    
    final err = await _bookController.saveBook(bookData, _username!);
    
    if (err == null) {
      final title = bookData['volumeInfo']['title'];
      
      // 1. SnackBar DULUAN (Instant Feedback)
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil masuk koleksi!"), backgroundColor: accentGreen));

      // 2. Trigger Notifikasi (Dengan Delay 3 Detik)
      try {
        await _notifService.requestPermissions(); 
        // Jangan pakai await di sini biar UI thread gak kaku nungguin 3 detik
        _notifService.showNotificationNow(
          title: "Buku Ditambahkan", 
          body: "Buku '$title' masuk koleksi. Selamat membaca!", 
          notificationId: DateTime.now().millisecond,
          delaySeconds: 3 // Nah ini dia request-nya!
        );
      } catch (_) {} 

    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: accentYellow));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cari Buku"), automaticallyImplyLeading: false, elevation: 0),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: scaffoldBg,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: "Cari judul, penulis, ISBN...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded, color: primaryPurple)),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: _selectedFilter == f,
                        selectedColor: primaryPurple.withOpacity(0.2),
                        checkmarkColor: primaryPurple,
                        backgroundColor: Colors.white,
                        onSelected: (val) { if(val) { setState(() => _selectedFilter = f); if (_searchCtl.text.isNotEmpty) _search(); } },
                      ),
                    )).toList(),
                  ),
                )
              ],
            ),
          ),
          if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_results.isEmpty) const Expanded(child: Center(child: Text("Tidak ada hasil.", style: TextStyle(color: textSecondary))))
          else Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final book = _results[index];
                  final info = book['volumeInfo'];
                  final title = info['title'] ?? 'Tanpa Judul';
                  final author = (info['authors'] as List?)?.join(', ') ?? '-';
                  final genre = (info['categories'] as List?)?.first ?? 'Umum';
                  final img = info['imageLinks']?['thumbnail'] ?? '';

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showBookDetailSheet(book),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: img.isNotEmpty ? Image.network(img, width: 60, height: 90, fit: BoxFit.cover) : Container(width: 60, height: 90, color: Colors.grey[300], child: const Icon(Icons.book))),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(genre.toUpperCase(), style: const TextStyle(fontSize: 10, color: accentYellow, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textSecondary, fontSize: 12)),
                                  ])),
                                ]),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: primaryPurple, size: 28),
                            tooltip: "Tambah ke Koleksi",
                            onPressed: () => _save(book),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}