import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/constants/app_config.dart';
import '../models/encrypted_packet.dart';

/// Implements PBKDF2 (100k rounds) and AES-GCM-256 encryption/decryption
/// 100% interoperable with WebCrypto SubtleCrypto in app.js.
class CryptoService {
  SecretKey? _secretKey;
  final AesGcm _aesGcm = AesGcm.with256bits();

  bool get hasKey => _secretKey != null;

  /// Derives an AES-256 key from room password and room salt using PBKDF2 HMAC-SHA256
  Future<void> deriveKey({
    required String password,
    required String roomId,
  }) async {
    final String saltString = '${AppConfig.saltPrefix}$roomId';
    final List<int> salt = utf8.encode(saltString);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: AppConfig.pbkdf2Iterations,
      bits: 256,
    );

    final passwordKey = SecretKey(utf8.encode(password));
    _secretKey = await pbkdf2.deriveKey(
      secretKey: passwordKey,
      nonce: salt,
    );
  }

  /// Clears the active encryption key on logout or room change
  void reset() {
    _secretKey = null;
  }

  /// Encrypts any JSON-serializable Map into an EncryptedPacket
  /// Interoperable with WebCrypto (where ciphertext + 16-byte auth tag are concatenated)
  Future<EncryptedPacket?> encryptPayload(Map<String, dynamic> data) async {
    if (_secretKey == null) return null;

    try {
      final List<int> plaintext = utf8.encode(jsonEncode(data));
      // Generate 12-byte random IV
      final List<int> iv = _aesGcm.newNonce();

      final SecretBox secretBox = await _aesGcm.encrypt(
        plaintext,
        secretKey: _secretKey!,
        nonce: iv,
      );

      // WebCrypto SubtleCrypto appends the 16-byte authentication tag to the ciphertext
      final Uint8List concatenated = Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      return EncryptedPacket(
        e2ee: true,
        iv: base64Encode(iv),
        ct: base64Encode(concatenated),
        v: 1,
      );
    } catch (e) {
      return null;
    }
  }

  /// Decrypts an EncryptedPacket received from MQTT into a JSON Map
  Future<Map<String, dynamic>?> decryptPayload(EncryptedPacket packet) async {
    if (_secretKey == null || !packet.e2ee || packet.iv.isEmpty || packet.ct.isEmpty) {
      return null;
    }

    try {
      final Uint8List iv = base64Decode(packet.iv);
      final Uint8List rawCt = base64Decode(packet.ct);

      // WebCrypto ciphertext has the 16-byte auth tag at the very end
      if (rawCt.length < 16) return null;

      final int splitIndex = rawCt.length - 16;
      final Uint8List cipherText = rawCt.sublist(0, splitIndex);
      final Uint8List macBytes = rawCt.sublist(splitIndex);

      final SecretBox secretBox = SecretBox(
        cipherText,
        nonce: iv,
        mac: Mac(macBytes),
      );

      final List<int> decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: _secretKey!,
      );

      final String jsonStr = utf8.decode(decryptedBytes);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      // Decryption failure: invalid key/password or tampered packet
      return null;
    }
  }
}
