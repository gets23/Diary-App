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
  
  // FITUR: Toggle Password
  bool _isObscure = true;
  bool _isLoading = false;

  void _register() async {
    setState(() => _isLoading = true);
    final email = _emailCtl.text.trim();
    final user = _userCtl.text.trim();
    final pass = _passCtl.text.trim();

    // FITUR: Validasi Lengkap (Standardisasi)
    if (email.isEmpty || user.isEmpty || pass.isEmpty) {
      _showSnack("Semua kolom wajib diisi!", errorRed);
      setState(() => _isLoading = false);
      return;
    }
    
    // Regex Email Sederhana
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnack("Format email tidak valid!", errorRed);
      setState(() => _isLoading = false);
      return;
    }

    // Min Password
    if (pass.length < 6) {
      _showSnack("Password minimal 6 karakter!", errorRed);
      setState(() => _isLoading = false);
      return;
    }

    final error = await _authController.register(email, user, pass);
    if (error == null) {
      if(mounted) {
        _showSnack("Registrasi Berhasil! Silakan Login", accentGreen);
        Navigator.pop(context);
      }
    } else {
      if(mounted) _showSnack(error, errorRed);
    }
    setState(() => _isLoading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
            decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
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
              // FITUR: Mata Password
              suffixIcon: IconButton(
                icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            )
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _register, 
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("DAFTAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}