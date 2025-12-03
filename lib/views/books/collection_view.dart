import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/book_controller.dart';
import '../../utils/constants.dart';
import 'book_detail_view.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({super.key});
  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  String? _username;
  final BookController _bookController = BookController();
  
  // Filter States
  String _selectedStatus = 'Semua';
  final List<String> _statusOptions = ['Semua', 'Sedang Baca', 'Selesai', 'Belum Baca'];
  
  // Untuk genre bisa dikembangkan dinamis, tapi kita pakai statis dulu biar simple
  String _selectedGenreFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _username = p.getString('loggedInUser')));
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Koleksiku"), automaticallyImplyLeading: false),
      body: Column(
        children: [
          // --- FILTER AREA ---
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statusOptions.map((status) {
                final bool isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: primaryPurple,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    backgroundColor: Colors.white,
                    onSelected: (val) {
                      if (val) setState(() => _selectedStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // --- LIST BUKU ---
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('bookBox').listenable(),
              builder: (context, Box box, _) {
                // Panggil Controller dengan Filter
                final userBooks = _bookController.getUserBooks(
                  _username!, 
                  filterStatus: _selectedStatus // Logic filter sudah ada di controller fase 2
                );

                if (userBooks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("Tidak ada buku dengan status '$_selectedStatus'.", style: const TextStyle(color: textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: userBooks.length,
                  itemBuilder: (context, index) {
                    final book = userBooks[index];
                    final hiveKey = "${book.username}_${book.id}";
                    final progress = (book.pageCount > 0) ? (book.currentPage / book.pageCount) : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailView(hiveKey: hiveKey))),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: book.coverUrl.isNotEmpty ? Image.network(book.coverUrl, width: 60, height: 90, fit: BoxFit.cover) : Container(width: 60, height: 90, color: Colors.grey[200], child: const Icon(Icons.book))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(book.authors, maxLines: 1, style: const TextStyle(color: textSecondary, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(value: progress, minHeight: 6, color: accentYellow, backgroundColor: accentYellow.withOpacity(0.1)),
                                  const SizedBox(height: 4),
                                  Text("${book.currentPage} / ${book.pageCount} Hal • ${book.status}", style: const TextStyle(fontSize: 11, color: textSecondary)),
                                ]),
                              ),
                              const Icon(Icons.chevron_right, color: textSecondary)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}