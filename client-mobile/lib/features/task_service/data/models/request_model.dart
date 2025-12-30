// features/hr_service/data/models/request_model.dart
import 'package:flutter/material.dart';

enum RequestType { leave, overtime, lateEarly, other }
enum RequestStatus { pending, approved, rejected }

class RequestModel {
  final String id;
  final String title;
  final String description;
  final RequestType type;
  final DateTime createdAt; 
  final RequestStatus status;
  // Thêm các trường này nếu cần dùng, nếu không thì bỏ qua trong code gọi
  final DateTime? startDate; 
  final DateTime? endDate;

  RequestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.status = RequestStatus.pending,
    this.startDate,
    this.endDate,
  });
}