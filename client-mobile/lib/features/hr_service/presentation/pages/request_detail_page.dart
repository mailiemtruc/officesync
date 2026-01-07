import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../domain/repositories/request_repository.dart';
import '../../data/datasources/request_remote_data_source.dart';

class RequestDetailPage extends StatefulWidget {
  final RequestModel request;

  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  late final RequestRepository _repository;
  final _storage = const FlutterSecureStorage();
  bool _isCancelling = false;

  // [LOGIC REALTIME]
  late RequestModel _currentRequest;
  StompClient? stompClient;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request; // Khởi tạo dữ liệu
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
    _connectWebSocket(); // [MỚI]
  }

  void _connectWebSocket() {
    final socketUrl = 'ws://10.0.2.2:8081/ws-hr/websocket';

    stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          print("--> [RequestDetail] Connected WS");
          final topic = '/topic/request/${widget.request.id}';

          stompClient!.subscribe(
            destination: topic,
            callback: (StompFrame frame) {
              if (frame.body != null) {
                print("--> [RequestDetail] Received: ${frame.body}");
                final Map<String, dynamic> data = jsonDecode(frame.body!);
                final updatedReq = RequestModel.fromJson(data);

                if (mounted) {
                  setState(() {
                    _currentRequest = updatedReq;
                  });
                  if (updatedReq.status == RequestStatus.CANCELLED) {
                    CustomSnackBar.show(
                      context,
                      title: "Request Cancelled",
                      message: "This request has been cancelled.",
                      isError: true, // Màu đỏ vì là hủy
                    );
                    Navigator.pop(context, true);
                  } else {
                    CustomSnackBar.show(
                      context,
                      title: "Status Updated",
                      message: "Updated to: ${_currentRequest.status.name}",
                      isError: _currentRequest.status == RequestStatus.REJECTED,
                    );
                  }
                }
              }
            },
          );
        },
      ),
    );
    stompClient!.activate();
  }

  @override
  void dispose() {
    stompClient?.deactivate(); // Ngắt kết nối khi thoát trang
    super.dispose();
  }

  // --- LOGIC BACKEND: HỦY ĐƠN ---
  Future<void> _handleCancelRequest() async {
    String? userId;
    String? userInfo = await _storage.read(key: 'user_info');
    if (userInfo != null) {
      userId = jsonDecode(userInfo)['id'].toString();
    } else {
      userId = await _storage.read(key: 'userId');
    }

    if (userId == null) return;

    setState(() => _isCancelling = true);
    try {
      await _repository.cancelRequest(widget.request.id.toString(), userId);
      // Không cần pop thủ công ở đây nếu WebSocket hoạt động tốt,
      // nhưng giữ lại để UX nhanh hơn.
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // [SỬA] Báo lỗi khi hủy đơn
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "Failed to cancel request: $e",
          isError: true,
        );
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
        title: 'Delete Request?',
        message:
            'Are you sure you want to delete this request? This action cannot be undone.',
        confirmText: 'Yes, Delete',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: () {
          Navigator.pop(context);
          _handleCancelRequest();
        },
      ),
    );
  }

  // --- LOGIC XỬ LÝ URL & MỞ FILE ---
  String _fixUrl(String url) {
    if (Platform.isAndroid && url.contains('localhost')) {
      return url.replaceFirst('localhost', '10.0.2.2');
    }
    return url;
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

  List<String> _getEvidenceUrls() {
    // Sử dụng _currentRequest
    if (_currentRequest.evidenceUrl != null &&
        _currentRequest.evidenceUrl!.isNotEmpty) {
      return _currentRequest.evidenceUrl!.split(';');
    }
    return [];
  }

  List<Map<String, dynamic>> _getWorkflowSteps() {
    const colorGreen = Color(0xFF10B981);
    const colorRed = Color(0xFFDC2626);
    const colorBlue = Color(0xFF2563EB);
    const colorGrey = Color(0xFFCBD5E1);

    final status = _currentRequest.status;

    // Format thời gian gửi đơn
    String submittedTime = 'Submitted';
    if (_currentRequest.createdAt != null) {
      submittedTime = DateFormat(
        'HH:mm, dd/MM/yyyy',
      ).format(_currentRequest.createdAt!);
    }

    // Format thời gian duyệt/xử lý
    String processedTime = 'Waiting...';
    if (_currentRequest.updatedAt != null && status != RequestStatus.PENDING) {
      processedTime = DateFormat(
        'HH:mm, dd/MM/yyyy',
      ).format(_currentRequest.updatedAt!);
    }

    // Tên người duyệt
    String actorName = _currentRequest.approverName ?? 'Manager';

    final steps = [
      {
        'title': 'Request Submitted',
        'time': submittedTime,
        'actor': 'By You',
        'dotColor': colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': 'done',
      },
      {
        'title': 'Manager Review',
        'time': status == RequestStatus.PENDING
            ? 'Processing...'
            : processedTime,
        'actor': status == RequestStatus.PENDING
            ? 'Waiting for Manager'
            : 'Reviewed',
        'dotColor': status == RequestStatus.PENDING ? colorBlue : colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': status == RequestStatus.PENDING ? 'current' : 'done',
      },
    ];

    if (status == RequestStatus.PENDING) {
      steps.add({
        'title': 'Final Decision',
        'time': 'Pending',
        'actor': '',
        'dotColor': colorGrey,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'waiting',
      });
    } else if (status == RequestStatus.APPROVED) {
      steps.add({
        'title': 'Request Approved',
        'time': processedTime,
        'actor': 'By $actorName', // [HIỆN TÊN NGƯỜI DUYỆT]
        'dotColor': const Color(0xFF10B981),
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'approved_done',
      });
    } else if (status == RequestStatus.REJECTED) {
      steps.add({
        'title': 'Request Rejected',
        'time': processedTime,
        'actor':
            'By $actorName • Tap to see reason', // [HIỆN TÊN NGƯỜI TỪ CHỐI]
        'dotColor': colorRed,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'rejected_done',
      });
    } else if (status == RequestStatus.CANCELLED) {
      steps.add({
        'title': 'Request Cancelled',
        'time': processedTime,
        'actor': 'By You',
        'dotColor': Colors.grey,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'cancelled_done',
      });
    }
    return steps;
  }

  void _showRejectionDialog(BuildContext context) {
    // Format ngày giờ duyệt
    String approvedTime = '';
    if (_currentRequest.updatedAt != null) {
      approvedTime = DateFormat(
        'MMM dd, HH:mm',
      ).format(_currentRequest.updatedAt!);
    }

    // Tên người duyệt (hoặc mặc định Manager)
    String managerName = _currentRequest.approverName ?? "Manager";

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

              // Box nội dung lý do
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
                      '"${_currentRequest.rejectReason ?? "No reason provided."}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF334155),
                        height: 1.5,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        // [ĐÃ XÓA] decoration: TextDecoration.underline,
                        // [ĐÃ XÓA] decorationColor: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dòng hiển thị Người duyệt và Thời gian
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From: $managerName',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          approvedTime,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
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
    // [QUAN TRỌNG] Sử dụng _currentRequest thay vì widget.request để UI tự update
    final req = _currentRequest;
    final isPending = req.status == RequestStatus.PENDING;
    final isRejected = req.status == RequestStatus.REJECTED;
    final evidenceList = _getEvidenceUrls();

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
                        _buildMainStatusCard(
                          context,
                          isRejected,
                          req,
                        ), // Truyền req
                        const SizedBox(height: 24),
                        _buildInfoGrid(req), // Truyền req
                        const SizedBox(height: 24),
                        _buildSectionTitle('REASON'),
                        const SizedBox(height: 8),
                        Text(
                          '"${req.reason}"',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),

                        if (evidenceList.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle('ATTACHMENT'),
                          const SizedBox(height: 12),
                          ...evidenceList
                              .map(
                                (url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildAttachmentCard(url),
                                ),
                              )
                              .toList(),
                        ],

                        const SizedBox(height: 24),
                        _buildSectionTitle('APPROVAL WORKFLOW'),
                        const SizedBox(height: 16),
                        // [ĐÂY LÀ HÀM BẠN BỊ THIẾU Ở CÂU TRẢ LỜI TRƯỚC]
                        _buildWorkflowList(context),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

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

  // --- CÁC WIDGET CON ---

  Widget _buildMainStatusCard(
    BuildContext context,
    bool isRejected,
    RequestModel req,
  ) {
    String displayCode = req.requestCode != null && req.requestCode!.isNotEmpty
        ? req.requestCode!
        : (req.id?.toString().padLeft(4, '0') ?? "N/A");

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
          Container(height: 6, width: double.infinity, color: req.statusColor),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  req.type.name, // Dùng req.type.name
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#$displayCode',
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
                    color: req.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.status.name,
                    style: TextStyle(
                      color: req.statusColor,
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
                                  : AppColors.primary,
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

  Widget _buildInfoGrid(RequestModel req) {
    // TRƯỜNG HỢP 1: Đơn nghỉ phép (ANNUAL_LEAVE) -> Giao diện MỚI (Nét đứt)
    if (req.type == RequestType.ANNUAL_LEAVE) {
      final dateFormat = DateFormat('MMM dd, yyyy');

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            // From Date
            _buildDetailRow('From Date', dateFormat.format(req.startTime)),
            _buildDottedLine(),

            // To Date
            _buildDetailRow('To Date', dateFormat.format(req.endTime)),
            _buildDottedLine(),

            // Total Duration
            _buildDetailRow('Total Duration', req.duration, isBlue: true),
          ],
        ),
      );
    }
    // TRƯỜNG HỢP 2: Các loại đơn khác (Overtime, Late...) -> Giao diện CŨ (Kẻ liền)
    else {
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
            _buildSimpleInfoRow('Date', req.dateRange.split('•')[0].trim()),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            _buildSimpleInfoRow('Duration', req.duration),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            _buildSimpleInfoRow(
              'Time',
              req.dateRange.contains('•')
                  ? req.dateRange.split('•')[1].trim()
                  : "N/A",
            ),
          ],
        ),
      );
    }
  }

  // Widget hiển thị dòng chi tiết cho giao diện MỚI
  Widget _buildDetailRow(String label, String value, {bool isBlue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
            style: TextStyle(
              color: isBlue ? const Color(0xFF2563EB) : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  // Widget vẽ đường kẻ nét đứt cho giao diện MỚI
  Widget _buildDottedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 6.0;
          const dashSpace = 4.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // Widget hiển thị dòng chi tiết cho giao diện CŨ
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

  // [HÀM BỊ THIẾU ĐÃ ĐƯỢC BỔ SUNG]
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

// --- Class xem Ảnh Full ---
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
        // [MỚI] Dùng actions để nút nằm bên phải
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8), // Căn lề phải một chút
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

// --- Class xem Video Full ---
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
      if (!mounted) return; // Thêm dòng này
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
