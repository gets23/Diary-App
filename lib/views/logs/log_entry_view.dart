import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart'; // Wajib
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/book_controller.dart';
import '../../controllers/log_controller.dart';
import '../../controllers/gamification_controller.dart';
import '../../models/log_model.dart';
import '../../utils/constants.dart';

class LogEntryView extends StatefulWidget {
  final String hiveKey; 
  const LogEntryView({super.key, required this.hiveKey});

  @override
  State<LogEntryView> createState() => _LogEntryViewState();
}

class _LogEntryViewState extends State<LogEntryView> {
  // Controller Input
  final _titleController = TextEditingController(); // Judul Log
  final _pageController = TextEditingController();
  final _priceController = TextEditingController(); // Input Harga User
  final _notesController = TextEditingController();
  
  // Logic Controllers
  final _bookController = BookController();
  final _logController = LogController();
  final _gameController = GamificationController();
  
  // State Lokasi & Foto
  String _locationMessage = "Tambah Lokasi (LBS)";
  Position? _position;
  String? _address;
  String? _imagePath; // Path foto lokal
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill data jika ada
    final book = _bookController.getBook(widget.hiveKey);
    if (book != null) {
      _pageController.text = book.currentPage.toString();
      _priceController.text = book.price.toString();
      // Default judul log
      _titleController.text = "Bacaan Harian"; 
    }
  }

  // --- FITUR FOTO (KAMERA/GALERI) ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 50); // Compress dikit biar ringan
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar"), backgroundColor: errorRed));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Kamera"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("Galeri"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  // --- FITUR LOKASI ---
  Future<void> _getCurrentLocation() async {
    setState(() { _locationMessage = "Sedang mencari..."; });
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied) {
          setState(() => _locationMessage = "Izin ditolak");
          return;
        }
      }
      
      _position = await Geolocator.getCurrentPosition();
      try {
        List<Placemark> marks = await placemarkFromCoordinates(_position!.latitude, _position!.longitude);
        Placemark place = marks[0];
        _address = "${place.locality}, ${place.subAdministrativeArea}"; // Simpel aja
        setState(() => _locationMessage = _address!);
      } catch (_) {
        setState(() { _locationMessage = "Lokasi Tersemat"; _address = "${_position!.latitude}, ${_position!.longitude}"; });
      }
    } catch (_) {
      setState(() => _locationMessage = "Gagal GPS");
    }
  }

  Future<void> _save() async {
    // Validasi Judul & Halaman
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Judul log harus diisi!"), backgroundColor: errorRed));
      return;
    }
    if (_pageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Halaman tidak boleh kosong!"), backgroundColor: errorRed));
      return;
    }

    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('loggedInUser');
    final book = _bookController.getBook(widget.hiveKey);

    if (username != null && book != null) {
      final page = int.tryParse(_pageController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0.0;

      // Logic Halaman > Total
      if (page > book.pageCount && book.pageCount > 0) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Melebihi total halaman (${book.pageCount})"), backgroundColor: errorRed));
        setState(() => _isLoading = false);
        return;
      }

      // Buat Model Log Lengkap
      final log = ReadingLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // ID Unik
        bookId: book.id,
        title: _titleController.text, // Judul Baru

        createdAt: DateTime.now(), 
        pageLogged: page,
        notes: _notesController.text,
        imagePath: _imagePath, // Foto Baru
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        address: _address,
        username: username,
      );

      // Simpan
      await _logController.addLog(log, widget.hiveKey, price);

      // Proses Gamifikasi
      bool levelUp = await _gameController.processLogRewards(username, book, page);

      if (mounted) {
        if (levelUp) {
          final p = _gameController.getProfile(username);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("NAIK LEVEL ${p.level}!"), backgroundColor: accentYellow));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log tersimpan!"), backgroundColor: accentGreen));
        }
        Navigator.pop(context);
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Catat Progres")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Judul Log
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Judul Log (Misal: Bab 1)", prefixIcon: Icon(Icons.title)),
            ),
            const SizedBox(height: 16),

            // Foto Bukti (Opsional)
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  image: _imagePath != null 
                    ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                    : null
                ),
                child: _imagePath == null 
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: textSecondary, size: 40), Text("Tambah Foto (Opsional)", style: TextStyle(color: textSecondary))])
                  : null,
              ),
            ),
            const SizedBox(height: 16),

            // Card Input Angka
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(controller: _pageController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: "Halaman Terakhir", prefixIcon: Icon(Icons.menu_book))),
                  const SizedBox(height: 12),
                  TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Update Harga Buku", prefixIcon: Icon(Icons.monetization_on))),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Catatan
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Catatan / Review Singkat", alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),

            // Tombol LBS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _getCurrentLocation, 
                icon: Icon(_address != null ? Icons.check_circle : Icons.location_on, color: _address != null ? accentGreen : primaryPurple),
                label: Text(_locationMessage),
              ),
            ),
            const SizedBox(height: 30),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN LOG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}