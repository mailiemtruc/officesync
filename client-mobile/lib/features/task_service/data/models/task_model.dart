import 'package:flutter/material.dart';

enum TaskStatus { TODO, IN_PROGRESS, REVIEW, DONE }

enum TaskPriority { LOW, MEDIUM, HIGH }

class TaskModel {
  final int? id;
  final String title;
  final String description;
  final int? assigneeId;
  final String? creatorName;
  final String? assigneeName;
  final int? creatorId;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final int? departmentId;
  final int? companyId;
  final bool isPublished;
  final DateTime createdAt;
  final String? departmentName;

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    this.assigneeId,
    this.creatorName,
    this.assigneeName,
    this.creatorId,
    required this.dueDate,
    this.status = TaskStatus.TODO,
    this.priority = TaskPriority.MEDIUM,
    this.departmentId,
    this.companyId,
    this.isPublished = false,
    this.departmentName,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    TaskStatus parseStatus(String? s) {
      if (s == null) return TaskStatus.TODO;
      return TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == s,
        orElse: () => TaskStatus.TODO,
      );
    }

    TaskPriority parsePriority(String? p) {
      if (p == null) return TaskPriority.MEDIUM;
      return TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == p,
        orElse: () => TaskPriority.MEDIUM,
      );
    }

    return TaskModel(
      id: json['id'] is int ? json['id'] : (json['id'] as num?)?.toInt(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assigneeId:
          json['assigneeId'] ?? json['assignee_id'], // Hỗ trợ cả 2 định dạng
      assigneeName: json['assigneeName'] ?? json['assignee_name'],

      creatorId: (json['creatorId'] ?? json['creator_id']) != null
          ? int.parse((json['creatorId'] ?? json['creator_id']).toString())
          : null,

      // SỬA TẠI ĐÂY: Hỗ trợ creatorName và creator_name
      creatorName: json['creatorName'] ?? json['creator_name'],

      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      status: parseStatus(json['status']),
      priority: parsePriority(json['priority']),
      departmentId: json['departmentId'] ?? json['department_id'],
      companyId: json['companyId'] ?? json['company_id'],
      isPublished: json['isPublished'] ?? json['is_published'] ?? false,
      departmentName: json['departmentName'] ?? json['department_name'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'assigneeId': assigneeId,
      'departmentId': departmentId,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'companyId': companyId,
    };
  }

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.HIGH:
        return const Color(0xFFDC2626);
      case TaskPriority.MEDIUM:
        return const Color(0xFFF97316);
      case TaskPriority.LOW:
        return const Color(0xFF16A34A);
    }
  }

  Color get statusColor {
    switch (status) {
      case TaskStatus.TODO:
        return const Color(0xFF2260FF);
      case TaskStatus.IN_PROGRESS:
        return const Color(0xFFFFA322);
      case TaskStatus.DONE:
        return const Color(0xFF4EE375);
      default:
        return const Color(0xFF64748B);
    }
  }

  String get statusText =>
      status.toString().split('.').last.replaceAll('_', ' ');
  //lấy text của Priority để hiển thị trên Tag
  String get priorityText => priority.toString().split('.').last;
}
