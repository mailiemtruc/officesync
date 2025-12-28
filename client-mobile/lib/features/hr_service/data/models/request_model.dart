import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Enum phải khớp string với Backend (RequestStatus.java, RequestType.java)
enum RequestStatus { PENDING, APPROVED, REJECTED, CANCELLED }

enum RequestType { ANNUAL_LEAVE, OVERTIME, LATE_ARRIVAL, EARLY_DEPARTURE }

class RequestModel {
  final int? id; // Backend là Long -> Dart là int
  final String? requestCode;
  final RequestType type;
  final RequestStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final double? durationVal;
  final String? durationUnit;
  final String reason;
  final String? rejectReason;
  // Có thể thêm requesterName nếu Backend trả về nested object

  RequestModel({
    this.id,
    this.requestCode,
    required this.type,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.durationVal,
    this.durationUnit,
    required this.reason,
    this.rejectReason,
  });

  // --- 1. FROM JSON (Nhận từ Backend) ---
  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'],
      requestCode: json['requestCode'] ?? '',
      // Map String sang Enum
      type: _parseType(json['type']),
      status: _parseStatus(json['status']),
      // Parse ISO Date String
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationVal: (json['durationVal'] as num?)?.toDouble(),
      durationUnit: json['durationUnit'],
      reason: json['reason'] ?? '',
      rejectReason: json['rejectReason'],
    );
  }

  // --- 2. TO JSON (Gửi đi Backend) ---
  Map<String, dynamic> toJson() {
    return {
      'type': type.name, // "ANNUAL_LEAVE"
      'status': status.name, // "PENDING"
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'reason': reason,
      'durationVal': durationVal,
      'durationUnit': durationUnit,
    };
  }

  // --- HELPERS PARSE ENUM ---
  static RequestType _parseType(String? typeStr) {
    return RequestType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => RequestType.ANNUAL_LEAVE,
    );
  }

  static RequestStatus _parseStatus(String? statusStr) {
    return RequestStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => RequestStatus.PENDING,
    );
  }

  // --- UI GETTERS (Giữ lại để tương thích UI cũ của bạn) ---

  // Title hiển thị đẹp
  String get title {
    switch (type) {
      case RequestType.ANNUAL_LEAVE:
        return 'Annual Leave';
      case RequestType.OVERTIME:
        return 'Overtime';
      case RequestType.LATE_ARRIVAL:
        return 'Late Arrival';
      case RequestType.EARLY_DEPARTURE:
        return 'Early Departure';
    }
  }

  // Description (Lấy từ reason)
  String get description => reason;

  // DateRange (Format lại từ startTime - endTime)
  String get dateRange {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    if (type == RequestType.ANNUAL_LEAVE) {
      return '${dateFormat.format(startTime)} - ${dateFormat.format(endTime)}';
    } else {
      // Overtime/Late: Hiện ngày + giờ
      return '${dateFormat.format(startTime)} • ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}';
    }
  }

  // Duration text
  String get duration =>
      '${durationVal ?? 0} ${durationUnit?.toLowerCase() ?? 'hours'}';

  // Màu sắc (Giữ nguyên logic của bạn)
  Color get statusColor {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFF97316);
      case RequestStatus.APPROVED:
        return const Color(0xFF16A34A);
      case RequestStatus.REJECTED:
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  Color get statusBgColor {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFFFF7ED);
      case RequestStatus.APPROVED:
        return const Color(0xFFF0FDF4);
      case RequestStatus.REJECTED:
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String get statusText => status.name; // "PENDING", "APPROVED"...
}
