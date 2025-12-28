// File: lib/presentation/pages/create_request_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

// Import cấu hình và Data Layer
import '../../../../core/config/app_colors.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../data/models/request_model.dart';

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
  List<String> _uploadedUrls = []; // Lưu URL sau khi upload thành công
  int _imageCount = 0; // Max 5
  int _videoCount = 0; // Max 1
  bool _isUploading = false;

  // --- LOGIC SYSTEM ---
  bool _isSubmitting = false;
  final _storage = const FlutterSecureStorage();
  late final RequestRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Repository
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
  }

  // --- 1. GỌI REPOSITORY ĐỂ UPLOAD ---
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
      final XFile? file = isVideo
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 1),
            )
          : await _picker.pickImage(source: source, imageQuality: 70);

      if (file != null) {
        setState(() => _isUploading = true);

        // [QUAN TRỌNG] Gọi Repository thay vì gọi trực tiếp http
        String url = await _repository.uploadFile(File(file.path));

        setState(() {
          _uploadedUrls.add(url);
          if (isVideo)
            _videoCount++;
          else
            _imageCount++;
          _isUploading = false;
        });
      }
    } catch (e) {
      print("Upload error: $e");
      setState(() => _isUploading = false);
      _showErrorSnackBar(
        "Upload failed: ${e.toString().replaceAll('Exception: ', '')}",
      );
    }
  }

  // --- 2. BOTTOM SHEET UI (Giống UserProfile) ---
  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Add Evidence",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Max 5 Images • 1 Video",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 20),

            // Mục chọn ẢNH
            if (_imageCount < 5) ...[
              ListTile(
                leading: Icon(
                  PhosphorIcons.camera(PhosphorIconsStyle.regular),
                  color: AppColors.primary,
                  size: 24,
                ),
                title: const Text(
                  "Take Photo",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _pickAndUpload(ImageSource.camera, false),
              ),
              ListTile(
                leading: Icon(
                  PhosphorIcons.image(PhosphorIconsStyle.regular),
                  color: AppColors.primary,
                  size: 24,
                ),
                title: const Text(
                  "Choose Image",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _pickAndUpload(ImageSource.gallery, false),
              ),
            ],

            // Mục chọn VIDEO (Có đường kẻ phân cách nếu đã hiện mục ảnh)
            if (_videoCount < 1) ...[
              if (_imageCount < 5) const Divider(),
              ListTile(
                leading: Icon(
                  PhosphorIcons.videoCamera(PhosphorIconsStyle.regular),
                  color: Colors.orange,
                  size: 24,
                ),
                title: const Text(
                  "Record Video",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _pickAndUpload(ImageSource.camera, true),
              ),
              ListTile(
                leading: Icon(
                  PhosphorIcons.filmStrip(PhosphorIconsStyle.regular),
                  color: Colors.orange,
                  size: 24,
                ),
                title: const Text(
                  "Choose Video",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _pickAndUpload(ImageSource.gallery, true),
              ),
            ],

            const SizedBox(height: 10),
            ListTile(
              leading: Icon(
                PhosphorIcons.x(PhosphorIconsStyle.regular),
                color: Colors.red,
                size: 24,
              ),
              title: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC XÓA FILE ---
  void _removeFile(int index) {
    String url = _uploadedUrls[index];
    bool isVideo =
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov');
    setState(() {
      _uploadedUrls.removeAt(index);
      if (isVideo)
        _videoCount--;
      else
        _imageCount--;
    });
  }

  // --- 3. LẤY ID CHUẨN (User Profile Style) ---
  Future<String?> _getUserIdFromStorage() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id']?.toString();
      }
      // Fallback
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

  // --- HÀM SUBMIT ---
  Future<void> _onSubmit() async {
    if (_reasonController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter a reason");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await _getUserIdFromStorage();
      if (userId == null) throw Exception("User session not found.");

      // Xử lý Ngày Giờ
      DateTime startDateTime;
      DateTime endDateTime;

      if (_selectedTypeIndex == 0) {
        // LEAVE
        if (_fromDate == null || _toDate == null)
          throw Exception("Please select From & To Date");
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
        // OVERTIME
        if (_fromDate == null || _startTime == null || _endTime == null)
          throw Exception("Please select Date & Time");
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
        // LATE/EARLY
        if (_fromDate == null || _startTime == null)
          throw Exception("Please select Date & Time");
        startDateTime = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }

      if (endDateTime.isBefore(startDateTime))
        throw Exception("End time cannot be before Start time");

      // Tính Duration
      final durationDiff = endDateTime.difference(startDateTime);
      double durationVal = durationDiff.inMinutes / 60.0;
      String durationUnit = "HOURS";
      if (_selectedTypeIndex == 0 && durationVal >= 24) {
        durationVal = durationDiff.inDays.toDouble() + 1;
        durationUnit = "DAYS";
      }

      // Map Enum
      RequestType typeEnum = RequestType.ANNUAL_LEAVE;
      if (_selectedTypeIndex == 1) typeEnum = RequestType.OVERTIME;
      if (_selectedTypeIndex == 2) {
        typeEnum = _lateEarlyTypeIndex == 0
            ? RequestType.LATE_ARRIVAL
            : RequestType.EARLY_DEPARTURE;
      }

      // Nối URL ảnh thành chuỗi
      String? evidenceString = _uploadedUrls.isNotEmpty
          ? _uploadedUrls.join(';')
          : null;

      final requestModel = RequestModel(
        type: typeEnum,
        status: RequestStatus.PENDING,
        startTime: startDateTime,
        endTime: endDateTime,
        reason: _reasonController.text,
        durationVal: double.parse(durationVal.toStringAsFixed(1)),
        durationUnit: durationUnit,
      );

      // Gọi Repository
      await _repository.createRequest(
        userId: userId,
        request: requestModel,
        evidenceUrl: evidenceString, // [MỚI] Truyền evidence
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
  // (Giữ nguyên các hàm _selectDate, _selectTime, _formatDate, _formatTime)
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

                  // Thumbnail List
                  if (_uploadedUrls.isNotEmpty)
                    Container(
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _uploadedUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          String url = _uploadedUrls[index];
                          bool isVideo =
                              url.toLowerCase().endsWith('.mp4') ||
                              url.toLowerCase().endsWith('.mov');
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
                                      : Image.network(
                                          url,
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

                  // Upload Button (ẩn nếu đã full)
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
                          onTap: _isUploading ? null : _showUploadBottomSheet,
                          child: SizedBox(
                            height: 80,
                            width: double.infinity,
                            child: _isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Column(
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
                      onPressed: (_isSubmitting || _isUploading)
                          ? null
                          : _onSubmit,
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
