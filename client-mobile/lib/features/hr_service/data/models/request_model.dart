import 'package:flutter/material.dart';

enum RequestStatus { pending, approved, rejected }

enum RequestType { leave, overtime, lateEarly }

class RequestModel {
  final String id;
  final RequestType type;
  final String title;
  final String description;
  final String dateRange;
  final String duration;
  final RequestStatus status;

  RequestModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.dateRange,
    required this.duration,
    required this.status,
  });

  // Helper để lấy màu sắc theo trạng thái
  Color get statusColor {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFF97316); // Cam
      case RequestStatus.approved:
        return const Color(0xFF16A34A); // Xanh lá
      case RequestStatus.rejected:
        return const Color(0xFFDC2626); // Đỏ
    }
  }

  // Helper để lấy màu nền nhạt theo trạng thái
  Color get statusBgColor {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFFFF7ED);
      case RequestStatus.approved:
        return const Color(0xFFF0FDF4);
      case RequestStatus.rejected:
        return const Color(0xFFFEF2F2);
    }
  }

  String get statusText {
    switch (status) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
    }
  }
}
