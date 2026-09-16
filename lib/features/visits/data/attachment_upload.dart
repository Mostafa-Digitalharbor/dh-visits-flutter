import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../../core/utils/app_log.dart';
import '../visit_constants.dart';

/// A picked file, read for upload — or the reason it can't be.
sealed class PreparedAttachment {
  const PreparedAttachment();
}

/// Ready to send: the file's name and its bytes as base64.
class AttachmentReady extends PreparedAttachment {
  final String filename;
  final String dataB64;
  const AttachmentReady(this.filename, this.dataB64);
}

/// Over [VisitConstants.maxAttachmentBytes]; nothing was read.
class AttachmentTooLarge extends PreparedAttachment {
  final int bytes;
  const AttachmentTooLarge(this.bytes);
}

/// The file could not be read (moved, deleted, no access).
class AttachmentUnreadable extends PreparedAttachment {
  const AttachmentUnreadable();
}

/// Reads [path] for upload as [filename].
///
/// The size is checked *before* anything is read: the picker used to load the
/// whole file into memory first, whatever the user tapped — a 200 MB video
/// included. The read and the base64 encoding then run on a background
/// isolate; on the UI isolate a 10 MB file costs well over a frame budget
/// (see test/base64_cost_test.dart) and the screen visibly froze.
Future<PreparedAttachment> prepareAttachment(
  String filename,
  String path, {
  int maxBytes = VisitConstants.maxAttachmentBytes,
}) async {
  try {
    final bytes = await File(path).length();
    if (bytes > maxBytes) return AttachmentTooLarge(bytes);
    final data = await Isolate.run(
      () async => base64Encode(await File(path).readAsBytes()),
    );
    return AttachmentReady(filename, data);
  } catch (e) {
    appLog('[prepareAttachment] could not read $filename: $e');
    return const AttachmentUnreadable();
  }
}

/// Writes a downloaded attachment ([dataB64]) to [path], decoding off the UI
/// isolate for the same reason [prepareAttachment] encodes there.
Future<void> writeAttachment(String path, String dataB64) =>
    Isolate.run(() async {
      await File(path).writeAsBytes(base64Decode(dataB64), flush: true);
    });
