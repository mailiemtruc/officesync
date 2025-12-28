import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../data/datasources/request_remote_data_source.dart';

class RequestDetailPage extends StatefulWidget {
  final RequestModel request;

  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  late final RequestRepositoryImpl _repository;
  final _storage = const FlutterSecureStorage();
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Repository
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
  }

  // --- LOGIC BACKEND: HỦY ĐƠN ---
  Future<void> _handleCancelRequest() async {
    // 1. Lấy User ID
    String? userId;
    String? userInfo = await _storage.read(key: 'user_info');
    if (userInfo != null) {
      userId = jsonDecode(userInfo)['id'].toString();
    } else {
      userId = await _storage.read(key: 'userId');
    }

    if (userId == null) return;

    // 2. Gọi API
    setState(() => _isCancelling = true);
    try {
      // Giả sử request.id là String hoặc Int, cần chuyển về String cho hàm cancel
      await _repository.cancelRequest(widget.request.id.toString(), userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request cancelled successfully")),
        );
        Navigator.pop(context, true); // Trả về true để trang trước reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showCancelDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Cancel Request?',
        message:
            'Are you sure you want to cancel this request? This action cannot be undone.',
        confirmText: 'Yes, Cancel',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: () {
          Navigator.pop(context); // Đóng Dialog
          _handleCancelRequest(); // Gọi API hủy
        },
      ),
    );
  }

  // --- LOGIC WORKFLOW (Giữ nguyên logic hiển thị của bạn) ---
  List<Map<String, dynamic>> _getWorkflowSteps() {
    const colorGreen = Color(0xFF10B981);
    const colorRed = Color(0xFFDC2626);
    const colorBlue = Color(0xFF2563EB);
    const colorGrey = Color(0xFFCBD5E1);

    final status = widget.request.status;

    final steps = [
      {
        'title': 'Request Submitted',
        'time': 'Submitted', // Có thể bind ngày tạo nếu có
        'actor': 'You',
        'dotColor': colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': 'done',
      },
      {
        'title': 'Manager Review',
        'time': status == RequestStatus.PENDING ? 'Processing...' : 'Reviewed',
        'actor': 'Manager', // Có thể bind tên manager nếu có
        'dotColor': status == RequestStatus.PENDING ? colorBlue : colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': status == RequestStatus.PENDING ? 'current' : 'done',
      },
    ];

    if (status == RequestStatus.PENDING) {
      steps.add({
        'title': 'Final Decision',
        'time': 'Waiting for approval',
        'actor': '',
        'dotColor': colorGrey,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'waiting',
      });
    } else if (status == RequestStatus.APPROVED) {
      steps.add({
        'title': 'Request Approved',
        'time': 'Approved',
        'actor': 'System updated successfully.',
        'dotColor': const Color(0xFF10B981),
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'approved_done',
      });
    } else if (status == RequestStatus.REJECTED) {
      steps.add({
        'title': 'Request Rejected',
        'time': 'Rejected',
        'actor': 'Tap \'See reason\' for details',
        'dotColor': colorRed,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'rejected_done',
      });
    } else if (status == RequestStatus.CANCELLED) {
      steps.add({
        'title': 'Request Cancelled',
        'time': 'Cancelled by you',
        'actor': '',
        'dotColor': Colors.grey,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'cancelled_done',
      });
    }
    return steps;
  }

  // --- DIALOG LÝ DO TỪ CHỐI (Giữ nguyên UI) ---
  void _showRejectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.warning,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Manager's Feedback",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Reason for rejection:",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${widget.request.rejectReason ?? "No reason provided."}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF334155),
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.request.status == RequestStatus.PENDING;
    final isRejected = widget.request.status == RequestStatus.REJECTED;

    // Logic Evidence: Giả sử evidenceUrl là chuỗi các URL cách nhau dấu chấm phẩy
    // Nếu bạn chưa update Model, hãy tạm thời dùng biến giả lập hoặc map từ reason (nếu có)
    // Ở đây mình check nếu có dữ liệu evidence thì hiển thị
    // final hasEvidence = widget.request.evidenceUrl != null && widget.request.evidenceUrl!.isNotEmpty;

    // TẠM THỜI: Để không lỗi code vì Model cũ chưa có evidenceUrl, mình sẽ ẩn phần này nếu null
    // Bạn có thể mở comment bên dưới khi Model đã update
    // List<String> evidenceList = widget.request.evidenceUrl?.split(';') ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, 'REQUEST DETAIL'),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainStatusCard(context, isRejected),
                        const SizedBox(height: 24),
                        _buildInfoGrid(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('REASON'),
                        const SizedBox(height: 8),
                        Text(
                          '"${widget.request.description}"',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),

                        // [TÍCH HỢP] Chỉ hiện Evidence nếu có
                        // if (evidenceList.isNotEmpty) ...[
                        //   const SizedBox(height: 24),
                        //   _buildSectionTitle('ATTACHMENT'),
                        //   const SizedBox(height: 12),
                        //   // Render list ảnh
                        //   ...evidenceList.map((url) => Padding(
                        //     padding: const EdgeInsets.only(bottom: 8.0),
                        //     child: _buildAttachmentCard(url), // Truyền URL vào
                        //   )).toList(),
                        // ],

                        // Placeholder UI cho Evidence (Giữ nguyên code cũ của bạn)
                        const SizedBox(height: 24),
                        _buildSectionTitle('ATTACHMENT'),
                        const SizedBox(height: 12),
                        _buildAttachmentCard("evidence.jpg"), // Static demo

                        const SizedBox(height: 24),
                        _buildSectionTitle('APPROVAL WORKFLOW'),
                        const SizedBox(height: 16),
                        _buildWorkflowList(context),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // [TÍCH HỢP] Nút Hủy Đơn (Chỉ hiện khi Pending)
                if (isPending)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isCancelling
                            ? null
                            : () => _showCancelDialog(context),
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              foregroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                              elevation: 0,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(
                                const Color(0xFFDC2626).withOpacity(0.1),
                              ),
                            ),
                        child: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFDC2626),
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(PhosphorIconsRegular.x, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cancel Request',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CÁC WIDGET CON (GIỮ NGUYÊN UI) ---

  Widget _buildMainStatusCard(BuildContext context, bool isRejected) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 6,
            width: double.infinity,
            color: widget.request.statusColor,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  widget.request.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#REQ-${widget.request.id?.toString().padLeft(4, '0') ?? "N/A"}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.request.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.request.statusText.toUpperCase(),
                    style: TextStyle(
                      color: widget.request.statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                if (isRejected) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showRejectionDialog(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              PhosphorIconsRegular.info,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'See rejection reason',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    // Logic hiển thị thông tin tùy theo loại Request (Giữ nguyên)
    if (widget.request.type == RequestType.ANNUAL_LEAVE) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildInfoRow(
              'Date Range',
              widget.request.dateRange,
              '',
            ), // Tùy biến text
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Duration',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  widget.request.duration,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSimpleInfoRow(
              'Date',
              widget.request.dateRange.split('•')[0].trim(),
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildSimpleInfoRow('Duration', widget.request.duration),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildSimpleInfoRow(
              'Time',
              widget.request.dateRange.contains('•')
                  ? widget.request.dateRange.split('•')[1].trim()
                  : "N/A",
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String date, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              date,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  // [SỬA] Widget Attachment nhận tên file/url
  Widget _buildAttachmentCard(String fileName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECF1FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PhosphorIcons.fileImage(PhosphorIconsStyle.fill),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Attachment',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Logic mở file/ảnh
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowList(BuildContext context) {
    final steps = _getWorkflowSteps();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isLast = step['isLast'] as bool;
        final Color dotColor = step['dotColor'];
        final Color lineColor = step['lineColor'];
        final String title = step['title'];
        final String actor = step['actor'];
        final String status = step['status'];

        Color titleColor = Colors.black;
        Color actorColor = const Color(0xFF64748B);
        FontWeight titleWeight = FontWeight.bold;

        if (status == 'approved_done') {
          titleColor = const Color(0xFF10B981);
          actorColor = const Color(0xFF10B981);
          titleWeight = FontWeight.w900;
        } else if (status == 'rejected_done') {
          titleColor = const Color(0xFFDC2626);
          actorColor = const Color(0xFFF87171);
        } else if (status == 'cancelled_done') {
          titleColor = Colors.grey;
          actorColor = Colors.grey;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(child: Container(width: 2, color: lineColor)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: titleWeight,
                          fontSize: 16,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step['time'],
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (actor.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        (status == 'rejected_done' &&
                                actor.contains('See reason'))
                            ? GestureDetector(
                                onTap: () => _showRejectionDialog(context),
                                child: Text(
                                  actor,
                                  style: TextStyle(
                                    color: actorColor,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              )
                            : Text(
                                actor,
                                style: TextStyle(
                                  color: actorColor,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'Inter',
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: Color(0xFF655F5F),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: 'Inter',
    ),
  );
}
