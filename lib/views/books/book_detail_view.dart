import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/book_controller.dart';
import '../../controllers/log_controller.dart';
import '../../controllers/gamification_controller.dart';
import '../../utils/constants.dart';
import '../../models/log_model.dart'; // Import Model Log
import '../logs/log_entry_view.dart';

class BookDetailView extends StatefulWidget {
  final String hiveKey;
  const BookDetailView({super.key, required this.hiveKey});

  @override
  State<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends State<BookDetailView> {
  final _bookController = BookController();
  final _logController = LogController();
  final _gameController = GamificationController();
  
  String? _username;
  String _selectedCurrency = "IDR";
  String _selectedZone = "WIB";
  final Map<String, int> _timeOffset = {"WIB": 0, "WITA": 1, "WIT": 2, "London": -7};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _username = p.getString('loggedInUser')));
  }

  // --- LOGIC UI ---
  
  String _formatPrice(double price) {
    double finalPrice = price;
    String symbol = "Rp ";
    if (_selectedCurrency == 'USD') { finalPrice = price * 0.000061; symbol = "\$ "; }
    if (_selectedCurrency == 'EUR') { finalPrice = price * 0.000057; symbol = "€ "; }
    return NumberFormat.currency(locale: 'id_ID', symbol: symbol, decimalDigits: 2).format(finalPrice);
  }

  String _formatLogDate(DateTime dt) {
    final localized = dt.add(Duration(hours: _timeOffset[_selectedZone]!));
    // Format: Senin, 10 Okt 2025 • 14:30
    return "${DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID').format(localized)} ($_selectedZone)";
  }

  Future<void> _deleteBook(String bookId) async {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Hapus Buku?"),
      content: const Text("Data tidak bisa dikembalikan."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: errorRed),
          onPressed: () async {
            if (_username != null) {
              await _bookController.deleteBook(widget.hiveKey, bookId, _username!);
              if(mounted) {
                Navigator.pop(c); Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Terhapus"), backgroundColor: accentGreen));
              }
            }
          }, child: const Text("Hapus")
        )
      ],
    ));
  }

  Future<void> _review(int r, String rev) async {
    int rating = r == 0 ? 0 : r;
    final ctl = TextEditingController(text: rev);
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text("Review"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
          icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: accentYellow, size: 32),
          onPressed: () => setSt(() => rating = i + 1),
        ))),
        TextField(controller: ctl, decoration: const InputDecoration(hintText: "Tulis ulasan..."), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
        ElevatedButton(onPressed: () async {
          await _bookController.updateReview(widget.hiveKey, rating, ctl.text);
          if (rev.isEmpty && ctl.text.isNotEmpty && _username != null) {
             await _gameController.addXp(_username!, 50); // XP Review
          }
          if(mounted) { Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Disimpan!"), backgroundColor: accentGreen)); }
        }, child: const Text("Simpan"))
      ]
    )));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('bookBox').listenable(keys: [widget.hiveKey]),
      builder: (context, Box box, _) {
        final book = _bookController.getBook(widget.hiveKey);
        if (book == null) return const Scaffold(body: Center(child: Text("Buku dihapus")));

        return Scaffold(
          appBar: AppBar(
            title: Text(book.title),
            actions: [IconButton(icon: const Icon(Icons.delete, color: errorRed), onPressed: () => _deleteBook(book.id))],
          ),
          floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (book.status == 'Finished')
              FloatingActionButton.extended(heroTag: '1', backgroundColor: accentGreen, label: const Text("Review"), icon: const Icon(Icons.star), onPressed: () => _review(book.rating, book.review)),
            const SizedBox(height: 10),
            FloatingActionButton.extended(heroTag: '2', backgroundColor: accentYellow, label: const Text("Catat Log"), icon: const Icon(Icons.edit_note), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogEntryView(hiveKey: widget.hiveKey)))),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            // Header
            Row(children: [
              Hero(tag: book.id, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(book.coverUrl, width: 90, height: 130, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(width: 90, height: 130, color: Colors.grey)))), 
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Chip(label: Text(book.category, style: const TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: primaryPurple, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                Text(book.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(book.authors, style: const TextStyle(color: textSecondary)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: book.pageCount>0?book.currentPage/book.pageCount:0, color: accentYellow, backgroundColor: Colors.grey[200]),
                Text("${book.currentPage} / ${book.pageCount} Hal", style: const TextStyle(fontSize: 12)),
              ]))
            ]),
            const SizedBox(height: 20),
            
            // Harga & Konversi
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_formatPrice(book.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(value: _selectedCurrency, items: ['IDR', 'USD', 'EUR'].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>_selectedCurrency=v!), underline: Container())
            ]))),
            
            // Sinopsis Dropdown
            Card(child: ExpansionTile(title: const Text("Sinopsis", style: TextStyle(fontWeight: FontWeight.bold)), children: [Padding(padding: const EdgeInsets.all(16), child: Text(book.description.isNotEmpty ? book.description : "Tidak ada deskripsi", textAlign: TextAlign.justify))])),
            
            // Review User
            if(book.review.isNotEmpty) Card(color: accentYellow.withOpacity(0.1), child: ListTile(title: const Text("Review Kamu", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('"${book.review}"', style: const TextStyle(fontStyle: FontStyle.italic)), trailing: Row(mainAxisSize: MainAxisSize.min, children: List.generate(book.rating, (index) => const Icon(Icons.star, size: 16, color: Colors.orange))))),

            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Riwayat Baca", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(value: _selectedZone, items: _timeOffset.keys.map((k)=>DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v)=>setState(()=>_selectedZone=v!), underline: Container(), icon: const Icon(Icons.access_time))
            ]),
            
            // List Log
            ValueListenableBuilder(
              valueListenable: Hive.box('logBox').listenable(),
              builder: (ctx, _, __) {
                final logsData = _logController.getLogsWithKeys(book.id, book.username!);
                if (logsData.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Belum ada log.", style: TextStyle(color: Colors.grey))));
                
                return Column(children: logsData.map((item) {
                  final log = item['log'] as ReadingLog;
                  final key = item['key'] as int;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _logController.deleteLog(key))
                      ]),
                      Text(_formatLogDate(log.createdAt), style: const TextStyle(fontSize: 11, color: primaryPurple)),
                      const Divider(),
                      if (log.imagePath != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Image.file(File(log.imagePath!), height: 100, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox())),
                      Text("Halaman ${log.pageLogged}", style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                      if (log.notes.isNotEmpty) Text(log.notes, style: const TextStyle(color: textSecondary)),
                      if (log.address != null) Row(children: [const Icon(Icons.location_on, size: 12, color: textSecondary), Text(log.address!, style: const TextStyle(fontSize: 11, color: textSecondary))])
                    ])),
                  );
                }).toList());
              }
            ),
          ]),
        );
      },
    );
  }
}