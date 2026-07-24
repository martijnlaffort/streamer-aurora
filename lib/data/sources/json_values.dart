/// Defensive coercers for panel JSON (global rule: any field can be missing,
/// null, or the wrong type). Xtream panels freely mix `"7"` and `7`, send
/// `""` for absent values, epoch seconds as strings, and base64 EPG text.
/// Pure Dart — no Flutter imports — so mapping is unit-testable.
library;

import 'dart:convert';

/// String from string/num; trimmed; empty → null.
String? optString(dynamic v) {
  if (v == null) return null;
  final s = v is String ? v.trim() : (v is num ? v.toString() : null);
  return (s == null || s.isEmpty) ? null : s;
}

/// Like [optString] but with a fallback for required display fields.
String stringOr(dynamic v, String fallback) => optString(v) ?? fallback;

int? optInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? optDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

/// Epoch **seconds** (int or numeric string) → UTC DateTime. Rejects zero,
/// negatives, and implausible values so `"0"`/garbage don't become 1970.
DateTime? optUtcFromEpochSeconds(dynamic v) {
  final s = optInt(v);
  if (s == null || s <= 0 || s > 4102444800 /* year 2100 */) return null;
  return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
}

/// A 4-digit year from an int, a "2024" string, or a "2024-05-01" date string.
int? optYear(dynamic v) {
  final direct = optInt(v);
  if (direct != null && direct >= 1900 && direct <= 2100) return direct;
  final s = optString(v);
  if (s == null || s.length < 4) return null;
  final y = int.tryParse(s.substring(0, 4));
  return (y != null && y >= 1900 && y <= 2100) ? y : null;
}

/// Xtream EPG sends title/description base64-encoded — but not always.
/// Try to decode; fall back to the raw string.
String? optBase64Text(dynamic v) {
  final s = optString(v);
  if (s == null) return null;
  try {
    return optString(utf8.decode(base64.decode(base64.normalize(s))));
  } on FormatException {
    return s;
  }
}

/// Some fields (backdrop_path) arrive as a list OR a plain string.
String? optFirstString(dynamic v) {
  if (v is List) {
    for (final item in v) {
      final s = optString(item);
      if (s != null) return s;
    }
    return null;
  }
  return optString(v);
}

Map<String, dynamic>? optMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : null;

List<dynamic> listOr(dynamic v) => v is List ? v : const [];
