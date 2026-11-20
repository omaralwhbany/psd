import 'dart:typed_data';

const List<int> _n5Bits = <int>[
  0, 3, 5, 7, 10, 12, 14, 17, 19, 21, 24, 26, 28, 31,
  33, 35, 38, 40, 42, 45, 47, 49, 52, 54, 56, 59, 61,
];

const List<int> _insignificantDigitsNumber = <int>[
  0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4,
  4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9,
  9, 9, 10, 10, 10, 11, 11, 11, 12, 12, 12, 12, 13,
  13, 13, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 17,
  17, 17, 18, 18, 18, 19,
];

final List<BigInt> _powersOfFive = List<BigInt>.generate(
  325,
  (index) => BigInt.from(5).pow(index),
  growable: false,
);

class _FloatingDecimalDigits {
  const _FloatingDecimalDigits({
    required this.digits,
    required this.decimalExponent,
    required this.roundedUp,
    required this.exact,
  });

  final List<int> digits;
  final int decimalExponent;
  final bool roundedUp;
  final bool exact;
}

/// Formats the two DecimalFormat patterns used by PSD5 Buck graphs.
///
/// This ports the OpenJDK 21 FloatingDecimal compatibility conversion and
/// DigitList HALF_EVEN rounding path. The legacy 32-bit and 64-bit dtoa paths
/// deliberately retain Java's signed overflow behavior; an exact BigInt-only
/// conversion does not produce the same labels for every large double.
String formatBuckJavaDecimal(
  double value, {
  required int minFractionDigits,
  required int maxFractionDigits,
}) {
  if (minFractionDigits < 0 || maxFractionDigits < minFractionDigits) {
    throw ArgumentError('Invalid DecimalFormat fraction digit range.');
  }
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';

  final data = ByteData(8)..setFloat64(0, value, Endian.big);
  final bits = data.getInt64(0, Endian.big);
  final negative = bits.isNegative;
  if (value == 0.0) {
    final fraction = List<String>.filled(minFractionDigits, '0').join();
    return (negative ? '-0' : '0') +
        (fraction.isEmpty ? '' : '.' + fraction);
  }

  final converted = _floatingDecimalDigits(bits);
  final digits = List<int>.of(converted.digits);
  var decimalExponent = converted.decimalExponent;

  // DigitList removes leading zeroes while parsing the converter's decimal
  // string, then removes trailing zeroes before applying the pattern scale.
  while (digits.length > 1 && digits.first == 0) {
    digits.removeAt(0);
  }
  while (digits.length > 1 && digits.last == 0) {
    digits.removeLast();
  }

  if (-decimalExponent > maxFractionDigits) {
    digits.clear();
  } else if (-decimalExponent == maxFractionDigits) {
    if (_shouldRoundUp(
      digits,
      0,
      converted.roundedUp,
      converted.exact,
    )) {
      digits
        ..clear()
        ..add(1);
      decimalExponent++;
    } else {
      digits.clear();
    }
  } else {
    final maximumDigits = maxFractionDigits + decimalExponent;
    if (maximumDigits >= 0 && maximumDigits < digits.length) {
      if (_shouldRoundUp(
        digits,
        maximumDigits,
        converted.roundedUp,
        converted.exact,
      )) {
        var carryIndex = maximumDigits - 1;
        while (carryIndex >= 0 && digits[carryIndex] == 9) {
          digits[carryIndex] = 0;
          carryIndex--;
        }
        if (carryIndex < 0) {
          digits[0] = 1;
          decimalExponent++;
        } else {
          digits[carryIndex]++;
        }
      }
      digits.removeRange(maximumDigits, digits.length);
      while (digits.length > 1 && digits.last == 0) {
        digits.removeLast();
      }
    }
  }

  final formatted = _formatDigitList(
    digits,
    decimalExponent,
    minFractionDigits,
  );
  return (negative ? '-' : '') + formatted;
}

/// Buck.java first formats a graph side label with #0.00#### and Graph.java
/// parses that text back to a double before selecting the SI prefix.
double buckJavaGraphLabelValue(double value) {
  if (!value.isFinite) return value;
  return double.parse(
    formatBuckJavaDecimal(
      value,
      minFractionDigits: 2,
      maxFractionDigits: 6,
    ),
  );
}

/// Graph.java uses a negated >= 1.0 comparison; NaN therefore keeps the milli
/// prefix, while infinities and magnitudes of at least one use base units.
bool buckJavaGraphLabelKeepsMilliPrefix(double value) =>
    !(buckJavaGraphLabelValue(value).abs() >= 1.0);

/// Graph.java formats the already-rounded label after applying mV/mA scaling.
String formatBuckJavaGraphMetric(double value, double scale) =>
    formatBuckJavaDecimal(
      buckJavaGraphLabelValue(value) * scale,
      minFractionDigits: 2,
      maxFractionDigits: 2,
    );

bool _shouldRoundUp(
  List<int> digits,
  int maximumDigits,
  bool alreadyRounded,
  bool decimalDigitsExact,
) {
  if (maximumDigits >= digits.length) return false;
  final nextDigit = digits[maximumDigits];
  if (nextDigit > 5) return true;
  if (nextDigit < 5) return false;

  // DigitList has already stripped trailing zeroes, so any remaining digit
  // after a five means the discarded decimal tail is strictly greater than
  // an exact half.
  if (maximumDigits < digits.length - 1) return true;
  if (alreadyRounded) return false;
  if (!decimalDigitsExact) return true;
  return maximumDigits > 0 && digits[maximumDigits - 1].isOdd;
}

String _formatDigitList(
  List<int> digits,
  int decimalExponent,
  int minFractionDigits,
) {
  if (digits.isEmpty || (digits.length == 1 && digits.single == 0)) {
    final fraction = List<String>.filled(minFractionDigits, '0').join();
    return '0' + (fraction.isEmpty ? '' : '.' + fraction);
  }

  final digitText = digits.join();
  late String integerPart;
  late String fractionPart;
  if (decimalExponent <= 0) {
    integerPart = '0';
    fractionPart =
        List<String>.filled(-decimalExponent, '0').join() + digitText;
  } else if (decimalExponent >= digitText.length) {
    integerPart = digitText +
        List<String>.filled(
          decimalExponent - digitText.length,
          '0',
        ).join();
    fractionPart = '';
  } else {
    integerPart = digitText.substring(0, decimalExponent);
    fractionPart = digitText.substring(decimalExponent);
  }

  while (fractionPart.endsWith('0')) {
    fractionPart = fractionPart.substring(0, fractionPart.length - 1);
  }
  if (fractionPart.length < minFractionDigits) {
    fractionPart += List<String>.filled(
      minFractionDigits - fractionPart.length,
      '0',
    ).join();
  }
  return integerPart +
      (fractionPart.isEmpty ? '' : '.' + fractionPart);
}

_FloatingDecimalDigits _floatingDecimalDigits(int bits) {
  final exponentBits = (bits >> 52) & 0x7ff;
  var fractionBits = bits & 0x000fffffffffffff;
  if (exponentBits == 0x7ff || (exponentBits == 0 && fractionBits == 0)) {
    throw ArgumentError('A finite non-zero double is required.');
  }

  late int binaryExponent;
  late int significantBits;
  if (exponentBits == 0) {
    final leadingZeros = 64 - fractionBits.bitLength;
    final shift = leadingZeros - 11;
    fractionBits <<= shift;
    binaryExponent = 1 - shift - 1023;
    significantBits = 64 - leadingZeros;
  } else {
    fractionBits |= 1 << 52;
    binaryExponent = exponentBits - 1023;
    significantBits = 53;
  }

  final trailingZeros = _numberOfTrailingZeros(fractionBits);
  final fractionBitCount = 53 - trailingZeros;
  final tinyBits = fractionBitCount - binaryExponent - 1 > 0
      ? fractionBitCount - binaryExponent - 1
      : 0;

  // FloatingDecimal's easy integer path calls developLongDigits. It rounds
  // insignificant decimal places half-up before DigitList's later HALF_EVEN
  // pattern rounding, matching the JDK's historical implementation.
  if (binaryExponent <= 62 &&
      binaryExponent >= -21 &&
      tinyBits < 27 &&
      fractionBitCount + _n5BitsAt(tinyBits) < 64 &&
      tinyBits == 0) {
    var insignificantDigits = 0;
    if (binaryExponent > significantBits) {
      final powerOfTwo = binaryExponent - significantBits - 1;
      if (powerOfTwo > 1 &&
          powerOfTwo < _insignificantDigitsNumber.length) {
        insignificantDigits = _insignificantDigitsNumber[powerOfTwo];
      }
    }

    var integerValue = BigInt.from(fractionBits);
    if (binaryExponent >= 52) {
      integerValue <<= binaryExponent - 52;
    } else {
      integerValue >>= 52 - binaryExponent;
    }

    var decimalExponent = insignificantDigits;
    if (insignificantDigits != 0) {
      final powerOfTen =
          _powersOfFive[insignificantDigits] << insignificantDigits;
      final residue = integerValue.remainder(powerOfTen);
      integerValue ~/= powerOfTen;
      if (residue >= (powerOfTen >> 1)) {
        integerValue += BigInt.one;
      }
    }

    var digits = integerValue
        .toString()
        .split('')
        .map((character) => int.parse(character))
        .toList();
    while (digits.length > 1 && digits.last == 0) {
      digits.removeLast();
      decimalExponent++;
    }
    return _FloatingDecimalDigits(
      digits: digits,
      decimalExponent: decimalExponent + digits.length,
      roundedUp: false,
      exact: false,
    );
  }

  var decimalExponent = _estimateDecimalExponent(
    fractionBits,
    binaryExponent,
  );
  final b5 = decimalExponent < 0 ? -decimalExponent : 0;
  var b2 = b5 + tinyBits + binaryExponent;
  final s5 = decimalExponent > 0 ? decimalExponent : 0;
  var s2 = s5 + tinyBits;
  final m5 = b5;
  var m2 = b2 - significantBits;
  final normalizedFraction = fractionBits >> trailingZeros;
  b2 -= fractionBitCount - 1;

  final commonPowerOfTwo = b2 < s2 ? b2 : s2;
  b2 -= commonPowerOfTwo;
  s2 -= commonPowerOfTwo;
  m2 -= commonPowerOfTwo;
  if (fractionBitCount == 1) m2--;
  if (m2 < 0) {
    b2 -= m2;
    s2 -= m2;
    m2 = 0;
  }

  final bBits = fractionBitCount + b2 + _n5BitsAt(b5);
  final tenSBits = s2 + 1 + _n5BitsAt(s5 + 1);
  final digits = <int>[];
  late bool low;
  late bool high;
  late BigInt lowDigitDifference;
  late bool exact;

  if (bBits < 32 && tenSBits < 32) {
    const width = 32;
    var b = _wrapSigned(
      BigInt.from(normalizedFraction) * _powersOfFive[b5] << b2,
      width,
    );
    final s = _wrapSigned(_powersOfFive[s5] << s2, width);
    var m = _wrapSigned(_powersOfFive[m5] << m2, width);
    final tenS = _wrapSigned(s * BigInt.from(10), width);

    var quotient = (b ~/ s).toInt();
    b = _wrapSigned(BigInt.from(10) * b.remainder(s), width);
    m = _wrapSigned(m * BigInt.from(10), width);
    low = b < m;
    high = _wrapSigned(b + m, width) > tenS;
    if (quotient == 0 && !high) {
      decimalExponent--;
    } else {
      digits.add(quotient);
    }

    if (decimalExponent < -3 || decimalExponent >= 8) {
      low = false;
      high = false;
    }
    while (!low && !high) {
      quotient = (b ~/ s).toInt();
      b = _wrapSigned(BigInt.from(10) * b.remainder(s), width);
      m = _wrapSigned(m * BigInt.from(10), width);
      if (m > BigInt.zero) {
        low = b < m;
        high = _wrapSigned(b + m, width) > tenS;
      } else {
        low = true;
        high = true;
      }
      digits.add(quotient);
    }
    lowDigitDifference = low && high
        ? _wrapSigned(_wrapSigned(b << 1, width) - tenS, width)
        : BigInt.zero;
    exact = b == BigInt.zero;
  } else if (bBits < 64 && tenSBits < 64) {
    const width = 64;
    var b = _wrapSigned(
      BigInt.from(normalizedFraction) * _powersOfFive[b5] << b2,
      width,
    );
    final s = _wrapSigned(_powersOfFive[s5] << s2, width);
    var m = _wrapSigned(_powersOfFive[m5] << m2, width);
    final tenS = _wrapSigned(s * BigInt.from(10), width);

    var quotient = (b ~/ s).toInt();
    b = _wrapSigned(BigInt.from(10) * b.remainder(s), width);
    m = _wrapSigned(m * BigInt.from(10), width);
    low = b < m;
    high = _wrapSigned(b + m, width) > tenS;
    if (quotient == 0 && !high) {
      decimalExponent--;
    } else {
      digits.add(quotient);
    }

    if (decimalExponent < -3 || decimalExponent >= 8) {
      low = false;
      high = false;
    }
    while (!low && !high) {
      quotient = (b ~/ s).toInt();
      b = _wrapSigned(BigInt.from(10) * b.remainder(s), width);
      m = _wrapSigned(m * BigInt.from(10), width);
      if (m > BigInt.zero) {
        low = b < m;
        high = _wrapSigned(b + m, width) > tenS;
      } else {
        low = true;
        high = true;
      }
      digits.add(quotient);
    }
    lowDigitDifference = low && high
        ? _wrapSigned(_wrapSigned(b << 1, width) - tenS, width)
        : BigInt.zero;
    exact = b == BigInt.zero;
  } else {
    var b = (BigInt.from(normalizedFraction) * _powersOfFive[b5]) << b2;
    final s = _powersOfFive[s5] << s2;
    var m = _powersOfFive[m5] << m2;
    final tenS = s * BigInt.from(10);

    var quotient = (b ~/ s).toInt();
    b = BigInt.from(10) * b.remainder(s);
    m *= BigInt.from(10);
    low = b < m;
    high = b + m >= tenS;
    if (quotient == 0 && !high) {
      decimalExponent--;
    } else {
      digits.add(quotient);
    }

    if (decimalExponent < -3 || decimalExponent >= 8) {
      low = false;
      high = false;
    }
    while (!low && !high) {
      quotient = (b ~/ s).toInt();
      b = BigInt.from(10) * b.remainder(s);
      m *= BigInt.from(10);
      low = b < m;
      high = b + m >= tenS;
      digits.add(quotient);
    }
    lowDigitDifference = low && high
        ? (b << 1) - tenS
        : BigInt.zero;
    exact = b == BigInt.zero;
  }

  if (digits.isEmpty) digits.add(0);
  var roundedUp = false;
  if (high) {
    var shouldRoundUp = false;
    if (low) {
      if (lowDigitDifference == BigInt.zero) {
        shouldRoundUp = digits.last.isOdd;
      } else if (lowDigitDifference > BigInt.zero) {
        shouldRoundUp = true;
      }
    } else {
      shouldRoundUp = true;
    }

    if (shouldRoundUp) {
      var carryIndex = digits.length - 1;
      while (carryIndex > 0 && digits[carryIndex] == 9) {
        digits[carryIndex] = 0;
        carryIndex--;
      }
      if (digits[carryIndex] == 9) {
        decimalExponent++;
        digits[0] = 1;
      } else {
        digits[carryIndex]++;
        roundedUp = true;
      }
    }
  }

  while (digits.length > 1 && digits.first == 0) {
    digits.removeAt(0);
  }
  return _FloatingDecimalDigits(
    digits: digits,
    decimalExponent: decimalExponent + 1,
    roundedUp: roundedUp,
    exact: exact,
  );
}

int _estimateDecimalExponent(int fractionBits, int binaryExponent) {
  final d2Bits =
      (0x3ff << 52) | (fractionBits & 0x000fffffffffffff);
  final data = ByteData(8)..setUint64(0, d2Bits, Endian.big);
  final d2 = data.getFloat64(0, Endian.big);
  final estimate = (d2 - 1.5) * 0.289529654 +
      0.176091259 +
      binaryExponent * 0.301029995663981;
  return estimate.floor();
}

int _n5BitsAt(int exponent) =>
    exponent < _n5Bits.length ? _n5Bits[exponent] : exponent * 3;

int _numberOfTrailingZeros(int value) {
  var count = 0;
  var remaining = value;
  while ((remaining & 1) == 0) {
    remaining >>= 1;
    count++;
  }
  return count;
}

BigInt _wrapSigned(BigInt value, int width) {
  final modulus = BigInt.one << width;
  var wrapped = value.remainder(modulus);
  if (wrapped.isNegative) wrapped += modulus;
  final signBit = BigInt.one << (width - 1);
  return wrapped >= signBit ? wrapped - modulus : wrapped;
}
