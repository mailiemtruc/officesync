import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import 'package:intl/intl.dart';

class EmployeeProfilePage extends StatelessWidget {
  final EmployeeModel employee;

  const EmployeeProfilePage({super.key, required this.employee});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              // Cập nhật padding để khớp với UserProfilePage
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      const Expanded(
                        child: Text(
                          'EMPLOYEE PROFILE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildHeader(employee),
                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                            value: employee.email,
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.phone(),
                            label: 'Phone',
                            value: employee.phone.isEmpty
                                ? "N/A"
                                : employee.phone,
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.buildings(),
                            label: 'Department',
                            value: employee.departmentName ?? "Unassigned",
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.identificationCard(),
                            label: 'Employee ID',
                            value: employee.employeeCode ?? "N/A",
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.calendarBlank(),
                            label: 'Date of Birth',
                            value: _formatDate(employee.dateOfBirth),
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: PhosphorIcons.lockKey(),
                            label: 'Account Status',
                            value: (employee.status == "LOCKED")
                                ? 'Locked'
                                : 'Active',
                            valueColor: (employee.status == "LOCKED")
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

  Widget _buildHeader(EmployeeModel employee) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child:
                (employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty)
                ? Image.network(
                    employee.avatarUrl!,
                    fit: BoxFit.cover,

                    errorBuilder: (_, __, ___) => Icon(
                      PhosphorIcons.user(PhosphorIconsStyle.fill),
                      size: 60,
                      color: Colors.grey,
                    ),
                  )
                : Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.fill),
                    size: 60,
                    color: Colors.grey,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          employee.fullName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          employee.role ?? "Staff",
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
