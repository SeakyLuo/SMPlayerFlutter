import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'music_share_identity.dart';

Uint8List _pairPayload(String hostFingerprint, String secret, String name) =>
    Uint8List.fromList(
      utf8.encode(
        jsonEncode(['smplayer-pair-v1', hostFingerprint, secret, name]),
      ),
    );

Future<Map<String, String>> signPairIdentity(
  MusicShareIdentity identity,
  String hostFingerprint,
  String secret,
  String name,
) => Isolate.run(() {
  final private = CryptoUtils.rsaPrivateKeyFromPem(identity.key);
  final public = RSAPublicKey(private.modulus!, private.publicExponent!);
  return {
    'publicKey': CryptoUtils.encodeRSAPublicKeyToPem(public),
    'proof': base64Encode(
      CryptoUtils.rsaSign(private, _pairPayload(hostFingerprint, secret, name)),
    ),
  };
});

Future<String> verifyPairIdentity(
  String publicKey,
  String proof,
  String hostFingerprint,
  String secret,
  String name,
) => Isolate.run(() {
  final public = CryptoUtils.rsaPublicKeyFromPem(publicKey);
  if (!CryptoUtils.rsaVerify(
    public,
    _pairPayload(hostFingerprint, secret, name),
    base64Decode(proof),
  )) {
    throw const FormatException('Invalid device proof');
  }
  return sha256
      .convert(CryptoUtils.encodeRSAPublicKeyToDERBytes(public))
      .toString();
});
