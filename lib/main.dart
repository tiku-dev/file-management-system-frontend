import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'services/local_file_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFileApp());
}

class SmartFileApp extends StatefulWidget {
  const SmartFileApp({super.key});

  @override
  State<SmartFileApp> createState() => _SmartFileAppState();
}

class _SmartFileAppState extends State<SmartFileApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late final SmartFileApi _api;
  late final LocalFileService _fileService;
  UserAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _api = SmartFileApi();
    _fileService = LocalFileService();
  }

  void _handleAuthenticated(UserAccount user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _handleLogout() {
    setState(() {
      _api.logout();
      _currentUser = null;
    });
  }

  void _handleThemeModeChanged(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart File',
      themeMode: _themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _currentUser == null
          ? AuthScreen(
              api: _api,
              onAuthenticated: _handleAuthenticated,
            )
          : MainShell(
              api: _api,
              fileService: _fileService,
              isDark: isDark,
              onThemeModeChanged: _handleThemeModeChanged,
              onLogout: _handleLogout,
            ),
    );
  }
}
