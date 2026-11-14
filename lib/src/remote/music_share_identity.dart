import 'dart:async';
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

bool isMusicShareNetworkFailure(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is HttpException;

class MusicShareTransport {
  MusicShareTransport(
    this.address, {
    this.fingerprint,
    this.token,
    this.onNetworkError,
    int? maxConnectionsPerHost,
  }) {
    _client.connectionTimeout = const Duration(seconds: 5);
    _client.maxConnectionsPerHost = maxConnectionsPerHost;
    _client.badCertificateCallback = (certificate, host, port) {
      final digest = sha256.convert(certificate.der).toString();
      observedFingerprint = digest;
      fingerprint ??= digest;
      return digest == fingerprint;
    };
  }

  final void Function(Object, StackTrace)? onNetworkError;
  var _closed = false;
  final String address;
  String? fingerprint;
  final String? token;
  String? observedFingerprint;
  final _client = HttpClient(context: SecurityContext(withTrustedRoots: false));

  Future<T> runNetworkOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stack) {
      reportNetworkFailure(error, stack);
      rethrow;
    }
  }

  void reportNetworkFailure(Object error, StackTrace stack) {
    if (!_closed && isMusicShareNetworkFailure(error)) {
      onNetworkError?.call(error, stack);
    }
  }

  Future<WebSocket> connectEvents() => runNetworkOperation(() async {
    final uri = Uri.parse(address).resolve('/events').replace(scheme: 'wss');
    final socket = await WebSocket.connect(
      uri.toString(),
      customClient: _client,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    socket.pingInterval = const Duration(seconds: 20);
    return socket;
  });

  Future<HttpClientResponse> open(
    String path, {
    String method = 'GET',
    Object? body,
    String? range,
  }) => runNetworkOperation(
    () => _open(path, method: method, body: body, range: range),
  );

  Future<HttpClientResponse> _open(
    String path, {
    String method = 'GET',
    Object? body,
    String? range,
  }) async {
    final uri = Uri.parse(address).resolve(path);
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set(
      'X-Smplayer-Device-Type',
      Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop',
    );
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
    try {
      return await runNetworkOperation(
        () => _json(path, method: method, body: body),
      );
    } on TimeoutException {
      throw const MusicShareException('share.requestTimedOut');
    }
  }

  Future<Map<String, dynamic>> _json(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final response = await _open(path, method: method, body: body);
    final bytes = await response
        .fold<BytesBuilder>(
          BytesBuilder(),
          (builder, data) => builder..add(data),
        )
        .timeout(const Duration(seconds: 15));
    final text = utf8.decode(bytes.takeBytes());
    final payload =
        (response.statusCode == HttpStatus.ok ||
                response.headers.contentType?.mimeType == 'application/json')
            ? jsonDecode(text) as Map<String, dynamic>
            : <String, dynamic>{};
    if (response.statusCode != HttpStatus.ok) {
      throw MusicShareException(
        payload['error'] as String? ??
            '${response.statusCode} ${response.reasonPhrase}',
        httpStatusCode: response.statusCode,
      );
    }
    return payload;
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
