import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/gamification_controller.dart';
import '../../utils/constants.dart';
import '../home_view.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _authController = AuthController();
  final _gameController = GamificationController(); // Untuk trigger streak
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    final success = await _authController.login(_userController.text, _passController.text);
    
    if (success) {
      await _gameController.updateStreak(_userController.text); // Hitung streak saat login
      if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeView()));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login Gagal"), backgroundColor: errorRed));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book_rounded, size: 80, color: primaryPurple),
            const SizedBox(height: 32),
            TextField(controller: _userController, decoration: const InputDecoration(labelText: "Username")),
            const SizedBox(height: 16),
            TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _isLoading ? null : _login, child: const Text("LOGIN")),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterView())), 
              child: const Text("Belum punya akun? Daftar")
            )
          ],
        ),
      ),
    );
  }
}