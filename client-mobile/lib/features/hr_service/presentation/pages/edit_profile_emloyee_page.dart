import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../widgets/confirm_bottom_sheet.dart';

class EditProfileEmployeePage extends StatefulWidget {
  const EditProfileEmployeePage({super.key});

  @override
  State<EditProfileEmployeePage> createState() =>
      _EditProfileEmployeePageState();
}

class _EditProfileEmployeePageState extends State<EditProfileEmployeePage> {
  // Biến trạng thái
  bool _isActive = true;
  String _selectedDepartment = 'Business';
  String _selectedRole = 'Manager';

  // Controller cho Email để có thể chỉnh sửa
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    // Khởi tạo giá trị ban đầu cho email
    _emailController = TextEditingController(text: 'nguyenvana@gmail.com');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Hàm hiển thị BottomSheet xác nhận XÓA
  void _showDeleteConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Delete this account?',
        message:
            'This action cannot be undone. All data associated with employee Nguyen Van A will be permanently deleted.',
        confirmText: 'Delete',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Hàm hiển thị BottomSheet xác nhận CHẶN (SUSPEND)
  void _showSuspendConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Suspend Access?',
        message:
            'Employee Nguyen Van A will not be able to log in to the system until you reactivate their account.',
        confirmText: 'Suspend',
        confirmColor: const Color(0xFFF97316),
        onConfirm: () {
          setState(() => _isActive = false);
          Navigator.pop(context);
        },
        onCancel: () {
          setState(() => _isActive = true);
        },
      ),
    );
  }

  // --- STYLE CHUNG CHO CÁC KHỐI (Có đổ bóng 0.1) ---
  BoxDecoration _buildBlockDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFECF1FF)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05), // Đổ bóng 0.1 theo yêu cầu
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 1. Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'EDIT EMPLOYEE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Avatar Circle (Đã bỏ biểu tượng Camera)
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        "https://i.pravatar.cc/300?img=11",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[300]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Name & ID
                  const Text(
                    'Nguyen Van A',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'EMPLOYEE ID: 001',
                    style: TextStyle(
                      color: Color(0xFF6A6A6A),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 4. Form Fields - Section 1
                  _buildSectionTitle('ACCOUNT SETTINGS'),
                  const SizedBox(height: 12),

                  // Email Field (Đã chỉnh sửa để Edit được)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration:
                        _buildBlockDecoration(), // Sử dụng hàm style có bóng
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.envelopeSimple(),
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            // TextFormField thay cho Text tĩnh
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  labelText: "Email",
                                  labelStyle: TextStyle(
                                    color: Color(0xFF0C28B3),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder
                                      .none, // Bỏ viền mặc định của input
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEFFD2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFA16207),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Changing email will update login credentials.",
                                  style: TextStyle(
                                    color: Color(0xFFA16207),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('ROLES & PERMISSIONS'),
                  const SizedBox(height: 12),

                  // Roles & Dept Container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration:
                        _buildBlockDecoration(), // Sử dụng hàm style có bóng
                    child: Column(
                      children: [
                        _buildDropdownRow(
                          label: 'Department',
                          value: _selectedDepartment,
                          items: ['Business', 'HR', 'Technical', 'Sales'],
                          onChanged: (val) =>
                              setState(() => _selectedDepartment = val!),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildDropdownRow(
                          label: 'Role',
                          value: _selectedRole,
                          items: ['Manager', 'Staff', 'Intern'],
                          onChanged: (val) =>
                              setState(() => _selectedRole = val!),
                          isBlueValue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('STATUS'),
                  const SizedBox(height: 12),

                  // Status Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration:
                        _buildBlockDecoration(), // Sử dụng hàm style có bóng
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Switch.adaptive(
                          value: _isActive,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (value) {
                            if (value == false) {
                              _showSuspendConfirmation(context);
                            } else {
                              setState(() => _isActive = true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Delete Button
                  TextButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // In ra email để kiểm tra
                        print("New Email: ${_emailController.text}");
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Save changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF655F5F),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isBlueValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xE5706060),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.chevron_right, color: Colors.grey),
              style: TextStyle(
                color: isBlueValue ? AppColors.primary : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
