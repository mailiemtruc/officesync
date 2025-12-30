import 'package:flutter/material.dart';

enum TaskStatus { todo, in_progress, review, done }
enum TaskPriority { low, medium, high }

class TaskModel {
  final String? id;
  final String title;
  final String description;
  final String? assigneeId;
  final String? assigneeName; // Để hiển thị nhanh
  final String? creatorId;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    this.assigneeId,
    this.assigneeName,
    this.creatorId,
    required this.dueDate,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
  });

  // Helper hiển thị màu sắc theo Priority
  Color get priorityColor {
    switch (priority) {
      case TaskPriority.high:
        return const Color(0xFFDC2626); // Red
      case TaskPriority.medium:
        return const Color(0xFFF97316); // Orange
      case TaskPriority.low:
        return const Color(0xFF16A34A); // Green
    }
  }

  // Helper hiển thị màu sắc theo Status
  Color get statusColor {
    switch (status) {
      case TaskStatus.todo:
        return const Color(0xFF64748B); // Grey
      case TaskStatus.in_progress:
        return const Color(0xFF2563EB); // Blue
      case TaskStatus.review:
        return const Color(0xFFD97706); // Amber
      case TaskStatus.done:
        return const Color(0xFF10B981); // Green
    }
  }

  String get statusText {
    return status.name.replaceAll('_', ' ').toUpperCase();
  }
}