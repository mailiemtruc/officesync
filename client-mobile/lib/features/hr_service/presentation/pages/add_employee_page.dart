import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// --- IMPORT PATHS ---
import '../../data/datasources/employee_remote_data_source.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../data/models/department_model.dart';
import '../../../../core/config/app_colors.dart';
import '../../widgets/selection_bottom_sheet.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  // 1. Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  late TextEditingController _passwordController;

  // 2. State Variables
  DepartmentModel? _selectedDepartment;
  String? _selectedRole;
  bool _isLoading = false;

  // Danh sách phòng ban lấy từ API
  List<DepartmentModel> _departments = [];

  // Repository & Storage
  late final EmployeeRepository _employeeRepository;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: "Abc123@ejk");

    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final depts = await _employeeRepository.getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
        });
      }
    } catch (e) {
      print("Error fetching departments: $e");
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id'].toString();
      }
    } catch (e) {
      print("Error reading user info: $e");
    }
    return null;
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

  // Tìm hàm cũ và thay thế bằng hàm này
  void _generateRandomPassword() {
    final random = Random();
    const length = 10; // Độ dài mật khẩu (lớn hơn 8)

    // Các bộ ký tự
    const upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '@#_-.!';

    // 1. Đảm bảo mỗi loại có ít nhất 1 ký tự
    String chars = '';
    chars += upperCase[random.nextInt(upperCase.length)];
    chars += lowerCase[random.nextInt(lowerCase.length)];
    chars += numbers[random.nextInt(numbers.length)];
    chars += specialChars[random.nextInt(specialChars.length)];

    // 2. Điền nốt các ký tự còn lại ngẫu nhiên từ tất cả các bộ
    const allChars = upperCase + lowerCase + numbers + specialChars;
    for (int i = 4; i < length; i++) {
      chars += allChars[random.nextInt(allChars.length)];
    }

    // 3. Trộn ngẫu nhiên vị trí các ký tự để không theo quy luật cố định
    List<String> charList = chars.split('');
    charList.shuffle(random);
    String password = charList.join('');

    setState(() {
      _passwordController.text = password;
    });
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
        _dobController.text = DateFormat("dd/MM/yyyy").format(picked);
      });
    }
  }

  // --- LOGIC CHÍNH ---
  // --- LOGIC CHÍNH ---
  Future<void> _handleCreateEmployee() async {
    // 1. Kiểm tra validation
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedRole == null ||
        _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("Session expired. Please login again.");
      }

      String formattedDob = "";
      if (_dobController.text.isNotEmpty) {
        try {
          DateTime parsedDate = DateFormat(
            "dd/MM/yyyy",
          ).parse(_dobController.text);
          formattedDob = DateFormat("yyyy-MM-dd").format(parsedDate);
        } catch (e) {
          print("Date parse error: $e");
        }
      }

      final success = await _employeeRepository.createEmployee(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: formattedDob,
        role: _selectedRole?.toUpperCase() ?? "STAFF",
        departmentId: _selectedDepartment!.id!,
        currentUserId: currentUserId,
        password: _passwordController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // [LOGIC MỚI] Xử lý thông báo lỗi từ Backend cho dễ đọc
        String errorMessage = e.toString();

        // Backend thường trả về: Exception: Server Error: {"timestamp":..., "message":"Email đã tồn tại", ...}
        // Ta cần lấy cái "message" bên trong đó.
        if (errorMessage.contains("Server Error:")) {
          try {
            // Lấy phần JSON sau chữ "Server Error:"
            final String jsonPart = errorMessage
                .split("Server Error:")[1]
                .trim();
            final Map<String, dynamic> errorMap = jsonDecode(jsonPart);

            // Nếu có trường 'message', dùng nó làm thông báo
            if (errorMap.containsKey('message')) {
              errorMessage = errorMap['message'];
            }
          } catch (_) {
            // Nếu không parse được JSON thì giữ nguyên, chỉ xóa chữ Exception
            errorMessage = errorMessage
                .replaceAll("Exception: ", "")
                .replaceAll("Server Error: ", "");
          }
        } else {
          errorMessage = errorMessage.replaceAll("Exception: ", "");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), // Hiển thị thông báo sạch đẹp
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI HELPER ---
  void _showDepartmentSelector() {
    if (_departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading departments or no data available...'),
        ),
      );
      _fetchDepartments();
      return;
    }

    final List<Map<String, String>> deptItems = _departments
        .map(
          (dept) => {
            'id': dept.id
                .toString(), // id có thể null nhưng lấy từ API về thì ko null
            'title': dept.name,
            'desc': dept.code ?? '',
          },
        )
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionBottomSheet(
        title: 'Select Department',
        items: deptItems,
        selectedId: _selectedDepartment?.id.toString(),
        onSelected: (idStr) {
          final selectedDept = _departments.firstWhere(
            (d) => d.id.toString() == idStr,
          );
          setState(() => _selectedDepartment = selectedDept);
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
            'desc': 'Submit requests, track tasks.',
          },
          {
            'id': 'Manager',
            'title': 'Manager',
            'desc': 'Approve requests, manage members.',
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
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tìm đoạn code UI phần Password và thay thế TextField bằng đoạn này:
                                    SizedBox(
                                      width: 180,
                                      child: TextField(
                                        controller: _passwordController,
                                        textAlign: TextAlign.end,
                                        readOnly: false, // Cho phép nhập tay
                                        // 1. Style cho MẬT KHẨU NHẬP VÀO (Xanh + Đậm)
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                        ),

                                        decoration: const InputDecoration(
                                          hintText: 'Enter password',

                                          // 2. Style cho CHỮ GỢI Ý (Enter password)
                                          // Đã chỉnh lên w500 để đậm hơn, giống với trường Email
                                          hintStyle: TextStyle(
                                            color: Color(0xFFBDC6DE),
                                            fontSize: 16,
                                            fontWeight: FontWeight
                                                .w500, // Tăng độ đậm lên Medium
                                            fontFamily: 'Inter',
                                          ),

                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionTitle('ORGANIZATION'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _buildBlockDecoration(),
                        child: Column(
                          children: [
                            _buildSelectorItem(
                              label: 'Department',
                              value: _selectedDepartment?.name ?? 'Select Dept',
                              isPlaceholder: _selectedDepartment == null,
                              onTap: _showDepartmentSelector,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
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

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleCreateEmployee,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

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
                color: Color(0xFFBDC6DE),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
