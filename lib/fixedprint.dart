enum Alignment {
  left,
  middle,
  right;
}

enum Overflow {
  truncate,
  ellipsis;
}

class FixedPrint {
  final StringSink out;
  final Alignment defaultAlign;
  final Overflow defaultOverflow;
  final String defaultPadding;

  const FixedPrint(this.out,
      {Alignment? defaultAlign, Overflow? defaultOverflow, String? defaultPadding})
      : defaultAlign = defaultAlign ?? Alignment.left,
        defaultOverflow = defaultOverflow ?? Overflow.truncate,
        defaultPadding = defaultPadding ?? ' ';

  // Writes a string to the output sink.
  //
  // Writes all of [s] if [width] is null and ignores all other named parameters. Otherwise,
  // if [s] larger than [width], uses the value of [overflow] to decide whether to truncate
  // or truncate and add ellipsis. If [s] is shorter than [width], pads [s] based on the [align]
  // to fit within the [width] using the specified padding character(s).
  void write(String s,
      {int? width, Alignment? customAlign, Overflow? customOverflow, String? customPadding}) {
    if ((width == null) || (width == 0)) {
      out.write(s);
      return;
    }

    final align = customAlign ?? defaultAlign;
    final overflow = customOverflow ?? defaultOverflow;
    final padding = customPadding ?? defaultPadding;

    final w = width;
    if (s.length == w) {
      out.write(s);
    } else if (s.length > w) {
      var maxChars = w - ((overflow == Overflow.truncate) ? 0 : 3);
      out.write(s.substring(0, maxChars));
      if (overflow == Overflow.ellipsis) {
        out.write('...');
      }
      return;
    } else if (align == Alignment.left) {
      out.write(s.padRight(w, padding));
    } else if (align == Alignment.right) {
      out.write(s.padLeft(w, padding));
    } else {
      // Center alignment
      // Split text into two roughly equal parts. Left-pad the first part. Right-pad the 2nd part.
      int widthMidpoint = w ~/ 2;
      int strMidpoint = s.length ~/ 2;

      var leftStr = s.substring(0, strMidpoint).padLeft(widthMidpoint, padding);
      var rightStr = s.substring(strMidpoint, s.length).padRight(w - widthMidpoint, padding);
      out.write(leftStr);
      out.write(rightStr);
    }
  }

  void writeln(String s,
      {int? width, Alignment? customAlign, Overflow? customOverflow, String? customPadding}) {
    write(s,
        width: width,
        customAlign: customAlign,
        customOverflow: customOverflow,
        customPadding: customPadding);
    out.writeln();
  }
}
