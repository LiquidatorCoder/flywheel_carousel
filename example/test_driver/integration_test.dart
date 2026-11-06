import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver for `integration_test/flywheel_e2e_test.dart`.
///
/// Writes the metrics the tests report to `build/e2e/metrics.json` and prints
/// a compact per-scenario table.
Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final metrics = data ?? <String, dynamic>{};
    final file = File('build/e2e/metrics.json');
    await file.create(recursive: true);
    await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(metrics)}\n');
    stdout.writeln(_table(metrics));
    stdout.writeln('metrics written to ${file.path}');
  },
);

String _table(Map<String, dynamic> metrics) {
  const cols = <(String, String)>[
    ('frames', 'frames'),
    ('build_avg_ms', 'bAvg'),
    ('build_p90_ms', 'bP90'),
    ('build_max_ms', 'bMax'),
    ('raster_avg_ms', 'rAvg'),
    ('raster_p90_ms', 'rP90'),
    ('raster_max_ms', 'rMax'),
    ('jank_frames', 'jank'),
    ('settle_ms', 'settle'),
    ('builder_calls_per_frame', 'calls/f'),
  ];
  String fmt(Object? v) => v == null
      ? '-'
      : v is num && v is! int
      ? v.toStringAsFixed(1)
      : '$v';
  final rows = <List<String>>[
    ['scenario', for (final c in cols) c.$2],
  ];
  for (final e in metrics.entries) {
    final v = e.value;
    if (v is! Map) continue;
    rows.add([e.key, for (final c in cols) fmt(v[c.$1])]);
  }
  final widths = [
    for (var i = 0; i < rows.first.length; i++)
      rows.map((r) => r[i].length).reduce((a, b) => a > b ? a : b),
  ];
  return rows
      .map((r) => [for (var i = 0; i < r.length; i++) r[i].padRight(widths[i])].join('  '))
      .join('\n');
}
