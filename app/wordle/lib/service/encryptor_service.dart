// json_encrypt.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;
import 'package:wordle/service/secure_storage_service.dart';

class JsonEncryptor {
  final SecureStorageService _storageService = SecureStorageService();

  static String encryptJsonToBase64(Map<String, dynamic> data, String publicKeyPem) {
    final jsonString = jsonEncode(data);
    final compressed = GZipCodec().encode(utf8.encode(jsonString));

    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(12);

    final aesEnc = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.gcm));
    final encryptedData = aesEnc.encryptBytes(compressed, iv: iv);

    final parser = encrypt.RSAKeyParser();
    final publicKey = parser.parse(publicKeyPem) as pc.RSAPublicKey;

    final engine = pc.OAEPEncoding.withSHA256(pc.RSAEngine());
    engine.init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));

    final encryptedAesKey = engine.process(aesKey.bytes);

    // 5. Combine
    final combined = Uint8List.fromList([
      ...encryptedAesKey,
      ...iv.bytes,
      ...encryptedData.bytes,
    ]);

    return base64Encode(combined);
  }

  Future<bool> savePublicKey(String pk) async {
    try {
      await _storageService.saveSecretKey(pk);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getPublicKey() async {
    return await _storageService.getSecretKey();
  }
}