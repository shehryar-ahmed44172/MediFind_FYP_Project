import 'package:flutter/foundation.dart';

/// Safely parses a dynamic JSON value into a double.
/// Handles cases where the value might be a [num], [String], or null.
double doubleFromJson(dynamic value) {
  if (value == null) return 0.0;
  
  if (value is num) {
    return value.toDouble();
  }
  
  if (value is String) {
    try {
      return double.tryParse(value) ?? 0.0;
    } catch (e) {
      debugPrint('Error parsing double from string "$value": $e');
      return 0.0;
    }
  }
  
  return 0.0;
}

/// Safely parses a dynamic JSON value into an int.
int intFromJson(dynamic value) {
  if (value == null) return 0;
  
  if (value is num) {
    return value.toInt();
  }
  
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  
  return 0;
}
