import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';

class EmployeeProfilePage extends StatelessWidget {
  final Employee employee;

  const EmployeeProfilePage({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    // Mock data cho các trường chưa có trong model
    final String email =
        "${employee.name.replaceAll(' ', '').toLowerCase()}@company.com";
    final String phone = "0909 123 456";
    final String dob = "01/01/1995";

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Màu nền xám nhạt chuẩn
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'EMPLOYEE PROFILE',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // 1. Header Section (Avatar + Name)
                  _buildHeader(employee),

                  const SizedBox(height: 32),

                  // 2. Info Section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.1,
                          ), // Bóng nhẹ cho khối thông tin
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFECF1FF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: PhosphorIcons.envelopeSimple(),
                            label: 'Email',
                            value: email,
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.phone(),
                            label: 'Phone',
                            value: phone,
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.buildings(),
                            label: 'Department',
                            value: employee.department.isNotEmpty
                                ? employee.department
                                : "Unassigned",
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.identificationCard(),
                            label: 'Employee ID',
                            value: employee.id,
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.calendarBlank(),
                            label: 'Date of Birth',
                            value: dob,
                          ),
                          const SizedBox(height: 24),
                          // Thêm trạng thái tài khoản
                          _InfoRow(
                            icon: PhosphorIcons.lockKey(),
                            label: 'Account Status',
                            value: employee.isLocked ? 'Locked' : 'Active',
                            valueColor: employee.isLocked
                                ? Colors.red
                                : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Employee employee) {
    return Column(
      children: [
        // Avatar Container (ĐÃ SỬA: Không viền, bóng 0.1)
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Đã xóa dòng border: Border.all(...)
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Độ mờ bóng là 0.1
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              employee.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.person, size: 60, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          employee.name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          employee.role.isNotEmpty ? employee.role : "Staff",
          style: const TextStyle(
            color: Color(0xFF6A6A6A),
            fontSize: 15,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF404040), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF909090),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.black,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
