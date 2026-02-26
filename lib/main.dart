import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart'; // untuk kReleaseMode
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

import 'ui/splash_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // mati otomatis saat build release
      defaultDevice: Devices.ios.iPhone11ProMax,
      devices: [
        Devices.ios.iPhone11ProMax,
      ],
      builder: (context) => const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Integrasi Device Preview (wajib ketiga baris ini)
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      debugShowCheckedModeBanner: false,
      title: 'AI Schedule Generator',

      // Tema global menggunakan Material 3 dan Plus Jakarta Sans
      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF), // Vibrant purple/indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA), // Soft light gray
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Default transparan untuk menyatu dengan background custom
          elevation: 0,
          centerTitle: true,
        ),
      ),

      home: const SplashScreen(), // Halaman pertama saat aplikasi dibuka
    );
  }
}