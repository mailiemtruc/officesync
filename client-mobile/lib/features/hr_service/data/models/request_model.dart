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

  // [QUAN TRỌNG] Thêm trường này để hết lỗi đỏ bên trang Detail
  final String? evidenceUrl;
  // [MỚI] Thêm trường này để hứng ngày tạo đơn từ Backend
  final DateTime? createdAt;
  // [MỚI] Thêm các field thông tin người gửi đơn
  final String requesterName;
  final String requesterId; // ID nhân viên
  final String requesterAvatar;
  final String requesterDept;
  // [MỚI] Thêm các trường này
  final String? approverName;
  final DateTime? updatedAt;
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
    this.evidenceUrl,
    this.createdAt,
    this.requesterName = 'Unknown',
    this.requesterId = '',
    this.requesterAvatar = '',
    this.requesterDept = '',
    this.approverName,
    this.updatedAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    // [LOGIC MỚI] Bóc tách thông tin người gửi từ object lồng nhau 'requester'
    String rName = 'Unknown';
    String rId = '';
    String rAvatar = '';
    String rDept = '';

    if (json['requester'] != null) {
      final r = json['requester'];
      rName = r['fullName'] ?? 'Unknown';
      rId = r['employeeCode'] ?? r['id']?.toString() ?? '';
      rAvatar = r['avatarUrl'] ?? '';

      // Lấy tên phòng ban từ object lồng requester -> department
      if (r['department'] != null) {
        rDept = r['department']['name'] ?? '';
      }
    }
    // [MỚI] Bóc tách thông tin người duyệt (approver)
    String? appName;
    if (json['approver'] != null) {
      appName = json['approver']['fullName'];
    }

    return RequestModel(
      id: json['id'],
      requestCode: json['requestCode'] ?? '',
      type: _parseType(json['type']),
      status: _parseStatus(json['status']),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationVal: (json['durationVal'] as num?)?.toDouble(),
      durationUnit: json['durationUnit'],
      reason: json['reason'] ?? '',
      rejectReason: json['rejectReason'],
      evidenceUrl: json['evidenceUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,

      // Gán dữ liệu vừa bóc tách
      requesterName: rName,
      requesterId: rId,
      requesterAvatar: rAvatar,
      requesterDept: rDept,
      // [MỚI] Map dữ liệu vào
      approverName: appName,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
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
      'evidenceUrl': evidenceUrl, // [MỚI]
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
