import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/result_page.dart';
import 'pages/history_page.dart';
import 'pages/gallery_page.dart';
import 'services/api_service.dart';
import 'providers/app_provider.dart';

void main() {
  runApp(const AgriScanApp());
}

class AgriScanApp extends StatelessWidget {
  const AgriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'AgriScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // 农业绿色
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const HomePage(),
        routes: {
          '/camera': (context) => const CameraPage(),
          '/gallery': (context) => const GalleryPage(),
          '/result': (context) => const ResultPage(),
          '/history': (context) => const HistoryPage(),
        },
      ),
    );
  }
}
