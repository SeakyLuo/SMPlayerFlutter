import 'dart:convert';
import 'dart:io';

typedef TrashPath = Future<void> Function(String path);

class LibraryPendingDeleteService {
  const LibraryPendingDeleteService();

  Future<List<PendingDeleteRecord>> readRecords(File file) async {
    if (!file.existsSync()) {
      return const [];
    }

    final content = await file.readAsString();
    final data =
        content.trim().isEmpty
            ? const <Object?>[]
            : jsonDecode(content) as List<dynamic>;
    return data
        .whereType<Map<String, Object?>>()
        .map(pendingDeleteRecordFromJson)
        .toList();
  }

  Future<void> writeRecords(
    File file,
    List<PendingDeleteRecord> records,
  ) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(records.map((record) => record.toJson()).toList())}\n',
    );
  }

  Future<void> prependRecord(File file, PendingDeleteRecord record) async {
    final records = await readRecords(file);
    await writeRecords(file, [record, ...records]);
  }

  Future<void> removeRecord(File file, String deleteId) async {
    final records = await readRecords(file);
    await writeRecords(
      file,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  PendingSongDeleteRecord findSongDeleteRecord(
    List<PendingDeleteRecord> records,
    String deleteId,
  ) {
    return records.whereType<PendingSongDeleteRecord>().firstWhere(
      (item) => item.id == deleteId,
    );
  }

  PendingLocalItemsDeleteRecord findLocalItemsDeleteRecord(
    List<PendingDeleteRecord> records,
    String deleteId,
  ) {
    return records.whereType<PendingLocalItemsDeleteRecord>().firstWhere(
      (item) => item.id == deleteId,
    );
  }

  Future<void> commitSongDelete(
    File file,
    String deleteId,
    TrashPath trashPath,
  ) async {
    final records = await readRecords(file);
    final record = findSongDeleteRecord(records, deleteId);
    await _trashPathIfExists(record.songPath, trashPath);
    await writeRecords(
      file,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> commitLocalItemsDelete(
    File file,
    String deleteId,
    TrashPath trashPath,
  ) async {
    final records = await readRecords(file);
    final record = findLocalItemsDeleteRecord(records, deleteId);
    await _trashRecord(record, trashPath);
    await writeRecords(
      file,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> commitPendingDeletes(File file, TrashPath trashPath) async {
    if (!file.existsSync()) {
      return;
    }

    final records = await readRecords(file);
    final committedRecordIds = <String>{};
    for (final record in records) {
      try {
        await _trashRecord(record, trashPath);
        committedRecordIds.add(record.id);
      } on Object {
        // Keep failed records so the next launch can retry moving them to trash.
      }
    }
    await writeRecords(
      file,
      records
          .where((record) => !committedRecordIds.contains(record.id))
          .toList(),
    );
  }

  Future<void> _trashRecord(
    PendingDeleteRecord record,
    TrashPath trashPath,
  ) async {
    if (record is PendingSongDeleteRecord) {
      await _trashPathIfExists(record.songPath, trashPath);
      return;
    }

    final localItemsRecord = record as PendingLocalItemsDeleteRecord;
    for (final targetPath in localItemsRecord.targetPaths) {
      await _trashPathIfExists(targetPath, trashPath);
    }
  }

  Future<void> _trashPathIfExists(
    String targetPath,
    TrashPath trashPath,
  ) async {
    final type = FileSystemEntity.typeSync(targetPath);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    await trashPath(targetPath);
  }
}

abstract class PendingDeleteRecord {
  const PendingDeleteRecord();

  String get id;

  Map<String, Object?> toJson();
}

PendingDeleteRecord pendingDeleteRecordFromJson(Map<String, Object?> json) {
  return json['type'] == 'local-items'
      ? PendingLocalItemsDeleteRecord.fromJson(json)
      : PendingSongDeleteRecord.fromJson(json);
}

class PendingSongDeleteRecord extends PendingDeleteRecord {
  const PendingSongDeleteRecord({
    required this.id,
    required this.songId,
    required this.songPath,
    required this.musicArtistIds,
    required this.playlistItemIds,
    required this.recentRecordIds,
    required this.hiddenStorageItemIds,
  }) : super();

  factory PendingSongDeleteRecord.fromJson(Map<String, Object?> json) {
    return PendingSongDeleteRecord(
      id: json['id'] as String,
      songId: json['songId'] as int,
      songPath: json['songPath'] as String,
      musicArtistIds: intListFromJson(json['musicArtistIds']),
      playlistItemIds: intListFromJson(json['playlistItemIds']),
      recentRecordIds: intListFromJson(json['recentRecordIds']),
      hiddenStorageItemIds: intListFromJson(json['hiddenStorageItemIds']),
    );
  }

  @override
  final String id;
  final int songId;
  final String songPath;
  final List<int> musicArtistIds;
  final List<int> playlistItemIds;
  final List<int> recentRecordIds;
  final List<int> hiddenStorageItemIds;

  @override
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': 'song',
      'songId': songId,
      'songPath': songPath,
      'musicArtistIds': musicArtistIds,
      'playlistItemIds': playlistItemIds,
      'recentRecordIds': recentRecordIds,
      'hiddenStorageItemIds': hiddenStorageItemIds,
    };
  }
}

class PendingLocalItemsDeleteRecord extends PendingDeleteRecord {
  const PendingLocalItemsDeleteRecord({
    required this.id,
    required this.songIds,
    required this.folderPaths,
    required this.targetPaths,
    required this.musicIds,
    required this.musicArtistIds,
    required this.playlistItemIds,
    required this.recentRecordIds,
    required this.hiddenStorageItemIds,
    required this.folderIds,
    required this.fileIds,
  }) : super();

  factory PendingLocalItemsDeleteRecord.fromJson(Map<String, Object?> json) {
    return PendingLocalItemsDeleteRecord(
      id: json['id'] as String,
      songIds: intListFromJson(json['songIds']),
      folderPaths: stringListFromJson(json['folderPaths']),
      targetPaths: stringListFromJson(json['targetPaths']),
      musicIds: intListFromJson(json['musicIds']),
      musicArtistIds: intListFromJson(json['musicArtistIds']),
      playlistItemIds: intListFromJson(json['playlistItemIds']),
      recentRecordIds: intListFromJson(json['recentRecordIds']),
      hiddenStorageItemIds: intListFromJson(json['hiddenStorageItemIds']),
      folderIds: intListFromJson(json['folderIds']),
      fileIds: intListFromJson(json['fileIds']),
    );
  }

  @override
  final String id;
  final List<int> songIds;
  final List<String> folderPaths;
  final List<String> targetPaths;
  final List<int> musicIds;
  final List<int> musicArtistIds;
  final List<int> playlistItemIds;
  final List<int> recentRecordIds;
  final List<int> hiddenStorageItemIds;
  final List<int> folderIds;
  final List<int> fileIds;

  @override
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': 'local-items',
      'songIds': songIds,
      'folderPaths': folderPaths,
      'targetPaths': targetPaths,
      'musicIds': musicIds,
      'musicArtistIds': musicArtistIds,
      'playlistItemIds': playlistItemIds,
      'recentRecordIds': recentRecordIds,
      'hiddenStorageItemIds': hiddenStorageItemIds,
      'folderIds': folderIds,
      'fileIds': fileIds,
    };
  }
}

List<int> intListFromJson(Object? value) {
  return (value as List).map((item) => item as int).toList();
}

List<String> stringListFromJson(Object? value) {
  return (value as List).map((item) => item as String).toList();
}
