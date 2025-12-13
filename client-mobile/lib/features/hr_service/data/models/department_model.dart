import 'package:flutter/material.dart';

class Department {
  final String id;
  final String name;
  final String code;
  final String managerName;
  final String managerImageUrl; // Thêm trường này để hiện ảnh avatar
  final int memberCount;
  final Color themeColor;

  Department({
    required this.id,
    required this.name,
    required this.code,
    required this.managerName,
    required this.managerImageUrl, // Required
    required this.memberCount,
    required this.themeColor,
  });
}
