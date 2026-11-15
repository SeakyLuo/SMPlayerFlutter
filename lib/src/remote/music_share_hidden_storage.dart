import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';

class MusicShareHiddenStorage {
  const MusicShareHiddenStorage(this.repository, this.rootPath);

  final LibraryRepository repository;
  final String rootPath;

  Future<Map<String, dynamic>> handle(
    HttpRequest request, {
    required void Function(String) onResumed,
  }) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    if (request.method != 'GET' && request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      return {};
    }
    final items =
        (await repository.getHiddenStorageItems())
            .where(
              (item) =>
                  p.equals(rootPath, item.path) ||
                  p.isWithin(rootPath, item.path),
            )
            .toList();
    if (request.method == 'GET') {
      return {
        'items': [
          for (final item in items)
            {'id': item.id, 'type': item.type, 'path': item.path},
        ],
      };
    }

    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    final item = items.where((item) => item.id == body['id']).firstOrNull;
    if (item == null) {
      response.statusCode = HttpStatus.notFound;
      return {};
    }
    await repository.resumeHiddenStorageItem(item);
    onResumed(item.path);
    return {};
  }
}
