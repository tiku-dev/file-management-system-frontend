import 'package:flutter/material.dart';

import '../services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.isDark,
    required this.onThemeModeChanged,
    required this.onLogout,
  });

  final SmartFileApi api;
  final bool isDark;
  final ValueChanged<bool> onThemeModeChanged;
  final VoidCallback onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _onDeviceMode = false;
  bool _autoOrganize = true;
  bool _autoDeleteDuplicates = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top App Bar
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 24),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Settings Sections
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // User Profile banner
                  _buildUserCard(isDark, cardColor, outlineColor),
                  const SizedBox(height: 24),

                  // Section 1: AI & Privacy
                  _buildSectionTitle('AI & Privacy', isDark),
                  const SizedBox(height: 10),
                  _buildSettingsContainer(
                    cardColor,
                    outlineColor,
                    isDark,
                    [
                      _buildSwitchTile(
                        icon: Icons.lock_outline_rounded,
                        iconBg: const Color(0xFF6046E8).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF6046E8),
                        title: 'On-device mode',
                        subtitle: 'AI runs locally, nothing leaves your phone',
                        value: _onDeviceMode,
                        onChanged: (val) => setState(() => _onDeviceMode = val),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildNavTile(
                        icon: Icons.psychology_outlined,
                        iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF10B981),
                        title: 'AI model',
                        subtitle: 'Groq LLaMA 3.3 70B (Versatile)',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Groq LLaMA 3.3 70B Versatile is active'),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildNavTile(
                        icon: Icons.folder_shared_outlined,
                        iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Allowed paths',
                        subtitle: 'Documents · Downloads · DCIM',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Allowed paths: Documents, Downloads, DCIM'),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Automation
                  _buildSectionTitle('Automation', isDark),
                  const SizedBox(height: 10),
                  _buildSettingsContainer(
                    cardColor,
                    outlineColor,
                    isDark,
                    [
                      _buildSwitchTile(
                        icon: Icons.schedule_outlined,
                        iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Auto-organize weekly',
                        subtitle: 'Every Sunday at 9 PM',
                        value: _autoOrganize,
                        onChanged: (val) => setState(() => _autoOrganize = val),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSwitchTile(
                        icon: Icons.auto_delete_outlined,
                        iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF10B981),
                        title: 'Auto-delete duplicates',
                        subtitle: 'Confirm before deletion',
                        value: _autoDeleteDuplicates,
                        onChanged: (val) =>
                            setState(() => _autoDeleteDuplicates = val),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3: General & Appearance
                  _buildSectionTitle('General', isDark),
                  const SizedBox(height: 10),
                  _buildSettingsContainer(
                    cardColor,
                    outlineColor,
                    isDark,
                    [
                      _buildSwitchTile(
                        icon: isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Appearance',
                        subtitle: isDark ? 'Dark Mode (Active)' : 'Light Mode (Active)',
                        value: isDark,
                        onChanged: widget.onThemeModeChanged,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildNavTile(
                        icon: Icons.dns_outlined,
                        iconBg: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF06B6D4),
                        title: 'Backend Server',
                        subtitle: widget.api.baseUrl,
                        onTap: () {
                          _showEditServerDialog(context);
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Logout button
                  FilledButton.tonalIcon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(bool isDark, Color cardColor, Color outlineColor) {
    final user = widget.api.currentUser;
    final name = user?.displayName ?? 'User';
    final email = user?.email ?? 'user@filemind.ai';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF6046E8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : const Color(0xFF374151),
      ),
    );
  }

  Widget _buildSettingsContainer(
    Color cardColor,
    Color outlineColor,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF6046E8),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF22283A) : const Color(0xFFF3F4F6),
    );
  }

  void _showEditServerDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.api.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'http://127.0.0.1:4000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                widget.api.baseUrl = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
