import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._internal();
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  // Configure Android to use encrypted shared preferences
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'cwffects'
    ),
  );

  static const String _secretKeyName = 'mhtxdrs';
  static const String _passwordKey = 'settings_password';
  static const String _serverUrlKey = 'settings_server_url';

  Future<void> saveSecretKey(String key) async {
    await _storage.write(key: _secretKeyName, value: key);
  }

  Future<String?> getSecretKey() async {
    return await _storage.read(key: _secretKeyName);
  }

  Future<void> deleteSecretKey() async {
    await _storage.delete(key: _secretKeyName);
  }

  // --- Settings password ---
  Future<void> savePassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  // --- Server URL ---
  Future<void> saveServerUrl(String url) async {
    await _storage.write(key: _serverUrlKey, value: url);
  }

  Future<String?> getServerUrl() async {
    return await _storage.read(key: _serverUrlKey);
  }

  // --- Check if settings were previously saved ---
  Future<bool> hasSettings() async {
    final password = await _storage.read(key: _passwordKey);
    return password != null && password.isNotEmpty;
  }
}