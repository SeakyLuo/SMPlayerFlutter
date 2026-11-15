import 'package:sqlite3/sqlite3.dart';

import 'library_time_codec.dart';

void registerLibraryTimeSql(Database db) {
  db.createFunction(
    functionName: 'library_time',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function:
        (values) =>
            LibraryTimeCodec.toSortMilliseconds(values.single as String),
  );
}
