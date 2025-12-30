// features/task_service/presentation/pages/staff_application_forms_page.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../task_service/data/models/request_model.dart';

class StaffApplicationFormsPage extends StatefulWidget {
  const StaffApplicationFormsPage({super.key});

  @override
  State<StaffApplicationFormsPage> createState() => _StaffApplicationFormsPageState();
}

class _StaffApplicationFormsPageState extends State<StaffApplicationFormsPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  RequestType _selectedType = RequestType.leave;
  String _searchText = '';

  // Dữ liệu mẫu đã sửa lỗi Constructor
  final List<RequestModel> _myRequests = [
    RequestModel(
      id: '1',
      title: 'Sick Leave',
      description: 'Flu',
      type: RequestType.leave,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: RequestStatus.approved,
    ),
    RequestModel(
      id: '2',
      title: 'Overtime Project X',
      description: 'Urgent release',
      type: RequestType.overtime,
      createdAt: DateTime.now(),
      status: RequestStatus.pending,
    ),
  ];

  void _sendRequest() {
    if (_titleController.text.isEmpty) return;

    final newRequest = RequestModel(
      id: DateTime.now().toString(),
      title: _titleController.text,
      description: _descController.text,
      type: _selectedType,
      createdAt: DateTime.now(), // Đã khớp với Model
      status: RequestStatus.pending,
    );

    setState(() {
      _myRequests.insert(0, newRequest);
      _titleController.clear();
      _descController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (Giữ nguyên phần build UI Search Bar và List View như cũ)
    // Chỉ thay đổi phần hiển thị item để đảm bảo getters đúng
    final filteredList = _myRequests.where((req) {
      return req.title.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Phần Form nhập liệu giữ nguyên)
            // Copy lại phần Create Form từ code cũ của bạn vào đây
             Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<RequestType>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: RequestType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.name.toUpperCase()))).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _titleController, hintText: 'Title'),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _descController, hintText: 'Description', maxLines: 3),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendRequest,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text("List of Created Requests", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final req = filteredList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(req.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(DateFormat('dd/MM/yyyy').format(req.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                      _buildStatusBadge(req.status),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color color = status == RequestStatus.approved ? Colors.green : (status == RequestStatus.rejected ? Colors.red : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}