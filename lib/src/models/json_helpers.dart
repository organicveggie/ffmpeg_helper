import 'enums.dart';

int jsonStringToInt(String? s) => (s == null) ? 0 : int.parse(s);
String jsonIntToString(int? n) => (n == null) ? '' : n.toString();

final RegExp _truthyRegEx = RegExp(r'^\s*(yes|true)\s*$', multiLine: true, caseSensitive: false);

bool jsonStringToBool(String? s) => (s == null) ? false : _truthyRegEx.hasMatch(s);

BitRateMode? jsonStringToBitRateMode(String? s) {
  if (s == null) {
    return null;
  } else if (s.toUpperCase() == 'CBR') {
    return BitRateMode.constant;
  } else if (s.toUpperCase() == 'VBR') {
    return BitRateMode.variable;
  }
  return BitRateMode.unknown;
}

String? jsonBitRateModeToString(BitRateMode? mode) => mode?.toString();
