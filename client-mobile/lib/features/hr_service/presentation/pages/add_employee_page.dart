import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math'; // Import thư viện để random mật khẩu
import '../../../../core/config/app_colors.dart';
import '../../widgets/selection_bottom_sheet.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  // Thêm controller cho Password
  late TextEditingController _passwordController;

  String? _selectedDepartment;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    // Khởi tạo mật khẩu mặc định
    _passwordController = TextEditingController(text: "123456");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hàm tạo mật khẩu ngẫu nhiên (6 số)
  void _generateRandomPassword() {
    var rng = Random();
    var code = rng.nextInt(900000) + 100000; // Random từ 100000 -> 999999
    setState(() {
      _passwordController.text = code.toString();
    });
  }

  // ... (Các hàm _showDepartmentSelector, _showRoleSelector, _selectDate giữ nguyên)
  void _showDepartmentSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionBottomSheet(
        title: 'Select Department',
        items: const [
          {
            'id': 'Sales',
            'title': 'Sales & Marketing',
            'desc': 'Focus on revenue & branding',
          },
          {
            'id': 'HR',
            'title': 'Human Resources (HR)',
            'desc': 'Recruitment & Employee welfare',
          },
          {
            'id': 'IT',
            'title': 'IT & Technology',
            'desc': 'System admin & Development',
          },
        ],
        selectedId: _selectedDepartment,
        onSelected: (id) {
          setState(() => _selectedDepartment = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRoleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionBottomSheet(
        title: 'Assign Role',
        items: const [
          {
            'id': 'Staff',
            'title': 'Staff',
            'desc': 'Submit requests, track tasks, and view internal news.',
          },
          {
            'id': 'Manager',
            'title': 'Manager',
            'desc': 'Approve requests, assign tasks, and manage members.',
          },
        ],
        selectedId: _selectedRole,
        onSelected: (id) {
          setState(() => _selectedRole = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  BoxDecoration _buildBlockDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFECF1FF)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                          color: AppColors.primary,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'ADD EMPLOYEE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
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

                  // 2. Avatar Placeholder
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD8DEEC),
                          width: 2,
                        ),
                        color: const Color(0xFFE2E8F0),
                        // --- THÊM ĐỔ BÓNG TẠI ĐÂY ---
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.1,
                            ), // Độ mờ 0.1 như bạn muốn
                            blurRadius:
                                10, // Độ lan của bóng (càng lớn bóng càng mềm)
                            offset: const Offset(
                              0,
                              5,
                            ), // Đổ bóng lệch xuống dưới một chút
                          ),
                        ],
                        // -----------------------------
                      ),
                      child: ClipOval(
                        child: Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.fill),
                          size: 60,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 3. Basic Information
                  _buildSectionTitle('BASIC INFORMATION'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      children: [
                        _buildTextField(
                          label: 'Full Name',
                          hint: 'e.g. John Doe',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          label: 'Employee ID',
                          hint: 'Auto (EMP-XXX)',
                          enabled: false,
                          textColor: const Color(0xFFBDC6DE),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          label: 'Phone',
                          hint: 'Enter phone number',
                          controller: _phoneController,
                          inputType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _selectDate,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              label: 'Date of Birth',
                              hint: 'DD / MM / YYYY',
                              controller: _dobController,
                              icon: PhosphorIcons.calendarBlank(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Account & Login
                  _buildSectionTitle('ACCOUNT & LOGIN'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Email',
                          hint: 'email@company.com',
                          controller: _emailController,
                          inputType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // --- SỬA LẠI: PASSWORD CÓ THỂ NHẬP TAY + NÚT ICON ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            // Container chứa Input + Icon
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Input nhập tay
                                SizedBox(
                                  width: 120, // Độ rộng vừa phải cho password
                                  child: TextField(
                                    controller: _passwordController,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: AppColors.primary, // Màu xanh
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      fontFamily: 'Inter',
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      hintText: '......',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Nút Icon Refresh riêng biệt
                                InkWell(
                                  onTap: _generateRandomPassword,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      PhosphorIcons.arrowsClockwise(
                                        PhosphorIconsStyle.regular,
                                      ),
                                      size: 20,
                                      color: const Color(0xFF9CA3AF), // Màu xám
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // ---------------------------------------------------
                        const SizedBox(height: 8),
                        const Text(
                          '*Default password is 123456. User must change it upon login.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Organization
                  _buildSectionTitle('ORGANIZATION'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      children: [
                        _buildSelectorItem(
                          label: 'Department',
                          value: _selectedDepartment ?? 'Select Dept',
                          isPlaceholder: _selectedDepartment == null,
                          onTap: _showDepartmentSelector,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildSelectorItem(
                          label: 'Role',
                          value: _selectedRole ?? 'Select Role',
                          isPlaceholder: _selectedRole == null,
                          onTap: _showRoleSelector,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 6. Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Handle Create Logic
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
                        'Create Employee',
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

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF655F5F),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool enabled = true,
    Color? textColor,
    IconData? icon,
    TextInputType? inputType,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: inputType,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor ?? Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFBDC6DE),
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              suffixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        icon,
                        size: 20,
                        color: const Color(0xFFBDC6DE),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                maxHeight: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorItem({
    required String label,
    required String value,
    required bool isPlaceholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isPlaceholder
                      ? const Color(0xFF9B9292)
                      : AppColors.primary,
                  fontSize: 16,
                  fontWeight: isPlaceholder ? FontWeight.w300 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFFBDC6DE), // Màu xám nhạt
              ),
            ],
          ),
        ],
      ),
    );
  }
}
