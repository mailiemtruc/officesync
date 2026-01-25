import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart'; // [MỚI] Import để dùng model
import '../../../../core/config/app_colors.dart';
import '../../widgets/selection_bottom_sheet.dart';
import '../../widgets/confirm_bottom_sheet.dart'; // [MỚI] Import ConfirmBottomSheet
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/department_repository_impl.dart';
import '../../domain/repositories/department_repository.dart';
import '../../../../core/utils/custom_snackbar.dart';

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

  // [MỚI] Biến kiểm tra quyền hạn
  bool _isManager = false;
  String? _currentUserId;

  // Danh sách phòng ban lấy từ API
  List<DepartmentModel> _departments = [];

  // Repository & Storage
  late final EmployeeRepository _employeeRepository;
  late final DepartmentRepository _departmentRepository;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: "Abc123@ejk");

    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _departmentRepository = DepartmentRepositoryImpl(
      remoteDataSource: DepartmentRemoteDataSource(),
    );

    // [SỬA] Gọi hàm khởi tạo tích hợp kiểm tra quyền
    _initDataAndCheckPermissions();
  }

  // [LOGIC MỚI] Hàm khởi tạo và kiểm tra quyền
  Future<void> _initDataAndCheckPermissions() async {
    try {
      // 1. Lấy thông tin user từ Storage
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        _currentUserId = userMap['id'].toString(); // Lấy ID

        // Xác định Role
        String role = userMap['role'] ?? "STAFF";
        if (role.toUpperCase() == 'MANAGER') {
          setState(() {
            _isManager = true;
            _selectedRole = 'Staff';
          });
        }
      }

      // [QUAN TRỌNG] Kiểm tra null trước khi gọi API
      if (_currentUserId == null) {
        print("User ID not found, cannot fetch departments.");
        return;
      }

      // 2. Tải danh sách phòng ban (ĐÃ SỬA: Truyền _currentUserId vào)
      final depts = await _employeeRepository.getDepartments(_currentUserId!);

      if (mounted) {
        setState(() {
          _departments = depts;
        });

        // 3. Logic Manager tự chọn phòng (Giữ nguyên)
        if (_isManager) {
          try {
            final myDept = depts.firstWhere(
              (d) => d.manager?.id == _currentUserId,
            );
            setState(() {
              _selectedDepartment = myDept;
            });
          } catch (e) {
            print("Manager $_currentUserId has no department assigned.");
          }
        }
      }
    } catch (e) {
      print("Error initializing data: $e");
    }
  }

  Future<String?> _getCurrentUserId() async {
    return _currentUserId;
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

  void _generateRandomPassword() {
    final random = Random();
    const length = 10;
    const upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '@#_-.!';

    String chars = '';
    chars += upperCase[random.nextInt(upperCase.length)];
    chars += lowerCase[random.nextInt(lowerCase.length)];
    chars += numbers[random.nextInt(numbers.length)];
    chars += specialChars[random.nextInt(specialChars.length)];

    const allChars = upperCase + lowerCase + numbers + specialChars;
    for (int i = 4; i < length; i++) {
      chars += allChars[random.nextInt(allChars.length)];
    }

    List<String> charList = chars.split('');
    charList.shuffle(random);
    String password = charList.join('');

    setState(() {
      _passwordController.text = password;
    });
  }

  // [CẬP NHẬT] Đồng bộ màu sắc DatePicker
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      // [THÊM] Builder chỉnh màu
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // Màu header & nút chọn
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, // Màu nút Cancel/OK
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat("dd/MM/yyyy").format(picked);
      });
    }
  }

  Future<void> _handleCreateEmployee() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final dob = _dobController.text.trim();

    // 1. Validate Empty
    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        dob.isEmpty ||
        _selectedRole == null ||
        _selectedDepartment == null) {
      _showErrorSnackBar('Please fill in all required fields.');
      return;
    }

    // 2. Validate Email
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(email)) {
      _showErrorSnackBar('Invalid email format. Example: user@company.com');
      return;
    }

    // 3. Validate Phone
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (!phoneRegex.hasMatch(phone)) {
      _showErrorSnackBar('Phone number must contain digits only (0-9).');
      return;
    }
    if (phone.length < 9 || phone.length > 15) {
      _showErrorSnackBar(
        'Phone number length must be between 9 and 15 digits.',
      );
      return;
    }

    // 4. Validate Password
    if (password.length < 8) {
      _showErrorSnackBar('Password must be at least 8 characters long.');
      return;
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showErrorSnackBar(
        'Password must contain at least one uppercase letter (A-Z).',
      );
      return;
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      _showErrorSnackBar(
        'Password must contain at least one lowercase letter (a-z).',
      );
      return;
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      _showErrorSnackBar('Password must contain at least one number (0-9).');
      return;
    }
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      _showErrorSnackBar(
        'Password must contain at least one special character (!@#...).',
      );
      return;
    }

    if (_currentUserId == null) {
      _showErrorSnackBar("Session expired. Please login again.");
      return;
    }

    // 5. Check Manager Assignment (ĐÃ SỬA LOGIC: Thay vì chặn -> Hỏi để thay thế)
    if (_selectedRole?.toUpperCase() == 'MANAGER' &&
        _selectedDepartment != null) {
      if (_selectedDepartment!.manager != null) {
        final currentManagerName =
            _selectedDepartment!.manager?.fullName ?? "Unknown";
        final oldManager = _selectedDepartment!.manager!;

        // Hiện Dialog xác nhận thay thế
        final bool? confirm = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => ConfirmBottomSheet(
            title: 'Replace Manager?',
            message:
                'Department "${_selectedDepartment!.name}" is currently managed by $currentManagerName.\n\nDo you want to demote $currentManagerName and assign the NEW employee as Manager?',
            confirmText: 'Replace',
            confirmColor: const Color(0xFFF97316),
            onConfirm: () {
              Navigator.pop(context, true);
            },
          ),
        );

        if (confirm != true) return; // Nếu không đồng ý thì dừng lại

        // [LOGIC GIÁNG CHỨC]
        // Thực hiện giáng chức ông quản lý cũ TRƯỚC khi tạo người mới
        setState(() => _isLoading = true);
        try {
          if (oldManager.id != null) {
            print("--> Demoting old manager: ${oldManager.fullName}");
            await _employeeRepository.updateEmployee(
              _currentUserId!,
              oldManager.id!,
              oldManager.fullName,
              oldManager.phone,
              oldManager.dateOfBirth,
              email: oldManager.email,
              avatarUrl: oldManager.avatarUrl,
              status: oldManager.status,
              role: 'STAFF', // Giáng xuống Staff
              departmentId: _selectedDepartment!.id,
            );
          }
        } catch (e) {
          setState(() => _isLoading = false);
          _showErrorSnackBar("Failed to demote old manager: $e");
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      String formattedDob = "";
      if (dob.isNotEmpty) {
        try {
          DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(dob);
          formattedDob = DateFormat("yyyy-MM-dd").format(parsedDate);
        } catch (e) {
          print("Date parse error: $e");
        }
      }

      // [CREATE NEW EMPLOYEE]
      final String? newEmployeeId = await _employeeRepository.createEmployee(
        fullName: fullName,
        email: email,
        phone: phone,
        dob: formattedDob,
        role: _selectedRole?.toUpperCase() ?? "STAFF",
        departmentId: _selectedDepartment!.id!,
        currentUserId: _currentUserId!,
        password: password,
      );

      // Nếu có ID trả về => Tạo thành công
      if (newEmployeeId != null) {
        // [TỰ ĐỘNG GÁN MANAGER]
        // Cập nhật lại Department để trỏ Manager về nhân viên mới tạo
        if (_selectedRole?.toUpperCase() == 'MANAGER' &&
            _selectedDepartment != null) {
          print(
            "--> Auto-assigning Manager ($newEmployeeId) to Dept ${_selectedDepartment!.name}",
          );

          await _departmentRepository.updateDepartment(
            _currentUserId!,
            _selectedDepartment!.id!,
            _selectedDepartment!.name,
            newEmployeeId, // Gán ID nhân viên mới làm Manager
            _selectedDepartment!.isHr,
          );
        }

        if (mounted) {
          CustomSnackBar.show(
            context,
            title: 'Success',
            message: 'Employee created successfully!',
            isError: false,
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Employee created but failed to retrieve ID.");
      }
    } catch (e) {
      if (mounted) {
        // 1. Loại bỏ prefix "Exception: " mặc định của Dart
        String errorMessage = e.toString().replaceAll("Exception: ", "");

        // 2. Tìm xem trong lỗi có chứa chuỗi JSON không (bắt đầu bằng { và kết thúc bằng })
        final int jsonStartIndex = errorMessage.indexOf('{');
        final int jsonEndIndex = errorMessage.lastIndexOf('}');

        if (jsonStartIndex != -1 &&
            jsonEndIndex != -1 &&
            jsonEndIndex > jsonStartIndex) {
          try {
            // 3. Cắt chuỗi JSON ra: {"message":"Email ... exists!"}
            final String jsonString = errorMessage.substring(
              jsonStartIndex,
              jsonEndIndex + 1,
            );

            // 4. Parse JSON
            final Map<String, dynamic> errorMap = jsonDecode(jsonString);

            // 5. Nếu có key 'message', lấy nó làm thông báo lỗi chính
            if (errorMap.containsKey('message') &&
                errorMap['message'] != null) {
              errorMessage = errorMap['message'];
            }
          } catch (_) {
            // Nếu cắt chuỗi hoặc parse JSON lỗi, giữ nguyên message gốc (đã xóa Exception:)
          }
        }

        if (errorMessage.contains("Failed to create employee:")) {
          errorMessage = errorMessage
              .replaceAll("Failed to create employee:", "")
              .trim();
        }

        // Hiển thị message đã được làm sạch
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    CustomSnackBar.show(
      context,
      title: 'Validation Error',
      message: message,
      isError: true,
    );
  }

  // --- UI HELPER ---
  void _showDepartmentSelector() {
    if (_isManager) return;

    // [SỬA] Kiểm tra nếu danh sách rỗng thì báo lỗi rõ ràng
    if (_departments.isEmpty) {
      CustomSnackBar.show(
        context,
        title: 'Missing Department', // Tiêu đề rõ ràng
        message:
            'No departments found. Please create a department first!', // Thông báo hướng dẫn
        isError: true, // Dùng màu đỏ cam báo động
      );

      // Thử tải lại dữ liệu ngầm (phòng trường hợp mạng lag chưa tải xong)
      _initDataAndCheckPermissions();
      return;
    }

    final List<Map<String, String>> deptItems = _departments
        .map(
          (dept) => {
            'id': dept.id.toString(),
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
    if (_isManager) return;

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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
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
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                            color: Colors.grey[200],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Icon(
                              PhosphorIcons.user(PhosphorIconsStyle.fill),
                              size: 60,
                              color: Colors.grey[400],
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
                                    SizedBox(
                                      width: 180,
                                      child: TextField(
                                        controller: _passwordController,
                                        textAlign: TextAlign.end,
                                        readOnly: false,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter password',
                                          hintStyle: TextStyle(
                                            color: Color(0xFFBDC6DE),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
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
                              onTap: _isManager
                                  ? null
                                  : _showDepartmentSelector,
                              isReadOnly: _isManager,
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
                              onTap: _isManager ? null : _showRoleSelector,
                              isReadOnly: _isManager,
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
    required VoidCallback? onTap, // Cho phép null
    bool isReadOnly = false, // Cờ báo chỉ xem
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
                  // Nếu read-only (Manager) thì hiện màu đen/xám, ngược lại màu Primary
                  color: isReadOnly
                      ? Colors.grey[700]
                      : (isPlaceholder
                            ? const Color(0xFF9B9292)
                            : AppColors.primary),
                  fontSize: 16,
                  fontWeight: isPlaceholder ? FontWeight.w300 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Nếu read-only -> Hiện icon ổ khóa, ngược lại hiện mũi tên
              Icon(
                isReadOnly
                    ? PhosphorIcons.lock(PhosphorIconsStyle.regular)
                    : Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xFFBDC6DE),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
