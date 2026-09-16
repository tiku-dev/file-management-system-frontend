import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/local_file_service.dart';
import 'ai_assistant_screen.dart';
import 'browse_screen.dart';
import 'file_list_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.fileService,
    required this.isDark,
    required this.onThemeModeChanged,
    required this.onLogout,
  });

  final SmartFileApi api;
  final LocalFileService fileService;
  final bool isDark;
  final ValueChanged<bool> onThemeModeChanged;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _activeSearchQuery = 'tax 2024';
  FileCategory? _selectedCategory;

  void _navigateToTab(int index) {
    setState(() {
      _selectedCategory = null;
      _currentIndex = index;
    });
  }

  void _handleOpenSearch([String query = 'tax 2024']) {
    setState(() {
      _activeSearchQuery = query;
      _selectedCategory = null;
      _currentIndex = 3; // Search tab
    });
  }

  void _handleSelectCategory(FileCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    final isDark = widget.isDark;

    Widget currentBody;
    if (_selectedCategory != null) {
      currentBody = FileListScreen(
        fileService: widget.fileService,
        category: _selectedCategory!,
        onBack: () => setState(() => _selectedCategory = null),
      );
    } else {
      switch (_currentIndex) {
        case 0:
          currentBody = HomeScreen(
            fileService: widget.fileService,
            onOpenSearch: () => _handleOpenSearch(''),
            onOpenAiAssistant: () => _navigateToTab(2),
            onOpenBrowse: () => _navigateToTab(1),
            onFileTap: (file) => _handleSelectCategory(file.category),
          );
          break;
        case 1:
          currentBody = BrowseScreen(
            fileService: widget.fileService,
            onSelectCategory: _handleSelectCategory,
            onOpenSearch: _handleOpenSearch,
          );
          break;
        case 2:
          currentBody = AiAssistantScreen(
            api: widget.api,
            fileService: widget.fileService,
          );
          break;
        case 3:
          currentBody = SearchScreen(
            fileService: widget.fileService,
            initialQuery: _activeSearchQuery,
          );
          break;
        case 4:
          currentBody = SettingsScreen(
            api: widget.api,
            isDark: isDark,
            onThemeModeChanged: widget.onThemeModeChanged,
            onLogout: widget.onLogout,
          );
          break;
        default:
          currentBody = const SizedBox.shrink();
      }
    }

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _navigateToTab,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF6046E8),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: Text('Browse'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: Text('AI Chat'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: currentBody),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: currentBody,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        height: 68,
        elevation: 2,
        indicatorColor: const Color(0xFF6046E8).withValues(alpha: 0.14),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF6046E8)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: Color(0xFF6046E8)),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFF6046E8)),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: Color(0xFF6046E8)),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF6046E8)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
