import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../domain/repositories/request_repository.dart';
import '../../data/models/request_model.dart';
import '../../domain/repositories/department_repository_impl.dart';
import '../../domain/repositories/department_repository.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});
  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  // Logic Tab
  int _selectedTypeIndex = 0;
  int _lateEarlyTypeIndex = 0;

  final TextEditingController _reasonController = TextEditingController();

  // Biến ngày giờ
  DateTime? _fromDate;
  DateTime? _toDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // --- LOGIC UPLOAD & EVIDENCE ---
  final ImagePicker _picker = ImagePicker();

  // [ĐÃ SỬA] Danh sách file đã chọn (chưa upload)
  List<File> _selectedFiles = [];

  int _imageCount = 0; // Max 5
  int _videoCount = 0; // Max 1

  // --- LOGIC SYSTEM ---
  bool _isSubmitting = false;
  final _storage = const FlutterSecureStorage();
  late final RequestRepository _repository;
  late final DepartmentRepository _departmentRepository;

  // Tên phòng HR (Lấy từ server)
  String _hrDepartmentName = 'Human Resources Dept';

  @override
  void initState() {
    super.initState();
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );

    _departmentRepository = DepartmentRepositoryImpl(
      remoteDataSource: DepartmentRemoteDataSource(),
    );

    // Lấy tên phòng HR
    _fetchHrDepartmentName();
  }

  // --- 1. CHỌN FILE (CHƯA UPLOAD NGAY) ---
  Future<void> _pickAndUpload(ImageSource source, bool isVideo) async {
    Navigator.pop(context); // Đóng BottomSheet

    // Validate số lượng
    if (isVideo && _videoCount >= 1) {
      _showErrorSnackBar("Limit reached: Max 1 video allowed.");
      return;
    }
    if (!isVideo && _imageCount >= 5) {
      _showErrorSnackBar("Limit reached: Max 5 images allowed.");
      return;
    }

    try {
      final XFile? xfile = isVideo
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 1),
            )
          : await _picker.pickImage(source: source, imageQuality: 70);

      if (xfile != null) {
        setState(() {
          // [ĐÃ SỬA] Chỉ lưu file vào list local
          _selectedFiles.add(File(xfile.path));

          if (isVideo)
            _videoCount++;
          else
            _imageCount++;
        });
      }
    } catch (e) {
      print("Pick error: $e");
      _showErrorSnackBar("Failed to pick file");
    }
  }

  // Lấy tên phòng HR từ Server
  Future<void> _fetchHrDepartmentName() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final userMap = jsonDecode(userInfoStr);
        String userId = userMap['id'].toString();

        final hrDept = await _departmentRepository.getHrDepartment(userId);

        if (hrDept != null && mounted) {
          setState(() {
            _hrDepartmentName = hrDept.name;
          });
        }
      }
    } catch (e) {
      print("Lỗi tải tên phòng HR: $e");
    }
  }

  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                "Upload Evidence",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Max 5 Images • 1 Video",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // --- LIST OPTIONS ---
              if (_imageCount < 5) ...[
                _buildOptionItem(
                  icon: PhosphorIcons.camera(PhosphorIconsStyle.fill),
                  title: "Take a Photo",
                  color: AppColors.primary,
                  onTap: () => _pickAndUpload(ImageSource.camera, false),
                ),
                _buildOptionItem(
                  icon: PhosphorIcons.image(PhosphorIconsStyle.fill),
                  title: "Choose from Gallery",
                  color: AppColors.primary,
                  onTap: () => _pickAndUpload(ImageSource.gallery, false),
                ),
              ],

              if (_videoCount < 1) ...[
                if (_imageCount < 5)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ),

                _buildOptionItem(
                  icon: PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
                  title: "Record Video",
                  color: const Color(0xFFF59E0B),
                  onTap: () => _pickAndUpload(ImageSource.camera, true),
                ),
                _buildOptionItem(
                  icon: PhosphorIcons.filmStrip(PhosphorIconsStyle.fill),
                  title: "Upload Video",
                  color: const Color(0xFFF59E0B),
                  onTap: () => _pickAndUpload(ImageSource.gallery, true),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(thickness: 4, color: Color(0xFFF9FAFB)),

              // --- CANCEL BUTTON (ĐÃ SỬA HIỆU ỨNG ĐỎ) ---
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  // [MỚI] Thêm hiệu ứng lan tỏa màu đỏ
                  splashColor: const Color(0xFFEF4444).withOpacity(0.1),
                  highlightColor: const Color(0xFFEF4444).withOpacity(0.05),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFFEF4444), // Màu chữ đỏ
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // [HÀM MỚI] Widget con để vẽ từng dòng lựa chọn đẹp hơn
  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.1), // Hiệu ứng lan màu theo icon
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            children: [
              // Icon nền tròn
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1), // Nền nhạt theo màu icon
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              // Text
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151), // Màu chữ xám đậm
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(),
              Icon(
                PhosphorIcons.caretRight(),
                size: 18,
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIC XÓA FILE LOCAL ---
  void _removeFile(int index) {
    File file = _selectedFiles[index];
    String path = file.path.toLowerCase();
    bool isVideo = path.endsWith('.mp4') || path.endsWith('.mov');
    setState(() {
      _selectedFiles.removeAt(index);
      if (isVideo)
        _videoCount--;
      else
        _imageCount--;
    });
  }

  Future<String?> _getUserIdFromStorage() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id']?.toString();
      }
      return await _storage.read(key: 'userId');
    } catch (e) {
      print("Error reading User ID: $e");
    }
    return null;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // --- SUBMIT: UPLOAD RỒI TẠO ĐƠN ---
  Future<void> _onSubmit() async {
    if (_reasonController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter a reason");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await _getUserIdFromStorage();
      if (userId == null) throw Exception("User session not found.");

      // [ĐÃ SỬA] B1: Upload tất cả file trong danh sách
      List<String> uploadedUrls = [];
      if (_selectedFiles.isNotEmpty) {
        for (var file in _selectedFiles) {
          // Gọi API upload từng file
          String url = await _repository.uploadFile(file);
          uploadedUrls.add(url);
        }
      }

      // Ghép thành chuỗi evidenceUrl
      String? evidenceString = uploadedUrls.isNotEmpty
          ? uploadedUrls.join(';')
          : null;

      // Xử lý Ngày Giờ (Giữ nguyên logic cũ)
      DateTime startDateTime;
      DateTime endDateTime;

      if (_selectedTypeIndex == 0) {
        // Leave
        if (_fromDate == null || _toDate == null) {
          throw Exception("Please select From & To Date");
        }
        startDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          8,
          0,
        );
        endDateTime = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
          17,
          0,
        );
      } else if (_selectedTypeIndex == 1) {
        // Overtime
        if (_fromDate == null || _startTime == null || _endTime == null) {
          throw Exception("Please select Date & Time");
        }
        startDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        endDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      } else {
        // Late/Early
        if (_fromDate == null) throw Exception("Please select Date");
        if (_startTime == null)
          throw Exception("Please select First Time field");
        if (_endTime == null)
          throw Exception("Please select Second Time field");

        startDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        endDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      if (endDateTime.isBefore(startDateTime)) {
        throw Exception("End time cannot be before Start time.");
      }

      if (_selectedTypeIndex == 2 &&
          endDateTime.difference(startDateTime).inMinutes <= 0) {
        throw Exception(
          "Invalid duration. Check your Shift Standard Time vs Actual Time.",
        );
      }

      // Tính Duration
      final durationDiff = endDateTime.difference(startDateTime);
      double durationVal = durationDiff.inMinutes / 60.0;
      String durationUnit = "HOURS";
      if (_selectedTypeIndex == 0 && durationVal >= 24) {
        durationVal = durationDiff.inDays.toDouble() + 1;
        durationUnit = "DAYS";
      }

      RequestType typeEnum = RequestType.ANNUAL_LEAVE;
      if (_selectedTypeIndex == 1) typeEnum = RequestType.OVERTIME;
      if (_selectedTypeIndex == 2) {
        typeEnum = _lateEarlyTypeIndex == 0
            ? RequestType.LATE_ARRIVAL
            : RequestType.EARLY_DEPARTURE;
      }

      // Tạo Model
      final requestModel = RequestModel(
        type: typeEnum,
        status: RequestStatus.PENDING,
        startTime: startDateTime,
        endTime: endDateTime,
        reason: _reasonController.text,
        durationVal: double.parse(durationVal.toStringAsFixed(2)),
        durationUnit: durationUnit,
      );

      // B2: Gọi API tạo đơn (kèm chuỗi evidence đã upload)
      await _repository.createRequest(
        userId: userId,
        request: requestModel,
        evidenceUrl: evidenceString,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request submitted successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- Helper UI ---
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
          if (_selectedTypeIndex != 0) _toDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd/mm/yyyy';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

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
                  _buildHeader(context, 'CREATE REQUEST'),
                  const SizedBox(height: 24),
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
                  if (_selectedTypeIndex == 0) _buildLeaveBody(),
                  if (_selectedTypeIndex == 1) _buildOvertimeBody(),
                  if (_selectedTypeIndex == 2) _buildLateEarlyBody(),
                  const SizedBox(height: 24),
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

                  // --- PHẦN EVIDENCE HIỂN THỊ ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('EVIDENCE (OPTIONAL)'),
                      Text(
                        "$_imageCount/5 Images • $_videoCount/1 Video",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Thumbnail List (Hiển thị File local)
                  if (_selectedFiles.isNotEmpty)
                    Container(
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          File file = _selectedFiles[index];
                          String path = file.path.toLowerCase();
                          bool isVideo =
                              path.endsWith('.mp4') || path.endsWith('.mov');
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey[300],
                                  child: isVideo
                                      ? const Icon(
                                          Icons.videocam,
                                          color: Colors.black54,
                                          size: 40,
                                        )
                                      : Image.file(
                                          // [ĐÃ SỬA] Dùng Image.file
                                          file,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.error),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeFile(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // Upload Button (Ẩn nếu full)
                  if (_imageCount < 5 || _videoCount < 1)
                    DottedBorder(
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(12),
                      dashPattern: const [6, 3],
                      color: const Color(0xFFA1ACCC),
                      strokeWidth: 1,
                      child: Material(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          // [ĐÃ SỬA] Chỉ disable khi đang submit
                          onTap: _isSubmitting ? null : _showUploadBottomSheet,
                          child: SizedBox(
                            height: 80,
                            width: double.infinity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIcons.uploadSimple(
                                    PhosphorIconsStyle.bold,
                                  ),
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to upload Photo/Video',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting) ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 4,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
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

  // --- Build Widgets ---
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
    bool isLate = _lateEarlyTypeIndex == 0;
    String label1 = isLate
        ? 'Shift Start Time (Standard)'
        : 'Actual Departure Time';
    String label2 = isLate
        ? 'Actual Arrival Time'
        : 'Shift End Time (Standard)';

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
        _buildDateSelector('Date', true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTimeSelector(label1, true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeSelector(label2, false)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsRegular.info,
                color: Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLate
                      ? "Please enter your Standard Shift Start (e.g., 08:00) and when you actually arrived."
                      : "Please enter when you actually left and your Standard Shift End (e.g., 17:00).",
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
              size: 20,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // [ĐÃ SỬA] Xóa const để dùng biến
              children: [
                Text(
                  _hrDepartmentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Approver',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            PhosphorIcons.lockKey(),
            size: 20,
            color: const Color(0xFF94A3B8),
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

// ... DottedBorder & Painter Class (GIỮ NGUYÊN) ...
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
  void paint(ui.Canvas canvas, ui.Size size) {
    final ui.Paint paint = ui.Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    ui.Path path = ui.Path();
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
    ui.Path dashPath = ui.Path();
    double distance = 0.0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        double len = dashPattern[0];
        if (distance + len > pathMetric.length)
          len = pathMetric.length - distance;
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashPattern[0];
        if (distance < pathMetric.length) distance += dashPattern[1];
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
