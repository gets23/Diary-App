import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Tambahkan ini di pubspec.yaml jika belum: intl: ^0.18.0

import '../../controllers/book_controller.dart';
import '../../controllers/log_controller.dart';
import '../../controllers/gamification_controller.dart';
import '../../models/log_model.dart';
import '../../models/book_model.dart'; // Pastikan import ini ada
import '../../utils/constants.dart';

class LogEntryView extends StatefulWidget {
  final String hiveKey; 
  final ReadingLog? existingLog; // Parameter baru untuk mode Edit/View

  const LogEntryView({
    super.key, 
    required this.hiveKey, 
    this.existingLog
  });

  @override
  State<LogEntryView> createState() => _LogEntryViewState();
}

class _LogEntryViewState extends State<LogEntryView> {
  // Controller Input
  final _titleController = TextEditingController();
  final _pageController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Logic Controllers
  final _bookController = BookController();
  final _logController = LogController();
  final _gameController = GamificationController();
  
  // State
  String _locationMessage = "Tambah Lokasi (LBS)";
  Position? _position;
  String? _address;
  String? _imagePath;
  bool _isLoading = false;
  
  // State Mode (View/Edit)
  bool _isReadOnly = false;
  Book? _currentBook; // Simpan referensi buku

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    _currentBook = _bookController.getBook(widget.hiveKey);

    if (widget.existingLog != null) {
      // --- MODE VIEW/EDIT ---
      _isReadOnly = true; // Default terkunci
      final log = widget.existingLog!;
      
      _titleController.text = log.title;
      _pageController.text = log.pageLogged.toString();
      _notesController.text = log.notes;
      
      // Load Foto & Lokasi Lama
      _imagePath = log.imagePath;
      if (log.address != null) {
        _address = log.address;
        _locationMessage = log.address!;
        if (log.latitude != null && log.longitude != null) {
          _position = Position(
            longitude: log.longitude!, latitude: log.latitude!, 
            timestamp: DateTime.now(), accuracy: 0, altitude: 0, 
            heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0
          );
        }
      }
      
      // Harga ambil dari buku (karena log tidak simpan harga, hanya trigger update)
      if (_currentBook != null) {
        _priceController.text = _currentBook!.price.toString();
      }

    } else {
      // --- MODE INPUT BARU ---
      _isReadOnly = false;
      if (_currentBook != null) {
        _pageController.text = _currentBook!.currentPage.toString();
        _priceController.text = _currentBook!.price.toString();
        _titleController.text = "Bacaan Harian"; 
      }
    }
  }

  // --- FITUR FOTO ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isReadOnly) return; // Cegah ganti foto saat mode baca
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar"), backgroundColor: errorRed));
    }
  }

  void _showImageSourceDialog() {
    if (_isReadOnly) return;
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
    if (_isReadOnly) return;
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
        _address = "${place.locality}, ${place.subAdministrativeArea}";
        setState(() => _locationMessage = _address!);
      } catch (_) {
        setState(() { _locationMessage = "Lokasi Tersemat"; _address = "${_position!.latitude}, ${_position!.longitude}"; });
      }
    } catch (_) {
      setState(() => _locationMessage = "Gagal GPS");
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty || _pageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Judul & Halaman wajib diisi!"), backgroundColor: errorRed));
      return;
    }

    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('loggedInUser');
    
    // Refresh data buku terbaru sebelum simpan
    final book = _bookController.getBook(widget.hiveKey);

    if (username != null && book != null) {
      final page = int.tryParse(_pageController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0.0;

      // Logic Validasi Halaman
      if (page > book.pageCount && book.pageCount > 0) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Melebihi total halaman (${book.pageCount})"), backgroundColor: errorRed));
        setState(() => _isLoading = false);
        return;
      }

      // Tentukan ID: Pakai ID lama jika edit, buat baru jika new
      final String logId = widget.existingLog?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final DateTime dateCreated = widget.existingLog?.createdAt ?? DateTime.now();

      final log = ReadingLog(
        id: logId,
        bookId: book.id,
        title: _titleController.text,
        createdAt: dateCreated, 
        pageLogged: page,
        notes: _notesController.text,
        imagePath: _imagePath,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        address: _address,
        username: username,
      );

      if (widget.existingLog != null) {
        // --- LOGIC UPDATE ---
        // Catatan: Pastikan LogController punya method updateLog, atau gunakan addLog jika logicnya replace
        await _logController.updateLog(log, widget.hiveKey); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log diperbarui!"), backgroundColor: accentGreen));
      } else {
        // --- LOGIC CREATE BARU ---
        await _logController.addLog(log, widget.hiveKey, price);
        
        // Gamification hanya jalan saat log BARU dibuat
        bool levelUp = await _gameController.processLogRewards(username, book, page);
        if (mounted) {
           if (levelUp) {
            final p = _gameController.getProfile(username);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("NAIK LEVEL ${p.level}!"), backgroundColor: accentYellow));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log tersimpan!"), backgroundColor: accentGreen));
          }
        }
      }
      
      if(mounted) Navigator.pop(context);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Format tanggal cantik jika ada log lama
    String dateString = "";
    if (widget.existingLog != null) {
      dateString = DateFormat('dd MMM yyyy, HH:mm').format(widget.existingLog!.createdAt);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLog != null ? "Detail Log" : "Catat Progres"),
        actions: [
          // Tombol Edit hanya muncul jika sedang melihat log lama & masih dalam mode read-only
          if (widget.existingLog != null && _isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: "Edit Log",
              onPressed: () {
                setState(() {
                  _isReadOnly = false; // Buka kunci
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Edit Aktif"), duration: Duration(seconds: 1)));
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Tanggal (Hanya saat View/Edit)
            if (widget.existingLog != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Dibuat pada: $dateString", style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ]),
              ),

            // Input Judul Log
            TextField(
              controller: _titleController,
              readOnly: _isReadOnly,
              decoration: InputDecoration(
                labelText: "Judul Log (Misal: Bab 1)", 
                prefixIcon: const Icon(Icons.title),
                filled: _isReadOnly,
                fillColor: _isReadOnly ? Colors.grey[200] : null,
              ),
            ),
            const SizedBox(height: 16),

            // Foto Bukti
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
                  : (_isReadOnly ? null : Container( // Overlay edit icon jika ada foto & mode edit
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.all(8),
                      child: const CircleAvatar(backgroundColor: Colors.white, radius: 15, child: Icon(Icons.edit, size: 15, color: primaryPurple)),
                    )),
              ),
            ),
            const SizedBox(height: 16),

            // Card Input Angka
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: _pageController, 
                    readOnly: _isReadOnly,
                    keyboardType: TextInputType.number, 
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
                    decoration: const InputDecoration(labelText: "Halaman Terakhir", prefixIcon: Icon(Icons.menu_book)),
                  ),
                  // Indikator Max Halaman
                  if (_currentBook != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Text(
                          "Maksimal: ${_currentBook!.pageCount > 0 ? _currentBook!.pageCount : '-'} halaman",
                          style: TextStyle(fontSize: 12, color: (_currentBook!.pageCount > 0) ? Colors.grey[600] : Colors.transparent),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Harga hanya bisa diedit saat log baru (biasanya), tapi kita buka aja opsinya
                  TextField(
                    controller: _priceController, 
                    readOnly: _isReadOnly,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                    decoration: const InputDecoration(labelText: "Update Harga Buku", prefixIcon: Icon(Icons.monetization_on))
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Catatan
            TextField(
              controller: _notesController,
              readOnly: _isReadOnly,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Catatan / Review Singkat", alignLabelWithHint: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Tombol LBS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _getCurrentLocation, 
                icon: Icon(_address != null ? Icons.check_circle : Icons.location_on, color: (_isReadOnly) ? Colors.grey : (_address != null ? accentGreen : primaryPurple)),
                label: Text(_locationMessage),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isReadOnly ? Colors.grey : primaryPurple
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Tombol Simpan (Hanya muncul jika TIDAK read only)
            if (!_isReadOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(widget.existingLog != null ? "PERBARUI LOG" : "SIMPAN LOG", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}