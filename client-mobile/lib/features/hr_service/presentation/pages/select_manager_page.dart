// import 'package:flutter/material.dart';
// import 'package:phosphor_flutter/phosphor_flutter.dart';
// import '../../../../core/config/app_colors.dart';
// import '../../data/models/employee_model.dart';
// import '../../widgets/employee_card.widget.dart';
// import '../../widgets/employee_bottom_sheet.dart';

// class SelectManagerPage extends StatefulWidget {
//   final String? selectedId;
//   const SelectManagerPage({super.key, this.selectedId});

//   @override
//   State<SelectManagerPage> createState() => _SelectManagerPageState();
// }

// class _SelectManagerPageState extends State<SelectManagerPage> {
//   final List<Employee> _employees = [
//     Employee(
//       id: "002",
//       name: "Tran Thi B",
//       role: "Staff",
//       department: "Human resource",
//       imageUrl: "https://i.pravatar.cc/150?img=5",
//     ),
//     Employee(
//       id: "001",
//       name: "Nguyen Van A",
//       role: "Manager",
//       department: "Business",
//       imageUrl: "https://i.pravatar.cc/150?img=11",
//     ),
//     Employee(
//       id: "003",
//       name: "Nguyen Van C",
//       role: "Staff",
//       department: "Technical",
//       imageUrl: "https://i.pravatar.cc/150?img=3",
//       isLocked: true,
//     ), // User bị khóa
//     Employee(
//       id: "004",
//       name: "Nguyen Van E",
//       role: "Manager",
//       department: "Human resource",
//       imageUrl: "https://i.pravatar.cc/150?img=8",
//     ),
//   ];

//   void _showEmployeeOptions(Employee emp) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => EmployeeBottomSheet(
//         employee: emp,
//         onToggleLock: () => setState(() => emp.isLocked = !emp.isLocked),
//         onDelete: () =>
//             setState(() => _employees.removeWhere((e) => e.id == emp.id)),
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
//             child: Column(
//               children: [
//                 const SizedBox(height: 20),
//                 // Header
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   child: Row(
//                     children: [
//                       IconButton(
//                         icon: const Icon(
//                           Icons.arrow_back_ios,
//                           size: 20,
//                           color: Colors.blue,
//                         ),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                       const Expanded(
//                         child: Center(
//                           child: Text(
//                             'SELECT MANAGER',
//                             style: TextStyle(
//                               color: AppColors.primary,
//                               fontSize: 20,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 40),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),

//                 // Search & Filter (ĐÃ ĐỒNG BỘ STYLE)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   child: Row(
//                     children: [
//                       Expanded(child: _buildSearchBar()),
//                       const SizedBox(width: 12),
//                       _buildFilterButton(),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 12),
//                 const Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       'ALL EMPLOYEES',
//                       style: TextStyle(
//                         color: Color(0xFF6B7280),
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),

//                 // List
//                 Expanded(
//                   child: ListView.builder(
//                     padding: const EdgeInsets.symmetric(horizontal: 24),
//                     itemCount: _employees.length,
//                     itemBuilder: (context, index) {
//                       final emp = _employees[index];
//                       final isSelected = emp.id == widget.selectedId;

//                       return EmployeeCard(
//                         name: emp.name,
//                         employeeId: emp.id,
//                         role: emp.role,
//                         department: emp.department,
//                         imageUrl: emp.imageUrl,
//                         isLocked: emp.isLocked,
//                         isSelected: isSelected,

//                         // Nếu bị khóa -> onTap là null (không chọn được)
//                         onTap: emp.isLocked
//                             ? null
//                             : () => Navigator.pop(context, emp),

//                         onMenuTap: () => _showEmployeeOptions(emp),

//                         // Widget chọn: Radio Button
//                         selectionWidget: Container(
//                           width: 24,
//                           height: 24,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: isSelected
//                                 ? AppColors.primary
//                                 : Colors.white,
//                             border: Border.all(
//                               color: isSelected
//                                   ? AppColors.primary
//                                   : const Color(0xFF9CA3AF),
//                               width: 1.5,
//                             ),
//                           ),
//                           // Nếu khóa -> không hiện dấu tick kể cả khi (lỡ) chọn
//                           child: isSelected && !emp.isLocked
//                               ? const Icon(
//                                   Icons.check,
//                                   size: 16,
//                                   color: Colors.white,
//                                 )
//                               : null,
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // Widget SearchBar (Đồng bộ font/màu)
//   Widget _buildSearchBar() {
//     return Container(
//       height: 45,
//       decoration: BoxDecoration(
//         color: const Color(0xFFF5F5F5),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
//       ),
//       child: TextField(
//         decoration: InputDecoration(
//           hintText: 'Search name, employee ID...',
//           hintStyle: const TextStyle(
//             color: Color(0xFF9E9E9E),
//             fontSize: 14,
//             fontWeight: FontWeight.w300,
//           ), // Font chuẩn
//           prefixIcon: Icon(
//             PhosphorIcons.magnifyingGlass(),
//             color: const Color(0xFF757575),
//             size: 20,
//           ), // Icon chuẩn
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(vertical: 10),
//         ),
//       ),
//     );
//   }

//   Widget _buildFilterButton() {
//     return Container(
//       width: 45,
//       height: 45,
//       decoration: BoxDecoration(
//         color: const Color(0xFFF5F5F5),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () {},
//           child: Icon(
//             PhosphorIcons.funnel(PhosphorIconsStyle.regular),
//             color: const Color(0xFF555252),
//             size: 20,
//           ),
//         ),
//       ),
//     );
//   }
// }
