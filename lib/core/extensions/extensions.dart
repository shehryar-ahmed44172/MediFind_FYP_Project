/// Extension methods for common operations
extension StringExtension on String {
  bool get isNullOrEmpty => isEmpty;
  
  bool get isValidEmail => RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  ).hasMatch(this);
  
  bool get isValidPhone => RegExp(r'^\+?[1-9]\d{1,14}$')
      .hasMatch(replaceAll(RegExp(r'\D'), ''));
}

extension NullableStringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  
  String get orEmpty => this ?? '';
  
  String get orUnknown => this ?? 'Unknown';
}

extension DateTimeExtension on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  String get formattedDate {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return '$day/$month/$year';
  }
}

extension DurationExtension on Duration {
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes % 60;
    final seconds = inSeconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

extension NumExtension on num {
  String get formattedDistance {
    if (this < 1000) {
      return '${toStringAsFixed(0)}m';
    }
    return '${(this / 1000).toStringAsFixed(1)}km';
  }
}
