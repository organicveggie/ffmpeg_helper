import 'package:ffmpeg_helper/fixedprint.dart';
import 'package:test/test.dart';

void main() {
  test('Strings written without width are written verbatim', () async {
    var output = StringBuffer();
    var f = FixedPrint(output);

    f.write('short phrase');
    expect(output.toString(), 'short phrase');

    output.clear();
    f.write('much longer phrase without any explicit width limiting the string length');
    expect(output.toString(),
        'much longer phrase without any explicit width limiting the string length');
  });

  test('Long strings are truncated', () async {
    var output = StringBuffer();
    var f = FixedPrint(output);

    f.write('0123456789', width: 5, overflow: Overflow.truncate);
    expect(output.toString(), '01234');

    output.clear();
    f.write('012345678901234', width: 9, overflow: Overflow.truncate);
    expect(output.toString(), '012345678');
  });

  test('Long strings are truncated with ellipsis', () async {
    var output = StringBuffer();
    var f = FixedPrint(output);

    f.write('01234567890', width: 10, overflow: Overflow.ellipsis);
    expect(output.toString(), '0123456...');

    output.clear();
    f.write('012345678901234', width: 13, overflow: Overflow.ellipsis);
    expect(output.toString(), '0123456789...');
  });
  group('Align Left and Pad Right: ', () {
    test('Short strings padded right with defaults', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('12345', width: 10, align: Alignment.left);
      expect(output.toString(), '12345     ');
    });
    test('Short strings padded right with custom padding', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      output.clear();
      f.write('123456', width: 11, align: Alignment.left, padding: '-');
      expect(output.toString(), '123456-----');
    });
  });
  group('Align Right and Pad Left: ', () {
    test('Short strings padded left with defaults', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('12345', width: 10, align: Alignment.right);
      expect(output.toString(), '     12345');
    });
    test('Short strings padded left with custom padding', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('123456', width: 11, align: Alignment.right, padding: '-');
      expect(output.toString(), '-----123456');
    });
  });
  group('Center aligned: ', () {
    test('even number of letters and even width split evenly', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('ab', width: 4, align: Alignment.middle);
      expect(output.toString(), ' ab ');

      output.clear();
      f.write('abcd', width: 8, align: Alignment.middle);
      expect(output.toString(), '  abcd  ');
    });

    test('even number of letters and odd width', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('ab', width: 5, align: Alignment.middle);
      expect(output.toString(), ' ab  ');

      output.clear();
      f.write('abcd', width: 9, align: Alignment.middle);
      expect(output.toString(), '  abcd   ');
    });

    test('odd number of letters and even width', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('abc', width: 4, align: Alignment.middle);
      expect(output.toString(), ' abc');

      output.clear();
      f.write('abc', width: 6, align: Alignment.middle);
      expect(output.toString(), '  abc ');
    });

    test('odd number of letters and odd width', () async {
      var output = StringBuffer();
      var f = FixedPrint(output);
      f.write('abc', width: 5, align: Alignment.middle);
      expect(output.toString(), ' abc ');

      output.clear();
      f.write('abc', width: 7, align: Alignment.middle);
      expect(output.toString(), '  abc  ');
    });
  });
}
