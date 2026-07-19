// Measures what `base64Encode` actually costs on the UI isolate, because the
// attachment path runs it there:
//
//   final result = await FilePicker.pickFiles(withData: true);  // whole file in RAM
//   ... base64Encode(bytes)                                     // on the main isolate
//
// `pickFiles` is called with no size limit and no extension filter, so "bytes"
// is whatever the user tapped — a photo or a 25 MB video. Anything above one
// frame budget (16.6 ms at 60 fps) drops frames; a few hundred ms reads as the
// app having frozen.
//
// This is a measurement, not an assertion about a threshold — it prints the
// numbers so the cost is a known quantity rather than a guess. The loose
// upper bounds only catch a catastrophic regression.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

int _median(List<int> xs) {
  final sorted = [...xs]..sort();
  return sorted[sorted.length ~/ 2];
}

void main() {
  // Representative payloads:
  //   0.4 MB — a camera capture at the app's own imageQuality:70 / maxWidth:1600
  //   2 MB   — a photo picked from the gallery unprocessed
  //   10 MB  — a PDF or short video, which the picker happily allows
  const cases = <String, int>{
    'camera capture ~0.4MB': 400 * 1024,
    'gallery photo ~2MB': 2 * 1024 * 1024,
    'document/video ~10MB': 10 * 1024 * 1024,
  };

  test('base64Encode cost on the UI isolate', () {
    final results = <String, int>{};

    cases.forEach((label, size) {
      final bytes = Uint8List(size);
      // Vary the bytes so the encoder can't benefit from a uniform buffer.
      for (var i = 0; i < size; i += 997) {
        bytes[i] = i % 256;
      }

      // Warm up, then take the median of 5 runs.
      base64Encode(bytes);
      final samples = <int>[];
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        base64Encode(bytes);
        sw.stop();
        samples.add(sw.elapsedMilliseconds);
      }
      final ms = _median(samples);
      results[label] = ms;

      final frames = (ms / 16.6).ceil();
      // ignore: avoid_print
      print('$label: ${ms}ms  (~$frames dropped frames at 60fps)');
    });

    // Sanity ceilings — these are absurdly loose and exist only to fail if
    // something pathological changes, not to encode a performance budget.
    expect(results['camera capture ~0.4MB']!, lessThan(2000));
    expect(results['document/video ~10MB']!, lessThan(30000));
  });
}
