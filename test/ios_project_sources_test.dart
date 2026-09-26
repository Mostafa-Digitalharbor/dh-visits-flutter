// Guards the Xcode project against a Swift file that exists on disk but is not
// compiled into Runner.
//
// Xcode only builds what `project.pbxproj` lists, so restoring a `.swift` file
// with git (as happened when work-day tracking was reinstated) leaves it out
// of the build. Nothing fails on Windows or in the Dart tests; the first sign
// is the iOS release job dying with "Cannot find '<Type>' in scope".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Swift file in ios/Runner is compiled into the Runner target', () {
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final swiftFiles = Directory('ios/Runner')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.swift'));

    final missing = [
      for (final name in swiftFiles)
        if (!pbxproj.contains('/* $name in Sources */')) name,
    ];

    expect(
      missing,
      isEmpty,
      reason: 'These files are not in the Runner target, so iOS builds cannot '
          'see them. Add each one in Xcode (Runner group → Add Files, target '
          'Runner checked), or add its PBXBuildFile, PBXFileReference, group '
          'child and Sources entries to project.pbxproj by hand.',
    );
  });
}
