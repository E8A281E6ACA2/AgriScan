import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/result_page.dart';
import 'pages/history_page.dart';
import 'pages/gallery_page.dart';
import 'pages/notes_page.dart';
import 'pages/admin_page.dart';
import 'services/api_service.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = _generateDeviceId();
    await prefs.setString('device_id', deviceId);
  }
  final token = prefs.getString('auth_token');
  runApp(AgriScanApp(deviceId: deviceId, authToken: token));
}

class AgriScanApp extends StatelessWidget {
  final String deviceId;
  final String? authToken;

  const AgriScanApp({
    super.key,
    required this.deviceId,
    required this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        Provider(
          create: (_) {
            final api = ApiService();
            api.setDeviceId(deviceId);
            if (authToken != null && authToken!.isNotEmpty) {
              api.setAuthToken(authToken);
            }
            return api;
          },
        ),
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
          '/notes': (context) => const NotesPage(),
          '/admin': (context) => const AdminPage(),
        },
      ),
    );
  }
}

String _generateDeviceId() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
