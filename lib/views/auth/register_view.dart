import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/constants.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _authController = AuthController();
  
  bool _isObscure = true;
  bool _isLoading = false;

  void _register() async {
    // Tutup keyboard biar enak dilihat
    FocusScope.of(context).unfocus();

    final email = _emailCtl.text.trim();
    final user = _userCtl.text.trim();
    final pass = _passCtl.text; // Password jangan di-trim dulu untuk pengecekan spasi

    // 1. Validasi Kolom Kosong
    if (email.isEmpty || user.isEmpty || pass.isEmpty) {
      _showSnack("Semua kolom wajib diisi!", errorRed);
      return;
    }
    
    // 2. Validasi Format Email (Regex)
    // Penjelasan Regex: Harus ada teks + @ + teks + . + ekstensi (2-4 huruf)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnack("Format email tidak valid (contoh: user@mail.com)", errorRed);
      return;
    }

    // 3. Validasi Username
    if (user.length < 3) {
      _showSnack("Username minimal 3 karakter!", errorRed);
      return;
    }

    // 4. Validasi Password (Panjang & Spasi)
    if (pass.length < 6) {
      _showSnack("Password minimal 6 karakter!", errorRed);
      return;
    }
    if (pass.contains(' ')) {
      _showSnack("Password tidak boleh mengandung spasi!", errorRed);
      return;
    }

    setState(() => _isLoading = true);

    // Proses Register ke Controller
    final error = await _authController.register(email, user, pass);
    
    setState(() => _isLoading = false);

    if (error == null) {
      if(mounted) {
        _showSnack("Registrasi Berhasil! Silakan Login", accentGreen);
        Navigator.pop(context); // Kembali ke halaman Login
      }
    } else {
      if(mounted) _showSnack(error, errorRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.person_add_rounded, size: 80, color: primaryPurple),
          const SizedBox(height: 32),
          
          TextField(
            controller: _emailCtl, 
            decoration: const InputDecoration(
              labelText: "Email", 
              prefixIcon: Icon(Icons.email_outlined),
              hintText: "contoh@email.com"
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _userCtl, 
            decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _passCtl, 
            obscureText: _isObscure, 
            decoration: InputDecoration(
              labelText: "Password", 
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
              helperText: "Minimal 6 karakter, tanpa spasi"
            )
          ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: _isLoading ? null : _register, 
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primaryPurple
            ),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("DAFTAR SEKARANG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}