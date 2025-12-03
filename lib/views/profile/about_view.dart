import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tentang Kami")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: primaryPurple.withOpacity(0.1)),
                    child: const Icon(Icons.menu_book_rounded, size: 60, color: primaryPurple),
                  ),
                  const SizedBox(height: 16),
                  const Text("DIARY APP", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                  const Text("Versi 1.0.0 (Beta)", style: TextStyle(color: textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _section("Deskripsi", "Aplikasi jurnal membaca harian yang dirancang untuk membantu Anda melacak progres bacaan, mencapai target literasi, dan mengelola koleksi buku pribadi dengan fitur gamifikasi yang menyenangkan."),
            _section("Pengembang", "Dikembangkan oleh:\nSania Dinara Safina (124230020)\nPAM SI-D\n\nUntuk memenuhi Tugas Akhir Mata Kuliah Pemrograman Aplikasi Mobile."),
            _section("Fitur Unggulan", "• Tracking Lokasi (LBS)\n• Gamifikasi (XP, Level, Badge)\n• Notifikasi Pengingat\n• Integrasi Google Books API"),
            const SizedBox(height: 40),
            const Center(child: Text("© 2025 Diary Team", style: TextStyle(color: textSecondary, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5, color: textPrimary)),
        ],
      ),
    );
  }
}