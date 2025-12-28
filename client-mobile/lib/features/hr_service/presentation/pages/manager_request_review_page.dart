// import 'package:flutter/material.dart';
// import 'package:phosphor_flutter/phosphor_flutter.dart';
// import 'dart:ui';
// import '../../../../core/config/app_colors.dart';
// import '../../data/models/request_model.dart';
// import '../../widgets/confirm_bottom_sheet.dart';

// class ManagerRequestReviewPage extends StatefulWidget {
//   final RequestModel request;
//   final String employeeName;
//   final String employeeId;
//   final String employeeDept;
//   final String employeeAvatar;

//   const ManagerRequestReviewPage({
//     super.key,
//     required this.request,
//     this.employeeName = "Nguyen Van A",
//     this.employeeId = "001",
//     this.employeeDept = "Business",
//     this.employeeAvatar = "https://i.pravatar.cc/150?img=11",
//   });

//   @override
//   State<ManagerRequestReviewPage> createState() =>
//       _ManagerRequestReviewPageState();
// }

// class _ManagerRequestReviewPageState extends State<ManagerRequestReviewPage> {
//   final TextEditingController _rejectReasonController = TextEditingController();

//   // --- 1. REJECT BOTTOM SHEET ---
//   void _showRejectBottomSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: Container(
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
//           ),
//           padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Drag Handle
//               Center(
//                 child: Container(
//                   width: 48,
//                   height: 5,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFE5E7EB),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 24),

//               // Title
//               const Text(
//                 'Reason for Rejection',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w700,
//                   fontFamily: 'Inter',
//                   color: Colors.black,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // Description
//               const Text(
//                 'Please clarify why this request is rejected. This reason will be sent to the employee.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontSize: 16,
//                   fontFamily: 'Inter',
//                   fontWeight: FontWeight.w400,
//                   height: 1.4,
//                 ),
//               ),
//               const SizedBox(height: 24),

//               // Text Field
//               Container(
//                 height: 152,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: const Color(0xFFB6C1E0), width: 1),
//                 ),
//                 child: TextField(
//                   controller: _rejectReasonController,
//                   maxLines: 5,
//                   style: const TextStyle(
//                     fontFamily: 'Inter',
//                     fontSize: 16,
//                     color: Colors.black,
//                   ),
//                   decoration: const InputDecoration.collapsed(
//                     hintText:
//                         'E.g. Not enough leave balance, Urgent deadline...',
//                     hintStyle: TextStyle(
//                       color: Color(0xFFA5ADC6),
//                       fontSize: 16,
//                       fontFamily: 'Inter',
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 32),

//               // Buttons
//               Row(
//                 children: [
//                   Expanded(
//                     child: _buildSheetButton(
//                       label: 'Cancel',
//                       bgColor: const Color(0xFFF3F4F6),
//                       textColor: const Color(0xFF374151),
//                       onTap: () => Navigator.pop(context),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: _buildSheetButton(
//                       label: 'Confirm',
//                       bgColor: const Color(0xFFDC2626),
//                       textColor: Colors.white,
//                       onTap: () {
//                         Navigator.pop(context);
//                         Navigator.pop(context);
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Nút trong Bottom Sheet (Bo tròn 50)
//   Widget _buildSheetButton({
//     required String label,
//     required Color bgColor,
//     required Color textColor,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       height: 45,
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(50),
//         // Không đổ bóng theo yêu cầu mới
//       ),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(50),
//         child: InkWell(
//           onTap: onTap,
//           borderRadius: BorderRadius.circular(50),
//           child: Center(
//             child: Text(
//               label,
//               style: TextStyle(
//                 color: textColor,
//                 fontSize: 16, // Cỡ chữ 16 thống nhất
//                 fontWeight: FontWeight.w700,
//                 fontFamily: 'Inter',
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // --- XỬ LÝ APPROVE ---
//   void _handleApprove() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (context) => ConfirmBottomSheet(
//         title: 'Approve Request?',
//         message: 'This request will be marked as Approved.',
//         confirmText: 'Approve',
//         confirmColor: const Color(0xFF2260FF),
//         onConfirm: () {
//           Navigator.pop(context);
//           Navigator.pop(context);
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF9F9F9),
//       body: SafeArea(
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 600),
//             child: Stack(
//               children: [
//                 Column(
//                   children: [
//                     const SizedBox(height: 20),
//                     _buildHeader(context),
//                     const SizedBox(height: 24),
//                     Expanded(
//                       child: SingleChildScrollView(
//                         padding: const EdgeInsets.symmetric(horizontal: 24),
//                         child: Column(
//                           children: [
//                             _buildEmployeeInfoCard(),
//                             const SizedBox(height: 16),
//                             _buildRequestDetailCard(),
//                             const SizedBox(height: 100),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 // Bottom Bar
//                 Positioned(
//                   left: 24,
//                   right: 24,
//                   bottom: 24,
//                   child: Row(
//                     children: [
//                       // NÚT REJECT
//                       Expanded(
//                         child: Container(
//                           height: 45,
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFFFE4E4),
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(
//                               color: const Color(0xFFEF4444),
//                               width: 0.5, // Viền rõ hơn (1.0)
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.1),
//                                 blurRadius: 4,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ],
//                           ),
//                           child: Material(
//                             color: Colors.transparent,
//                             borderRadius: BorderRadius.circular(10),
//                             child: InkWell(
//                               onTap: () => _showRejectBottomSheet(context),
//                               borderRadius: BorderRadius.circular(10),
//                               splashColor: const Color(
//                                 0xFFFECACA,
//                               ).withOpacity(0.5), // Hiệu ứng đỏ nhạt
//                               highlightColor: const Color(
//                                 0xFFFECACA,
//                               ).withOpacity(0.3),
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     PhosphorIcons.x(
//                                       PhosphorIconsStyle.bold,
//                                     ), // Icon X
//                                     color: const Color(0xFFEF4444),
//                                     size: 18,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   const Text(
//                                     'Reject',
//                                     style: TextStyle(
//                                       color: Color(0xFFEF4444),
//                                       fontSize: 16, // Thống nhất 16
//                                       fontWeight: FontWeight.w700,
//                                       fontFamily: 'Inter',
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),

//                       // NÚT APPROVE
//                       Expanded(
//                         child: Container(
//                           height: 45,
//                           decoration: BoxDecoration(
//                             color: const Color(0xFF2260FF),
//                             borderRadius: BorderRadius.circular(10),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.1),
//                                 blurRadius: 4,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ],
//                           ),
//                           child: Material(
//                             color: Colors.transparent,
//                             borderRadius: BorderRadius.circular(10),
//                             child: InkWell(
//                               onTap: _handleApprove,
//                               borderRadius: BorderRadius.circular(10),

//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     PhosphorIcons.check(
//                                       PhosphorIconsStyle.bold,
//                                     ), // Icon Check
//                                     color: Colors.white,
//                                     size: 18,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   const Text(
//                                     'Approve',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 16, // Thống nhất 16
//                                       fontWeight: FontWeight.w700,
//                                       fontFamily: 'Inter',
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // --- WIDGETS CON ---

//   Widget _buildHeader(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 24),
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           Align(
//             alignment: Alignment.centerLeft,
//             child: IconButton(
//               padding: EdgeInsets.zero,
//               constraints: const BoxConstraints(),
//               icon: Icon(
//                 PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
//                 color: const Color(0xFF2260FF),
//                 size: 24,
//               ),
//               onPressed: () => Navigator.pop(context),
//             ),
//           ),
//           const Text(
//             'REVIEW REQUEST',
//             style: TextStyle(
//               color: Color(0xFF2260FF),
//               fontSize: 24,
//               fontFamily: 'Inter',
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmployeeInfoCard() {
//     final bool isManager = ['001', '004'].contains(widget.employeeId);
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0x4CF1F1F1)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0C000000),
//             blurRadius: 10,
//             offset: Offset(0, 0),
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           ClipOval(
//             child: Image.network(
//               widget.employeeAvatar,
//               width: 46,
//               height: 46,
//               fit: BoxFit.cover,
//               errorBuilder: (_, __, ___) =>
//                   Container(width: 46, height: 46, color: Colors.grey[200]),
//             ),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Flexible(
//                       child: Text(
//                         widget.employeeName,
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           fontFamily: 'Inter',
//                           color: Colors.black,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     if (isManager) ...[
//                       const SizedBox(width: 8),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFECF1FF),
//                           borderRadius: BorderRadius.circular(5),
//                         ),
//                         child: const Text(
//                           'Manager',
//                           style: TextStyle(
//                             color: Color(0xFF2260FF),
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             fontFamily: 'Inter',
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Employee ID: ${widget.employeeId} | ${widget.employeeDept}',
//                   style: const TextStyle(
//                     color: Color(0xFF555252),
//                     fontSize: 13,
//                     fontWeight: FontWeight.w300,
//                     fontFamily: 'Inter',
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//             decoration: BoxDecoration(
//               color: const Color(0xFFFFF7ED),
//               borderRadius: BorderRadius.circular(30),
//             ),
//             child: const Text(
//               'Pending',
//               style: TextStyle(
//                 color: Color(0xFFEA580C),
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 fontFamily: 'Inter',
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRequestDetailCard() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0x4CF1F1F1)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0C000000),
//             blurRadius: 10,
//             offset: Offset(0, 0),
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: const Color(0xFFECF1FF),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Text(
//               widget.request.title,
//               style: const TextStyle(
//                 color: Color(0xFF2260FF),
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 fontFamily: 'Inter',
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             '#REQ-${widget.request.id.padLeft(4, '0')}',
//             style: const TextStyle(
//               color: Color(0xFF94A3B8),
//               fontSize: 14,
//               fontFamily: 'Inter',
//               fontWeight: FontWeight.w400,
//             ),
//           ),
//           const SizedBox(height: 24),

//           _buildDynamicDetails(),

//           const SizedBox(height: 24),

//           const Text(
//             'REASON',
//             style: TextStyle(
//               color: Color(0xFF94A3B8),
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               fontFamily: 'Inter',
//             ),
//           ),
//           const SizedBox(height: 8),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF8FAFC),
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: const Color(0xFFA1ACCC)),
//             ),
//             child: Text(
//               '"${widget.request.description}"',
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontSize: 14,
//                 fontStyle: FontStyle.italic,
//                 fontWeight: FontWeight.w300,
//                 fontFamily: 'Inter',
//                 height: 1.5,
//               ),
//             ),
//           ),

//           const SizedBox(height: 24),

//           Row(
//             children: [
//               Icon(
//                 PhosphorIcons.paperclip(),
//                 size: 20,
//                 color: const Color(0xFF2563EB),
//               ),
//               const SizedBox(width: 8),
//               const Text(
//                 'View Attachment (PDF)',
//                 style: TextStyle(
//                   color: Color(0xFF2563EB),
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   fontFamily: 'Inter',
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDynamicDetails() {
//     return Column(
//       children: [
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // BỎ ICON, CHỈ GIỮ TEXT
//             Expanded(child: _buildInfoItem('DATE', 'Oct 12, 2025')),
//             Expanded(
//               child: _buildInfoItem(
//                 'DURATION',
//                 widget.request.duration,
//                 isBlue: true,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 24),
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(child: _buildInfoItem('END OF SHIFT', '05:30 PM')),
//             Expanded(child: _buildInfoItem('ACTUAL LEAVE', '04:30 PM')),
//           ],
//         ),
//       ],
//     );
//   }

//   // Cập nhật lại: Không nhận tham số Icon nữa
//   Widget _buildInfoItem(String label, String value, {bool isBlue = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             color: Color(0xFF94A3B8),
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             fontFamily: 'Inter',
//           ),
//         ),
//         const SizedBox(height: 6),
//         Text(
//           value,
//           style: TextStyle(
//             color: isBlue ? const Color(0xFF2563EB) : Colors.black,
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             fontFamily: 'Inter',
//           ),
//         ),
//       ],
//     );
//   }
// }
