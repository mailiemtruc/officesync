import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui'; // Quan trọng: Để sửa lỗi PathMetric
import '../../../../core/config/app_colors.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  // 0: Leave, 1: Overtime, 2: Late/Early
  int _selectedTypeIndex = 0;
  // Tab phụ cho Late/Early (0: Arrive Late, 1: Leave Early)
  int _lateEarlyTypeIndex = 0;

  final TextEditingController _reasonController = TextEditingController();

  // Biến lưu trữ ngày giờ đã chọn
  DateTime? _fromDate;
  DateTime? _toDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Hàm chọn ngày
  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // Hàm chọn giờ
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // Helper format ngày
  String _formatDate(DateTime? date) {
    if (date == null) return 'dd/mm/yyyy';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper format giờ
  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
                  const SizedBox(height: 20),
                  // Header
                  _buildHeader(context, 'CREATE REQUEST'),
                  const SizedBox(height: 24),

                  // 1. Request Type Selector (Tabs có Icon + Hiệu ứng)
                  _buildSectionTitle('REQUEST TYPE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          title: 'Leave',
                          icon: PhosphorIcons.sun(PhosphorIconsStyle.regular),
                          index: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeButton(
                          title: 'Overtime',
                          icon: PhosphorIcons.clock(PhosphorIconsStyle.regular),
                          index: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeButton(
                          title: 'Late/Early',
                          icon: PhosphorIcons.lightning(
                            PhosphorIconsStyle.regular,
                          ),
                          index: 2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Nội dung thay đổi theo Tab
                  if (_selectedTypeIndex == 0) _buildLeaveBody(),
                  if (_selectedTypeIndex == 1) _buildOvertimeBody(),
                  if (_selectedTypeIndex == 2) _buildLateEarlyBody(),

                  const SizedBox(height: 24),

                  // 3. Lý do (Dùng chung)
                  _buildSectionTitle('REASON'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: _buildBlockDecoration(),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Why are you requesting this?',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Evidence (Upload Button - Dotted Border + Hiệu ứng)
                  _buildSectionTitle('EVIDENCE (OPTIONAL)'),
                  const SizedBox(height: 12),
                  // Khối Upload File
                  DottedBorder(
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(12),
                    dashPattern: const [6, 3], // Nét đứt
                    color: const Color(0xFFA1ACCC),
                    strokeWidth: 1,
                    child: Material(
                      color: const Color(0xFFF9FAFB), // Màu nền
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // TODO: Handle upload
                          print("Upload tapped");
                        },
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // --- ICON UPLOAD CHUẨN THIẾT KẾ ---
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white, // Nền trắng
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2260FF,
                                      ).withOpacity(0.15), // Bóng xanh nhạt
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  PhosphorIcons.uploadSimple(
                                    PhosphorIconsStyle.bold,
                                  ),
                                  color: AppColors.primary, // Icon xanh
                                  size: 24,
                                ),
                              ),
                              // ----------------------------------
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to upload File',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Image (JPG, PNG) or PDF',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 5. Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
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
                        'Submit Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Các Widget con cho từng loại form ---

  Widget _buildLeaveBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DURATION'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDateSelector('From Date', true)),
            const SizedBox(width: 12),
            Expanded(child: _buildDateSelector('To Date', false)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SEND TO'),
        const SizedBox(height: 12),
        _buildSendToBlock(),
      ],
    );
  }

  Widget _buildOvertimeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('OVERTIME SCHEDULE'),
        const SizedBox(height: 12),
        _buildDateSelector('Date', true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTimeSelector('Start Time', true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeSelector('End Time', false)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SEND TO'),
        const SizedBox(height: 12),
        _buildSendToBlock(),
      ],
    );
  }

  Widget _buildLateEarlyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ADJUSTMENT TYPE'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(child: _buildToggleOption('Arrive Late', 0)),
              Expanded(child: _buildToggleOption('Leave Early', 1)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildDateSelector('Date', true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeSelector('Actual Time', true)),
          ],
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  // Nút chọn loại (Tabs có Icon + Hiệu ứng)
  Widget _buildTypeButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    bool isSelected = _selectedTypeIndex == index;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFECF1FF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedTypeIndex = index),
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF64748B),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Input Date Selector (+ Hiệu ứng)
  Widget _buildDateSelector(String label, bool isFrom) {
    return Container(
      decoration: _buildBlockDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDate(context, isFrom),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(isFrom ? _fromDate : _toDate),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Icon(
                      PhosphorIcons.calendarBlank(),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Input Time Selector (+ Hiệu ứng)
  Widget _buildTimeSelector(String label, bool isStart) {
    return Container(
      decoration: _buildBlockDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectTime(context, isStart),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(isStart ? _startTime : _endTime),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Icon(
                      PhosphorIcons.clock(),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Toggle button Late/Early (+ Hiệu ứng)
  Widget _buildToggleOption(String text, int index) {
    bool isSelected = _lateEarlyTypeIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () => setState(() => _lateEarlyTypeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Block hiển thị người nhận (Send To) - ĐÃ SỬA ICON & MÀU SẮC CHUẨN
  Widget _buildSendToBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Icon Users màu xanh, nền trắng
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.usersThree(
                PhosphorIconsStyle.fill,
              ), // Icon nhóm người
              size: 20,
              color: const Color(0xFF2563EB), // Màu xanh dương chuẩn
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Human Resources Dept',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Approver',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          // Icon KHÓA (Lock) màu xám nhạt
          Icon(
            PhosphorIcons.lockKey(),
            size: 20,
            color: const Color(0xFF94A3B8), // Màu xám chuẩn
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                color: AppColors.primary,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
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
}

// Widget DottedBorder (CustomPainter - Tích hợp sẵn)
class DottedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;
  final BorderType borderType;
  final Radius radius;

  const DottedBorder({
    super.key,
    required this.child,
    this.color = Colors.black,
    this.strokeWidth = 1,
    this.dashPattern = const [3, 1],
    this.borderType = BorderType.Rect,
    this.radius = const Radius.circular(0),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashPattern: dashPattern,
        borderType: borderType,
        radius: radius,
      ),
      child: child,
    );
  }
}

enum BorderType { Rect, RRect, Circle, Oval }

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;
  final BorderType borderType;
  final Radius radius;

  _DottedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
    required this.borderType,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path();
    if (borderType == BorderType.RRect) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          radius,
        ),
      );
    } else {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        double len = dashPattern[0];
        if (distance + len > pathMetric.length)
          len = pathMetric.length - distance;
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashPattern[0];
        if (distance < pathMetric.length) {
          distance += dashPattern[1];
        }
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
