import 'dart:convert';
import 'dart:io'; // Thêm thư viện IO
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart'; // Thêm để mở link ngoài
import 'package:video_player/video_player.dart'; // Thêm video player
import 'package:chewie/chewie.dart'; // Thêm chewie
import 'package:intl/intl.dart';
import '../../../../core/services/websocket_service.dart';
import '../../data/models/request_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../domain/repositories/request_repository.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../../../core/utils/custom_snackbar.dart';

class ManagerRequestReviewPage extends StatefulWidget {
  final RequestModel request;
  const ManagerRequestReviewPage({super.key, required this.request});
  @override
  State<ManagerRequestReviewPage> createState() =>
      _ManagerRequestReviewPageState();
}

class _ManagerRequestReviewPageState extends State<ManagerRequestReviewPage> {
  final TextEditingController _rejectReasonController = TextEditingController();

  late final RequestRepository _repository;
  final _storage = const FlutterSecureStorage();
  bool _isProcessing = false;
  late RequestModel _currentRequest;
  // Biến lưu hàm hủy đăng ký
  dynamic _unsubscribeFn;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
    _initListener();
  }

  void _initListener() {
    final topic = '/topic/request/${widget.request.id}';

    _unsubscribeFn = WebSocketService().subscribe(topic, (data) {
      if (!mounted) return;

      if (data is Map<String, dynamic>) {
        final updatedReq = RequestModel.fromJson(data);
        setState(() {
          _currentRequest = updatedReq;
        });

        if (updatedReq.status != RequestStatus.PENDING) {
          // [SỬA] Dùng CustomSnackBar thông báo cập nhật trạng thái
          CustomSnackBar.show(
            context,
            title: "Status Updated",
            message: "Request status changed to ${updatedReq.status.name}",
            isError: updatedReq.status == RequestStatus.REJECTED,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    // Hủy đăng ký topic này (các topic khác vẫn chạy)
    if (_unsubscribeFn != null) {
      _unsubscribeFn(unsubscribeHeaders: const <String, String>{});
    }
    _rejectReasonController.dispose(); // Dispose Controller
    super.dispose();
  }

  // --- LOGIC XỬ LÝ URL & MỞ FILE (GIỐNG REQUEST DETAIL) ---
  String _fixUrl(String url) {
    if (Platform.isAndroid && url.contains('localhost')) {
      return url.replaceFirst('localhost', '10.0.2.2');
    }
    return url;
  }

  List<String> _getEvidenceUrls() {
    if (_currentRequest.evidenceUrl != null &&
        _currentRequest.evidenceUrl!.isNotEmpty) {
      return _currentRequest.evidenceUrl!.split(';');
    }
    return [];
  }

  void _openFile(String url) {
    final String fixedUrl = _fixUrl(url);
    final String lowerUrl = fixedUrl.toLowerCase();

    if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp')) {
      final List<String> allImages = _getEvidenceUrls()
          .map((e) => _fixUrl(e))
          .where((e) {
            final l = e.toLowerCase();
            return l.endsWith('.jpg') ||
                l.endsWith('.jpeg') ||
                l.endsWith('.png') ||
                l.endsWith('.webp');
          })
          .toList();

      int initialIndex = allImages.indexOf(fixedUrl);
      if (initialIndex == -1) initialIndex = 0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _FullScreenImageViewer(
            imageUrls: allImages,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _FullScreenVideoPlayer(videoUrl: fixedUrl),
        ),
      );
    } else {
      _launchExternalUrl(fixedUrl);
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        // [SỬA] Báo lỗi mở file
        CustomSnackBar.show(
          context,
          title: "File Error",
          message: "Cannot open file: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _processRequest(String status, String comment) async {
    print("--> [DEBUG] Bắt đầu xử lý đơn: $status");
    setState(() => _isProcessing = true);

    try {
      String? userId;
      String? userInfoStr = await _storage.read(key: 'user_info');

      if (userInfoStr != null) {
        try {
          final data = jsonDecode(userInfoStr);
          userId = data['id']?.toString();
        } catch (e) {
          print("--> [LỖI] Parse JSON thất bại: $e");
        }
      }

      if (userId == null) {
        userId = await _storage.read(key: 'user_id');
      }

      if (userId == null) {
        if (mounted) {
          // [SỬA] Báo lỗi không tìm thấy user
          CustomSnackBar.show(
            context,
            title: "Authentication Error",
            message: "User info not found. Please login again.",
            isError: true,
          );
        }
        return;
      }

      final success = await _repository.processRequest(
        widget.request.id.toString(),
        userId,
        status,
        comment,
      );

      if (success && mounted) {
        // Socket sẽ tự update UI, nhưng ta pop về list cho mượt flow
        Navigator.pop(context, true);
      } else if (!success && mounted) {
        // [SỬA] Báo lỗi xử lý thất bại
        CustomSnackBar.show(
          context,
          title: "Processing Failed",
          message: "Could not process request. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Error",
          message: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reason for Rejection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please clarify why this request is rejected. This reason will be sent to the employee.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 152,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB6C1E0), width: 1),
                ),
                child: TextField(
                  controller: _rejectReasonController,
                  maxLines: 5,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration.collapsed(
                    hintText:
                        'E.g. Not enough leave balance, Urgent deadline...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA5ADC6),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildSheetButton(
                      label: 'Cancel',
                      bgColor: const Color(0xFFF3F4F6),
                      textColor: const Color(0xFF374151),
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSheetButton(
                      label: 'Confirm',
                      bgColor: const Color(0xFFDC2626),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _processRequest(
                          'REJECTED',
                          _rejectReasonController.text,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetButton({
    required String label,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleApprove() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Approve Request?',
        message: 'This request will be marked as Approved.',
        confirmText: 'Approve',
        confirmColor: const Color(0xFF2260FF),
        onConfirm: () {
          Navigator.pop(context);
          _processRequest('APPROVED', 'Approved by Manager');
        },
      ),
    );
  }

  // --- HÀM BUILD ---
  @override
  Widget build(BuildContext context) {
    // [QUAN TRỌNG] Dùng _currentRequest để render toàn bộ UI
    final req = _currentRequest;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                // [SỬA] Truyền 'req' vào hàm build
                                _buildEmployeeInfoCard(req),
                                const SizedBox(height: 16),
                                _buildRequestDetailCard(req),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Button Bar (Chỉ hiển thị khi PENDING)
                    if (req.status == RequestStatus.PENDING)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 24,
                        child: Row(
                          children: [
                            // NÚT REJECT
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4E4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () =>
                                        _showRejectBottomSheet(context),
                                    borderRadius: BorderRadius.circular(10),
                                    splashColor: const Color(
                                      0xFFFECACA,
                                    ).withOpacity(0.5),
                                    highlightColor: const Color(
                                      0xFFFECACA,
                                    ).withOpacity(0.3),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          PhosphorIcons.x(
                                            PhosphorIconsStyle.bold,
                                          ),
                                          color: const Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Reject',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
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
                            ),
                            const SizedBox(width: 16),

                            // NÚT APPROVE
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2260FF),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: _handleApprove,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          PhosphorIcons.check(
                                            PhosphorIconsStyle.bold,
                                          ),
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Approve',
                                          style: TextStyle(
                                            color: Colors.white,
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
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading Indicator
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                color: const Color(0xFF2260FF),
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            'REVIEW REQUEST',
            style: TextStyle(
              color: Color(0xFF2260FF),
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard(RequestModel req) {
    // [SAU KHI SỬA] Dùng role thực tế
    final bool isManager =
        req.requesterRole == 'MANAGER' || req.requesterRole == 'COMPANY_ADMIN';

    // Lấy thông tin từ req
    final statusText = req.status.name;
    final statusColor = _getStatusColor(req.status);
    final statusBgColor = _getStatusBgColor(req.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4CF1F1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 0),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- BẮT ĐẦU ĐOẠN SỬA ---
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF3F4F6), // Màu nền xám nhạt
            ),
            child: req.requesterAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      req.requesterAvatar,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      // [SỬA 1]
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: const Color(0xFF9CA3AF),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    // [SỬA 2]
                    child: Icon(
                      PhosphorIcons.user(PhosphorIconsStyle.fill),
                      color: const Color(0xFF9CA3AF),
                      size: 24,
                    ),
                  ),
          ),
          // --- KẾT THÚC ĐOẠN SỬA ---
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        req.requesterName.isNotEmpty
                            ? req.requesterName
                            : "Unknown",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isManager) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECF1FF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Manager',
                          style: TextStyle(
                            color: Color(0xFF2260FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee ID: ${req.requesterId} | ${req.requesterDept}',
                  style: const TextStyle(
                    color: Color(0xFF555252),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),

          // [QUAN TRỌNG] Badge trạng thái động
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestDetailCard(RequestModel request) {
    final evidenceList = _getEvidenceUrls();

    // [LOGIC ĐÃ SỬA] Ưu tiên lấy requestCode, nếu không có mới lấy ID và thêm số 0
    String displayCode =
        request.requestCode != null && request.requestCode!.isNotEmpty
        ? request.requestCode!
        : (request.id?.toString().padLeft(4, '0') ?? "N/A");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4CF1F1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 0),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECF1FF),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              request.type.name,
              style: const TextStyle(
                color: Color(0xFF2260FF),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 8),

          // [HIỂN THỊ] Sử dụng displayCode đã xử lý ở trên
          Text(
            '#$displayCode',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 24),
          _buildDynamicDetails(request),
          const SizedBox(height: 24),
          const Text(
            'REASON',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA1ACCC)),
            ),
            child: Text(
              '"${request.reason}"',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ),
          if (evidenceList.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'ATTACHMENT',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            ...evidenceList
                .map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildAttachmentCard(url),
                  ),
                )
                .toList(),
          ] else ...[
            const SizedBox(height: 24),
            const Text("No Attachment", style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  // Widget thẻ đính kèm (Copy từ RequestDetail)
  Widget _buildAttachmentCard(String fileUrl) {
    final String fixedUrl = _fixUrl(fileUrl);
    final String lowerUrl = fixedUrl.toLowerCase();

    final bool isImage =
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp');

    final bool isVideo =
        lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECF1FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openFile(fileUrl),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: isImage
                        ? Image.network(
                            fixedUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: isVideo
                                ? Colors.orange.withOpacity(0.1)
                                : const Color(0xFFEFF1F5),
                            child: Icon(
                              isVideo
                                  ? PhosphorIcons.playCircle(
                                      PhosphorIconsStyle.fill,
                                    )
                                  : PhosphorIcons.fileText(
                                      PhosphorIconsStyle.fill,
                                    ),
                              color: isVideo
                                  ? Colors.orange
                                  : const Color(0xFF2260FF),
                              size: 32,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isImage
                            ? "Evidence Image"
                            : isVideo
                            ? "Evidence Video"
                            : "Attached Document",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tap to view details",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFFBDC6DE),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicDetails(RequestModel request) {
    // Format riêng cho Annual Leave: "Dec 31, 2025" (Không hiện giờ)
    final annualLeaveFormat = DateFormat('MMM dd, yyyy');

    // Format cho các loại đơn khác (nếu cần giờ)
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');

    // TRƯỜNG HỢP 1: Đơn nghỉ phép (Annual Leave) -> Chỉ hiện Ngày Tháng Năm
    if (request.type == RequestType.ANNUAL_LEAVE) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột FROM
              Expanded(
                child: _buildInfoItem(
                  'FROM',
                  annualLeaveFormat.format(
                    request.startTime,
                  ), // Ví dụ: Dec 31, 2025
                ),
              ),
              // Cột TO
              Expanded(
                child: _buildInfoItem(
                  'TO',
                  annualLeaveFormat.format(
                    request.endTime,
                  ), // Ví dụ: Jan 02, 2026
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dòng DURATION
          _buildInfoItem('DURATION', request.duration, isBlue: true),
        ],
      );
    }
    // TRƯỜNG HỢP 2: Các loại đơn khác (Đi trễ/Về sớm) -> Giữ nguyên logic cũ
    else {
      String dateLabel = 'DATE';
      String dateValue = dateFormat.format(request.startTime);

      String row2Label1 = 'START TIME';
      String row2Value1 = timeFormat.format(request.startTime);

      String row2Label2 = 'END TIME';
      String row2Value2 = timeFormat.format(request.endTime);

      if (request.type == RequestType.LATE_ARRIVAL) {
        row2Label1 = 'EXPECTED';
        row2Label2 = 'ACTUAL ARRIVAL';
      } else if (request.type == RequestType.EARLY_DEPARTURE) {
        row2Label1 = 'END OF SHIFT';
        row2Label2 = 'ACTUAL LEAVE';
      }

      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInfoItem(dateLabel, dateValue)),
              Expanded(
                child: _buildInfoItem(
                  'DURATION',
                  request.duration,
                  isBlue: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInfoItem(row2Label1, row2Value1)),
              Expanded(child: _buildInfoItem(row2Label2, row2Value2)),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildInfoItem(String label, String value, {bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isBlue ? const Color(0xFF2563EB) : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  // --- HELPER MÀU SẮC ---
  Color _getStatusBgColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFFFF7ED);
      case RequestStatus.REJECTED:
        return const Color(0xFFFEF2F2);
      case RequestStatus.APPROVED:
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFEA580C);
      case RequestStatus.REJECTED:
        return const Color(0xFFDC2626);
      case RequestStatus.APPROVED:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF374151);
    }
  }
}

// --- Class xem Ảnh Full (Copy từ RequestDetail) ---
class _FullScreenImageViewer extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final PageController controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading:
            false, // [QUAN TRỌNG] Tắt nút back mặc định bên trái
        // [ĐÚNG] actions nằm bên phải
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8), // Căn lề phải một chút cho đẹp
        ],
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Class xem Video Full (Copy từ RequestDetail) ---
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _videoPlayerController.initialize();

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return const Center(
              child: Text(
                'Video loading error',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isError = true);
      debugPrint("Video Error: $e");
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: _isError
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 40),
                    SizedBox(height: 10),
                    Text(
                      "This video cannot be played.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
              : _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
              ? Chewie(controller: _chewieController!)
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
