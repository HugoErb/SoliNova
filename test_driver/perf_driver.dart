import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Écrit le résumé des temps d'image dans build/drag_perf.timeline_summary.json.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final timeline = driver.Timeline.fromJson(
      (data['drag_perf']! as Map).cast<String, dynamic>(),
    );
    final summary = driver.TimelineSummary.summarize(timeline);
    await summary.writeTimelineToFile(
      'drag_perf',
      pretty: true,
      includeSummary: true,
    );
  },
);
