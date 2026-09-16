import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final SmartFileApi api;
  final ValueChanged<UserAccount> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController(text: 'user@filemind.ai');
  final _passwordController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController(text: 'Alex Morgan');
  final _serverUrlController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _showServerConfig = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = widget.api.baseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        throw ApiException('Please enter your email and password.');
      }

      UserAccount user;
      if (_isRegister) {
        final name = _nameController.text.trim();
        user = await widget.api.register(
          email: email,
          displayName: name.isNotEmpty ? name : email.split('@').first,
          password: password,
        );
      } else {
        user = await widget.api.login(email: email, password: password);
      }

      if (!mounted) return;
      widget.onAuthenticated(user);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Connection failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDemoMode() {
    final user = widget.api.startDemoSession();
    widget.onAuthenticated(user);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Header
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: AppColors.storageGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6046E8).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FileMind AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart file management powered by AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card container
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: outlineColor.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented tabs: Sign In vs Register
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2235)
                                : const Color(0xFFF1F3F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isRegister = false;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: !_isRegister
                                          ? (isDark
                                              ? const Color(0xFF282F46)
                                              : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: !_isRegister
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: !_isRegister
                                              ? const Color(0xFF6046E8)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isRegister = true;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _isRegister
                                          ? (isDark
                                              ? const Color(0xFF282F46)
                                              : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _isRegister
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _isRegister
                                              ? const Color(0xFF6046E8)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form fields
                        if (_isRegister) ...[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Display Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isRegister &&
                                    (_errorMessage!.contains('already exists') ||
                                        _errorMessage!.contains('taken') ||
                                        _errorMessage!.contains('409'))) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => setState(() {
                                      _isRegister = false;
                                      _errorMessage = null;
                                    }),
                                    icon: const Icon(Icons.login, size: 16),
                                    label: const Text('Switch to Sign In'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF6046E8),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Main Submit Button
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6046E8)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _isLoading ? null : _handleSubmit,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _isRegister
                                            ? 'Create Account'
                                            : 'Sign In',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Demo Mode Action
                        OutlinedButton.icon(
                          onPressed: _handleDemoMode,
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text('Explore Demo Mode (Instant)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6046E8),
                            side: const BorderSide(
                              color: Color(0xFF6046E8),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Backend Server Settings toggle
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showServerConfig = !_showServerConfig),
                    icon: Icon(
                      _showServerConfig
                          ? Icons.expand_less
                          : Icons.settings_ethernet,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _showServerConfig
                          ? 'Hide Server Settings'
                          : 'Server: ${widget.api.baseUrl}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  if (_showServerConfig) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: outlineColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _serverUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Backend Base URL',
                              hintText: 'http://127.0.0.1:4000',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Quick preset buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('127.0.0.1:4000 (ADB/USB)',
                                    style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  _serverUrlController.text =
                                      'http://127.0.0.1:4000';
                                },
                              ),
                              ActionChip(
                                label: const Text('192.168.1.158:4000 (Wi-Fi)',
                                    style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  _serverUrlController.text =
                                      'http://192.168.1.158:4000';
                                },
                              ),
                              ActionChip(
                                label: const Text('10.0.2.2:4000 (Emulator)',
                                    style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  _serverUrlController.text =
                                      'http://10.0.2.2:4000';
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final testUrl =
                                        _serverUrlController.text.trim();
                                    widget.api.baseUrl = testUrl;
                                    final ok = await widget.api.checkHealth();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Connected! Backend is healthy.'
                                                : 'Cannot reach $testUrl. Check that backend is running and adb reverse tcp:4000 tcp:4000 was executed.',
                                          ),
                                          backgroundColor: ok
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Test Connection'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      widget.api.baseUrl =
                                          _serverUrlController.text.trim();
                                      _showServerConfig = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Server URL set to ${widget.api.baseUrl}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Save URL'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
