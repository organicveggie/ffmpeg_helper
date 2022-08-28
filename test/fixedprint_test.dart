import 'package:ffmpeg_helper/fixedprint.dart';
import 'package:test/test.dart';

void main() {
  group('Constructor Defaults: ', () {
    test('Strings written without width are written verbatim', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);

      f.write('short phrase');
      expect(output.toString(), 'short phrase');

      output.clear();
      f.write('much longer phrase without any explicit width limiting the string length');
      expect(output.toString(),
          'much longer phrase without any explicit width limiting the string length');
    });
    test('Long strings are truncated', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);

      f.write('0123456789', width: 5, customOverflow: Overflow.truncate);
      expect(output.toString(), '01234');

      output.clear();
      f.write('012345678901234', width: 9, customOverflow: Overflow.truncate);
      expect(output.toString(), '012345678');
    });
    test('Long strings are truncated with ellipsis', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);

      f.write('01234567890', width: 10, customOverflow: Overflow.ellipsis);
      expect(output.toString(), '0123456...');

      output.clear();
      f.write('012345678901234', width: 13, customOverflow: Overflow.ellipsis);
      expect(output.toString(), '0123456789...');
    });
    test('Short strings are padded', () {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('123', width: 5);
      expect(output.toString(), '123  ');
    });
  });

  group('Customize constructor defaults: ', () {
    test('Customized right alignment', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultAlign: Alignment.right);
      f.write('12345', width: 10);
      expect(output.toString(), '     12345');
    });
    test('Override customized default alignment', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultAlign: Alignment.middle);
      f.write('12345', width: 10, customAlign: Alignment.right);
      expect(
        output.toString(),
        '     12345',
      );
    });

    test('Customized default ellipsis overflow: ', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultOverflow: Overflow.ellipsis);
      f.write('01234567890', width: 10);
      expect(output.toString(), '0123456...');
    });
    test('Override customized default ellipsis overflow: ', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultOverflow: Overflow.truncate);
      f.write('01234567890', width: 10, customOverflow: Overflow.ellipsis);
      expect(output.toString(), '0123456...');
    });

    test('Custom default padding:', () {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultPadding: '-');
      f.write('123', width: 5);
      expect(output.toString(), '123--');
    });
    test('Override custom default padding:', () {
      var output = StringBuffer();
      var f = FixedPrinter(output, defaultPadding: '-');
      f.write('123', width: 5, customPadding: '=');
      expect(output.toString(), '123==');
    });
  });

  group('Align Left and Pad Right: ', () {
    test('Short strings padded right with defaults', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('12345', width: 10, customAlign: Alignment.left);
      expect(output.toString(), '12345     ');
    });
    test('Short strings padded right with custom padding', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      output.clear();
      f.write('123456', width: 11, customAlign: Alignment.left, customPadding: '-');
      expect(output.toString(), '123456-----');
    });
  });
  group('Align Right and Pad Left: ', () {
    test('Short strings padded left with defaults', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('12345', width: 10, customAlign: Alignment.right);
      expect(output.toString(), '     12345');
    });
    test('Short strings padded left with custom padding', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('123456', width: 11, customAlign: Alignment.right, customPadding: '-');
      expect(output.toString(), '-----123456');
    });
  });
  group('Center aligned: ', () {
    test('even number of letters and even width split evenly', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('ab', width: 4, customAlign: Alignment.middle);
      expect(output.toString(), ' ab ');

      output.clear();
      f.write('abcd', width: 8, customAlign: Alignment.middle);
      expect(output.toString(), '  abcd  ');
    });

    test('even number of letters and odd width', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('ab', width: 5, customAlign: Alignment.middle);
      expect(output.toString(), ' ab  ');

      output.clear();
      f.write('abcd', width: 9, customAlign: Alignment.middle);
      expect(output.toString(), '  abcd   ');
    });

    test('odd number of letters and even width', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('abc', width: 4, customAlign: Alignment.middle);
      expect(output.toString(), ' abc');

      output.clear();
      f.write('abc', width: 6, customAlign: Alignment.middle);
      expect(output.toString(), '  abc ');
    });

    test('odd number of letters and odd width', () async {
      var output = StringBuffer();
      var f = FixedPrinter(output);
      f.write('abc', width: 5, customAlign: Alignment.middle);
      expect(output.toString(), ' abc ');

      output.clear();
      f.write('abc', width: 7, customAlign: Alignment.middle);
      expect(output.toString(), '  abc  ');
    });
  });
}
