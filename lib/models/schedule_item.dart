import 'package:flutter/material.dart';

enum ScheduleCategory { kerja, kuliah, liburan }

extension ScheduleCategoryX on ScheduleCategory {
  String get value {
    switch (this) {
      case ScheduleCategory.kerja:
        return 'kerja';
      case ScheduleCategory.kuliah:
        return 'kuliah';
      case ScheduleCategory.liburan:
        return 'liburan';
    }
  }

  String get label {
    switch (this) {
      case ScheduleCategory.kerja:
        return 'Kerja';
      case ScheduleCategory.kuliah:
        return 'Kuliah';
      case ScheduleCategory.liburan:
        return 'Liburan';
    }
  }

  IconData get icon {
    switch (this) {
      case ScheduleCategory.kerja:
        return Icons.work_outline_rounded;
      case ScheduleCategory.kuliah:
        return Icons.school_outlined;
      case ScheduleCategory.liburan:
        return Icons.beach_access_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ScheduleCategory.kerja:
        return const Color(0xFF0F766E);
      case ScheduleCategory.kuliah:
        return const Color(0xFF1D4ED8);
      case ScheduleCategory.liburan:
        return const Color(0xFFEA580C);
    }
  }
}

ScheduleCategory scheduleCategoryFromValue(String value) {
  switch (value.toLowerCase()) {
    case 'kerja':
      return ScheduleCategory.kerja;
    case 'kuliah':
      return ScheduleCategory.kuliah;
    case 'liburan':
      return ScheduleCategory.liburan;
    default:
      throw ArgumentError('Kategori tidak dikenal: $value');
  }
}

class ScheduleDraft {
  const ScheduleDraft({
    required this.title,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.notes,
  });

  final String title;
  final ScheduleCategory category;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String location;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title.trim(),
      'category': category.value,
      'schedule_date': formatDate(date),
      'start_time': normalizeTime(startTime),
      'end_time': normalizeTime(endTime),
      'location': location.trim(),
      'notes': notes.trim(),
    };
  }
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.notes,
  });

  final int id;
  final String title;
  final ScheduleCategory category;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String location;
  final String notes;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: int.parse(json['id'].toString()),
      title: json['title'] as String? ?? '',
      category: scheduleCategoryFromValue(json['category'] as String? ?? ''),
      date: DateTime.parse(json['schedule_date'] as String? ?? ''),
      startTime: normalizeTime(json['start_time'] as String? ?? ''),
      endTime: normalizeTime(json['end_time'] as String? ?? ''),
      location: json['location'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  ScheduleDraft toDraft() {
    return ScheduleDraft(
      title: title,
      category: category,
      date: date,
      startTime: startTime,
      endTime: endTime,
      location: location,
      notes: notes,
    );
  }

  String get timeRangeLabel =>
      '${displayTime(startTime)} - ${displayTime(endTime)}';

  String get dateLabel {
    final DateTime localDate = DateTime(date.year, date.month, date.day);
    return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
  }
}

String formatDate(DateTime date) {
  final DateTime value = DateTime(date.year, date.month, date.day);
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String normalizeTime(String value) {
  final List<String> parts = value.split(':');
  if (parts.length < 2) {
    return value;
  }

  final String hour = parts[0].padLeft(2, '0');
  final String minute = parts[1].padLeft(2, '0');
  return '$hour:$minute:00';
}

String displayTime(String value) {
  final List<String> parts = normalizeTime(value).split(':');
  return '${parts[0]}:${parts[1]}';
}
