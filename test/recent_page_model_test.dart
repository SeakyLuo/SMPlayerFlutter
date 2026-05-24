import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/recent/recent_page_model.dart';

void main() {
  test('formatRecentDateTime displays UTC timestamps in local time', () {
    const value = '2026-05-20T00:30:00.000Z';
    final local = DateTime.utc(2026, 5, 20, 0, 30).toLocal();
    final datePart =
        local.year == DateTime.now().year
            ? '${local.month}/${local.day}'
            : '${local.year}/${local.month}/${local.day}';

    expect(
      formatRecentDateTime(value),
      '$datePart ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}',
    );
  });
}
