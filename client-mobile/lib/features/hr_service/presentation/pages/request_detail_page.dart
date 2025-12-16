import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';

class RequestDetailPage extends StatelessWidget {
  final RequestModel request;

  const RequestDetailPage({super.key, required this.request});

  // --- LOGIC WORKFLOW CHUẨN ---
  List<Map<String, dynamic>> _getWorkflowSteps() {
    // Định nghĩa các màu chuẩn (Solid - Không trong suốt)
    const colorGreen = Color(0xFF10B981);
    const colorRed = Color(0xFFDC2626);
    const colorBlue = Color(0xFF2563EB);
    // Màu xám thống nhất cho đường kẻ
    const colorGrey = Color(0xFFCBD5E1);

    final steps = [
      {
        'title': 'Request Submitted',
        'time': 'Oct 10, 2025 • 09:30 AM',
        'actor': 'By: Nguyen Van A',
        'dotColor': colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': 'done',
      },
      {
        'title': 'Manager Review',
        'time': request.status == RequestStatus.pending
            ? 'Processing...'
            : 'Reviewed',
        'actor': 'Assignee: Tran Thi B',
        'dotColor': request.status == RequestStatus.pending
            ? colorBlue
            : colorGreen,
        'lineColor': colorGrey,
        'isLast': false,
        'status': request.status == RequestStatus.pending ? 'current' : 'done',
      },
    ];

    if (request.status == RequestStatus.pending) {
      steps.add({
        'title': 'Final Decision',
        'time': 'Waiting for approval',
        'actor': '',
        'dotColor': colorGrey,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'waiting',
      });
    } else if (request.status == RequestStatus.approved) {
      steps.add({
        'title': 'Request Approved',
        'time': 'Oct 20 • 09:20 AM',
        'actor': 'System updated successfully.',
        'dotColor': const Color(0xFF10B981),
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'approved_done',
      });
    } else if (request.status == RequestStatus.rejected) {
      steps.add({
        'title': 'Request Rejected',
        'time': 'Oct 20 • 09:20 AM',
        'actor': 'Tap \'See reason\' for details',
        'dotColor': colorRed,
        'lineColor': Colors.transparent,
        'isLast': true,
        'status': 'rejected_done',
      });
    }
    return steps;
  }

  // --- DIALOG LÝ DO TỪ CHỐI ---
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
                    splashColor: Colors.transparent,
                    highlightColor: Colors.grey.withOpacity(0.2),
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
                  children: const [
                    Text(
                      '"Please plan your commute better. We have a strict client meeting at 8:30 AM every Monday that cannot be missed."',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF334155),
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 12),
                    Divider(height: 1, color: Color(0xFFE2E8F0)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From: Tran Thi B',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          'Oct 20, 09:15',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
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
                  style:
                      ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        splashFactory: NoSplash.splashFactory,
                      ).copyWith(
                        overlayColor: MaterialStateProperty.all(
                          Colors.white.withOpacity(0.25),
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
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == RequestStatus.pending;
    final isRejected = request.status == RequestStatus.rejected;

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
                          '"${request.description}"',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('ATTACHMENT'),
                        const SizedBox(height: 12),
                        _buildAttachmentCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('APPROVAL WORKFLOW'),
                        const SizedBox(height: 16),
                        _buildWorkflowList(context),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                // NÚT CANCEL REQUEST
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => _showCancelDialog(context),
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
                                splashFactory: NoSplash.splashFactory,
                              ).copyWith(
                                overlayColor: MaterialStateProperty.all(
                                  const Color(0xFFDC2626).withOpacity(0.1),
                                ),
                              ),
                          child: Row(
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS CON ---

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
            color: request.statusColor,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  request.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#REQ-${request.id.padLeft(4, '0')}',
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
                    color: request.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.statusText.toUpperCase(),
                    style: TextStyle(
                      color: request.statusColor,
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
                      splashColor: Colors.transparent,
                      highlightColor: Colors.grey.withOpacity(0.2),
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
    if (request.type == RequestType.leave) {
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
            _buildInfoRow('From Date', 'Oct 24, 2025', '08:00 AM'),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildInfoRow('To Date', 'Oct 26, 2025', '05:30 PM'),
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
                  '3 Days',
                  style: TextStyle(
                    color: const Color(0xFF2563EB),
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
            _buildSimpleInfoRow('Date', 'Oct 24, 2025'),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildSimpleInfoRow('Duration', request.duration),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildSimpleInfoRow('Time', '08:00 - 11:00 AM'),
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

  Widget _buildAttachmentCard() {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ticket_booking.jpg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  '2.4 MB',
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
              splashColor: Colors.transparent,
              highlightColor: Colors.grey.withOpacity(0.2),
              onTap: () {},
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
        FontWeight titleWeight = FontWeight.bold; // Mặc định là Bold

        if (status == 'approved_done') {
          titleColor = const Color(0xFF10B981); // Solid Green
          actorColor = const Color(0xFF10B981);
          // SỬA: Tăng độ đậm lên mức cao nhất (Black - w900)
          titleWeight = FontWeight.w900;
        } else if (status == 'rejected_done') {
          titleColor = const Color(0xFFDC2626);
          actorColor = const Color(0xFFF87171);
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
                          fontWeight: titleWeight, // Dùng biến này
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
                                  // SỬA: Trả lại in nghiêng (italic)
                                  fontStyle: FontStyle.italic,
                                  // SỬA: Bỏ độ đậm w500 để trông thanh thoát hơn
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
