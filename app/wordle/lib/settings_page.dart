import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wordle/service/secure_storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SecureStorageService _storage = SecureStorageService();
  final _formKey = GlobalKey<FormState>();

  final _urlController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingConnectivity = false;
  String? _connectivityStatus;
  Color _connectivityColor = Colors.grey;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkIfConfigured();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkIfConfigured() async {
    final hasSettings = await _storage.hasSettings();
    if (hasSettings && mounted) {
      // Already configured — show password gate
      setState(() => _isLoading = false);
      _showPasswordGate();
    } else {
      // First time — go straight to form
      setState(() {
        _isLoading = false;
        _authenticated = true;
      });
    }
  }

  void _showPasswordGate() {
    final gateController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.teal[400]),
                  const SizedBox(width: 8),
                  const Text('Authentication'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your password to access settings.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gateController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(); // go back to home
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final saved = await _storage.getPassword();
                    if (gateController.text == saved) {
                      Navigator.of(ctx).pop();
                      final url = await _storage.getServerUrl();
                      setState(() {
                        _authenticated = true;
                        _urlController.text = url ?? '';
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Incorrect password'),
                          backgroundColor: Colors.red[400],
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkConnectivity() async {
    setState(() {
      _isCheckingConnectivity = true;
      _connectivityStatus = null;
    });

    try {
      // Step 1: Check network interface
      final result = await Connectivity().checkConnectivity();
      final hasNetwork = result.any((r) => r != ConnectivityResult.none);

      if (!hasNetwork) {
        setState(() {
          _connectivityStatus = 'No network connection';
          _connectivityColor = Colors.red;
          _isCheckingConnectivity = false;
        });
        return;
      }

      // Step 2: Try to reach the server URL
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _connectivityStatus = 'Network available, but no URL entered';
          _connectivityColor = Colors.orange;
          _isCheckingConnectivity = false;
        });
        return;
      }

      // Parse the URL and try a raw socket connection
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 80;

      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
        socket.destroy();
        setState(() {
          _connectivityStatus = 'Connected to $host:$port';
          _connectivityColor = Colors.green;
        });
      } catch (_) {
        setState(() {
          _connectivityStatus = 'Server unreachable at $host:$port';
          _connectivityColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _connectivityStatus = 'Error: ${e.toString()}';
        _connectivityColor = Colors.red;
      });
    } finally {
      setState(() => _isCheckingConnectivity = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    await _storage.saveServerUrl(_urlController.text.trim());
    await _storage.savePassword(_passwordController.text);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = Theme.of(context).brightness;
    final isDark = mode == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Awaiting authentication...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Server URL Section ---
              _buildSectionCard(
                isDark: isDark,
                icon: Icons.dns_outlined,
                title: 'Server Configuration',
                color: Colors.indigo,
                children: [
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'ws://192.168.1.100:22533',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter a server URL';
                      final uri = Uri.tryParse(val.trim());
                      if (uri == null || !uri.hasScheme) return 'Enter a valid URL (e.g. ws://host:port)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Connectivity check
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _isCheckingConnectivity
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_find),
                      label: Text(_isCheckingConnectivity ? 'Checking...' : 'Check Connectivity'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.indigo.withOpacity(0.5)),
                      ),
                      onPressed: _isCheckingConnectivity ? null : _checkConnectivity,
                    ),
                  ),
                  if (_connectivityStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: _connectivityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _connectivityColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectivityColor == Colors.green ? Icons.check_circle : Icons.error_outline,
                            color: _connectivityColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _connectivityStatus!,
                              style: TextStyle(color: _connectivityColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // --- Password Section ---
              _buildSectionCard(
                isDark: isDark,
                icon: Icons.shield_outlined,
                title: 'Security',
                color: Colors.teal,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please set a password';
                      if (val.length < 4) return 'Password must be at least 4 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // --- Save Button ---
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Settings',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
