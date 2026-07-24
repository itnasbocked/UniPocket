import 'dart:io';
import 'package:dm/data/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dm/theme/app_colors.dart';

import 'package:dm/ui/auth_page.dart';
import 'package:dm/ui/main_screen.dart';
import 'logic/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Comenté el await para evitar cuello de botella al iniciar la app
  // await DatabaseHelper.instance.database;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

  final notiService = NotificationService();
  await notiService.init();
  await notiService.requestPermission();

  final prefs = await SharedPreferences.getInstance();
  final bool sesionActiva = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(sesionActiva: sesionActiva));
}

class MyApp extends StatelessWidget {
  final bool sesionActiva;
  const MyApp({super.key, required this.sesionActiva});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniPocket',
      theme: ThemeData(scaffoldBackgroundColor: AppColors.fondo,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primario,
        surface: AppColors.fondo,
        error: Colors.redAccent
      ), 
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: AppColors.textoMuted),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primario, width: 2)
        ),
      )
      ),
      home: FutureBuilder<int?>(
      future: _obtenerSesionRecurrente(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        } else {
          return const AuthPage();
          }
      },),
    );
  }

  Future<int?> _obtenerSesionRecurrente() async {
    final prefs = await SharedPreferences.getInstance();
    int? id = prefs.getInt('userId');
    DatabaseHelper.instance.userId = id;
    return id;
  }
}