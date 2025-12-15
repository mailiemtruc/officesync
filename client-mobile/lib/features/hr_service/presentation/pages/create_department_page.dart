import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
// Đảm bảo import đúng đường dẫn tới các trang chọn
import 'select_manager_page.dart';
import 'add_members_page.dart';

class CreateDepartmentPage extends StatefulWidget {
  const CreateDepartmentPage({super.key});

  @override
  State<CreateDepartmentPage> createState() => _CreateDepartmentPageState();
}

class _CreateDepartmentPageState extends State<CreateDepartmentPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  // Biến lưu trữ dữ liệu được chọn
  Employee? _selectedManager;
  List<Employee> _selectedMembers = [];

  // Hàm mở trang chọn Manager
  Future<void> _pickManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectManagerPage(selectedId: _selectedManager?.id),
      ),
    );

    if (result != null && result is Employee) {
      setState(() {
        _selectedManager = result;
      });
    }
  }

  // Hàm mở trang thêm thành viên
  Future<void> _pickMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMembersPage(alreadySelectedMembers: _selectedMembers),
      ),
    );

    if (result != null && result is List<Employee>) {
      setState(() {
        _selectedMembers = result;
      });
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  _buildHeader(context),
                  const SizedBox(height: 32),

                  // 2. Department Icon (Đã sửa: Không viền, Bóng 0.1)
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF), // Tím nhạt
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.1,
                            ), // Bóng đậm 0.1
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                        size: 50,
                        color: const Color(0xFFD946EF), // Tím đậm
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
                          label: 'Department Name',
                          hint: 'e.g. Marketing',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          label: 'Dept Code',
                          hint: 'Auto (DEP-XXX)',
                          controller: _codeController,
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Leadership (Manager Selection)
                  _buildSectionTitle('LEADERSHIP'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickManager,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _buildBlockDecoration(),
                      child: Row(
                        children: [
                          if (_selectedManager == null) ...[
                            // State: Chưa chọn
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Select Employee',
                              style: TextStyle(
                                color: Color(0xFF9B9292),
                                fontSize: 16,
                              ),
                            ),
                          ] else ...[
                            // State: Đã chọn
                            ClipOval(
                              child: Image.network(
                                _selectedManager!.imageUrl,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedManager!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${_selectedManager!.id}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFFBDC6DE),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Initial Members (Đã sửa: Thêm icon dấu cộng +)
                  _buildSectionTitle('INITIAL MEMBERS'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickMembers,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _buildBlockDecoration(),
                      child: Row(
                        children: [
                          // --- Icon Dấu Cộng (+) ---
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF), // Nền xanh rất nhạt
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorIcons.plus(PhosphorIconsStyle.bold),
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // --- Nội dung Text ---
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add Members',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedMembers.isEmpty
                                      ? 'Select from existing employee list'
                                      : '${_selectedMembers.length} members selected',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                  ),
                                ),

                                // Nếu đã chọn thành viên -> Hiện Face Pile nhỏ bên dưới
                                if (_selectedMembers.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 30,
                                    child: Stack(
                                      children: List.generate(
                                        _selectedMembers.length > 5
                                            ? 5
                                            : _selectedMembers.length,
                                        (index) => Positioned(
                                          left: index * 20.0,
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                  _selectedMembers[index]
                                                      .imageUrl,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // --- Mũi tên hướng phải ---
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFFBDC6DE),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 6. Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Submit Data Logic
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
                        'Create Department',
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

  // --- Helper Widgets ---
  Widget _buildHeader(BuildContext context) {
    return Row(
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
              'CREATE DEPARTMENT',
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
      ),
    );
  }

  // Style cho các khối thông tin (Bóng nhẹ 0.05)
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

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool enabled = true,
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
            textAlign: TextAlign.end,
            style: TextStyle(
              color: enabled ? Colors.black : const Color(0xFFBDC6DE),
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
            ),
          ),
        ),
      ],
    );
  }
}
