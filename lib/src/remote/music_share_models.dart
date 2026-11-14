import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const musicSharePort = 29644;
const musicDiscoveryPort = 29645;
const remoteMusicScheme = 'smplayer-music';

String newShareSecret() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

String shareDigest(String value) =>
    sha256.convert(utf8.encode(value)).toString();

String remoteMusicPath(String device, int song) =>
    '$remoteMusicScheme://$device/$song';

bool isRemoteMusicPath(String path) => path.startsWith('$remoteMusicScheme://');

enum MusicPeerStatus { offline, online, unauthorized }

class MusicPeer {
  MusicPeer({
    required this.id,
    required this.name,
    required this.address,
    required this.fingerprint,
    required this.token,
  });

  final String id;
  String name;
  String address;
  final String fingerprint;
  final String token;
  bool canWrite = false;
  bool supportsPlaylists = false;
  MusicPeerStatus status = MusicPeerStatus.offline;
  String? catalogRevision;

  factory MusicPeer.fromJson(Map<String, dynamic> json) => MusicPeer(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    fingerprint: json['fingerprint'] as String,
    token: json['token'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'fingerprint': fingerprint,
    'token': token,
  };
}

class DiscoveredMusicHost {
  const DiscoveredMusicHost(this.id, this.name, this.address);
  final String id;
  final String name;
  final String address;
}

class MusicPairRequest {
  MusicPairRequest({
    required this.secret,
    required this.name,
    required this.code,
    this.deviceIdentity,
    this.previousGrant,
    this.isMobile = false,
  });
  final String secret;
  final String name;
  final String code;
  final String? deviceIdentity;
  final String? previousGrant;
  final bool isMobile;
  final expires = DateTime.now().add(const Duration(minutes: 2));
  String state = 'pending';
  String? token;
}

class MusicShareException implements Exception {
  const MusicShareException(this.messageKey, {this.httpStatusCode});
  final String messageKey;
  final int? httpStatusCode;
  @override
  String toString() =>
      httpStatusCode == null
          ? messageKey
          : '$messageKey (HTTP $httpStatusCode)';
}
