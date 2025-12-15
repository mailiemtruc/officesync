import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/config/app_colors.dart'; // Đảm bảo đường dẫn đúng tới file config màu

class SelectionBottomSheet extends StatefulWidget {
  final String title;
  // Danh sách item dạng Map: {'id': '...', 'title': '...', 'desc': '...'}
  final List<Map<String, String>> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const SelectionBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<SelectionBottomSheet> createState() => _SelectionBottomSheetState();
}

class _SelectionBottomSheetState extends State<SelectionBottomSheet> {
  String? _tempSelectedId;

  @override
  void initState() {
    super.initState();
    _tempSelectedId = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Responsive: Giới hạn chiều rộng trên Tablet
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Handle Bar (Thanh gạch ngang)
              Center(
                child: Container(
                  width: 35,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. HEADER: Tiêu đề + Nút Đóng (X)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tiêu đề
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),

                  // Nút Đóng (X) tròn màu xám
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB), // Màu nền xám nhạt
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF6B7280), // Màu icon xám đậm
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Danh sách lựa chọn (List Items)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = _tempSelectedId == item['id'];

                    return GestureDetector(
                      onTap: () => setState(() => _tempSelectedId = item['id']),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Nếu chọn: nền xanh nhạt, viền xanh. Không chọn: nền trắng, viền xám nhạt
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFDDE3F5)
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon Box bên trái
                            Container(
                              width: 46,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                isSelected
                                    ? PhosphorIcons.check(
                                        PhosphorIconsStyle.bold,
                                      )
                                    : PhosphorIcons.buildings(),
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Nội dung text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title']!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF1E40AF)
                                          : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item['desc'] != null &&
                                      item['desc']!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item['desc']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(
                                                0xFF1E40AF,
                                              ).withOpacity(0.7)
                                            : const Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Radio Circle (Vòng tròn chọn)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF94A3B8),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 4. Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _tempSelectedId == null
                      ? null // Disable nếu chưa chọn gì
                      : () => widget.onSelected(_tempSelectedId!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm Selection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
}
