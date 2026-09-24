import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// Text a person wrote — a visit's purpose, an outcome, an address, a customer
/// name — laid out in its own reading direction.
///
/// A [Text] takes its direction from the screen. An English purpose that
/// starts or ends with punctuation then reorders inside an Arabic screen:
/// "[QA-AUTO] E2E run" rendered as "E2E run [QA-AUTO]", and an Arabic address
/// scrambled on an English one (both seen on the emulator, 2026-09-17). The
/// paragraph direction here comes from the content itself, while the
/// alignment still follows the screen, so the text sits where the layout
/// expects it.
class AutoDirectionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Defaults to the start edge of the surrounding layout.
  final TextAlign? textAlign;

  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// The direction [text] reads in, judged from its words.
  static TextDirection directionOf(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final screenIsRtl = Directionality.of(context) == TextDirection.rtl;
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: directionOf(text),
      textAlign:
          textAlign ?? (screenIsRtl ? TextAlign.right : TextAlign.left),
    );
  }
}
