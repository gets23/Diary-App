import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/date_symbol_data_local.dart'; // Tambahkan intl
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'views/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService().init();
  await initializeDateFormatting('id_ID', null); // Format tanggal Indo
  tz.initializeTimeZones();

  await Hive.initFlutter();
  await Hive.openBox('userBox');
  await Hive.openBox('bookBox');
  await Hive.openBox('logBox');
  await Hive.openBox('profileBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: scaffoldBg,
        primaryColor: primaryPurple,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: scaffoldBg,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBg,
          hintStyle: const TextStyle(color: textSecondary),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryPurple, width: 2)),
        ),
        // SNACKBAR JELEK SUDAH DIPERBAIKI KE STYLE ASLI
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.all(16),
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          color: cardBg,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const SplashView(),
    );
  }
}