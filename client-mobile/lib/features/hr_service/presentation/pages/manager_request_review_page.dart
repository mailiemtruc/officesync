import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../data/datasources/request_remote_data_source.dart';

class ManagerRequestReviewPage extends StatefulWidget {
  final RequestModel request;
  const ManagerRequestReviewPage({super.key, required this.request});
  @override
  State<ManagerRequestReviewPage> createState() =>
      _ManagerRequestReviewPageState();
}

class _ManagerRequestReviewPageState extends State<ManagerRequestReviewPage> {
  final TextEditingController _rejectReasonController = TextEditingController();

  late final RequestRepositoryImpl _repository;
  final _storage = const FlutterSecureStorage();
  bool _isProcessing = false;
  late RequestModel _currentRequest;
  StompClient? stompClient;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request; // Khởi tạo
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
    _connectWebSocket(); // [MỚI] Lắng nghe
  }

  // [SỬA LỖI QUAN TRỌNG]: Bỏ check userId để đảm bảo socket luôn kết nối
  void _connectWebSocket() {
    // Thay IP phù hợp (10.0.2.2 cho Android Emulator)
    final socketUrl = 'ws://10.0.2.2:8081/ws-hr/websocket';

    stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          print("--> [ManagerReview] Connected WS");
          final topic = '/topic/request/${widget.request.id}';

          stompClient!.subscribe(
            destination: topic,
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> data = jsonDecode(frame.body!);
                final updatedReq = RequestModel.fromJson(data);

                if (mounted) {
                  setState(() {
                    _currentRequest = updatedReq;
                  });

                  // Hiển thị thông báo nếu trạng thái thay đổi
                  if (updatedReq.status != RequestStatus.PENDING) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Request updated to: ${updatedReq.status.name}",
                        ),
                        backgroundColor: _getStatusColor(updatedReq.status),
                        duration: const Duration(seconds: 2),
                      ),
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
    stompClient?.deactivate();
    _rejectReasonController.dispose();
    super.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Lỗi: Không tìm thấy thông tin người dùng. Vui lòng đăng nhập lại.",
              ),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Xử lý thất bại. Vui lòng thử lại."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
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

  // [ĐÃ SỬA LỖI TẠI ĐÂY] Dùng biến req để hiển thị, xóa hardcode 'Pending'
  Widget _buildEmployeeInfoCard(RequestModel req) {
    // Check tạm ID để hiển thị badge Manager
    final bool isManager = ['001', '004'].contains(req.requesterId);

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
          ClipOval(
            child: Image.network(
              req.requesterAvatar.isNotEmpty
                  ? req.requesterAvatar
                  : "https://ui-avatars.com/api/?name=${req.requesterName}",
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 46,
                height: 46,
                color: Colors.grey[200],
                child: const Icon(Icons.person),
              ),
            ),
          ),
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
                    fontWeight: FontWeight.w300,
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
          Text(
            '#REQ-${request.id}',
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

          const SizedBox(height: 24),

          // Hiển thị phần đính kèm nếu có
          if (request.evidenceUrl != null &&
              request.evidenceUrl!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  PhosphorIcons.paperclip(),
                  size: 20,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                const Text(
                  'View Attachment (PDF/Image)',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text("No Attachment", style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicDetails(RequestModel request) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildInfoItem('DATE', request.dateRange)),
            Expanded(
              child: _buildInfoItem('DURATION', request.duration, isBlue: true),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildInfoItem('END OF SHIFT', '05:30 PM')),
            Expanded(child: _buildInfoItem('ACTUAL LEAVE', '04:30 PM')),
          ],
        ),
      ],
    );
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
