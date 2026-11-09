import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'music_share_models.dart';

class MusicShareIdentity {
  MusicShareIdentity(this.id, this.key, this.certificate);
  final String id;
  final String key;
  final String certificate;

  static const storage = FlutterSecureStorage();

  static Future<MusicShareIdentity> load() async {
    final stored = await storage.read(key: 'music-share-identity-v1');
    if (stored != null) {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return MusicShareIdentity(
        json['id'] as String,
        json['key'] as String,
        json['certificate'] as String,
      );
    }
    final identity = await Isolate.run(() {
      final id = const Uuid().v4();
      final pair = CryptoUtils.generateRSAKeyPair();
      final private = pair.privateKey as RSAPrivateKey;
      final public = pair.publicKey as RSAPublicKey;
      final csr = X509Utils.generateRsaCsrPem({'CN': id}, private, public);
      return MusicShareIdentity(
        id,
        CryptoUtils.encodeRSAPrivateKeyToPem(private),
        X509Utils.generateSelfSignedCertificate(private, csr, 3650),
      );
    });
    await storage.write(
      key: 'music-share-identity-v1',
      value: jsonEncode({
        'id': identity.id,
        'key': identity.key,
        'certificate': identity.certificate,
      }),
    );
    return identity;
  }

  String get fingerprint {
    final der = CryptoUtils.getBytesFromPEMString(certificate);
    return sha256.convert(der).toString();
  }

  SecurityContext serverContext() =>
      SecurityContext()
        ..useCertificateChainBytes(utf8.encode(certificate))
        ..usePrivateKeyBytes(utf8.encode(key));
}

class MusicShareTransport {
  MusicShareTransport(this.address, {this.fingerprint, this.token}) {
    _client.connectionTimeout = const Duration(seconds: 5);
    _client.badCertificateCallback = (certificate, host, port) {
      final digest = sha256.convert(certificate.der).toString();
      observedFingerprint = digest;
      fingerprint ??= digest;
      return digest == fingerprint;
    };
  }

  final String address;
  String? fingerprint;
  final String? token;
  String? observedFingerprint;
  final _client = HttpClient(context: SecurityContext(withTrustedRoots: false));

  Future<HttpClientResponse> open(
    String path, {
    String method = 'GET',
    Object? body,
    String? range,
  }) async {
    final uri = Uri.parse(address).resolve(path);
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    return request.close().timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> json(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final response = await open(path, method: method, body: body);
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw MusicShareException(
        response.statusCode == 403 && path == '/pair'
            ? 'share.pairingClosed'
            : response.statusCode == 401
            ? 'share.authorizationRequired'
            : 'share.connectionFailed',
      );
    }
    final bytes = await response
        .fold<BytesBuilder>(
          BytesBuilder(),
          (builder, data) => builder..add(data),
        )
        .timeout(const Duration(seconds: 15));
    return jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
  }

  void close() => _client.close(force: true);
}
