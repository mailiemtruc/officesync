import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';
import 'staff_job_page.dart';
import 'staff_application_forms_page.dart';

class StaffTaskScreen extends StatefulWidget {
  const StaffTaskScreen({super.key});

  @override
  State<StaffTaskScreen> createState() => _StaffTaskScreenState();
}

class _StaffTaskScreenState extends State<StaffTaskScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('STAFF', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Custom Tab Bar (Pill shape)
          Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "My Job"),
                Tab(text: "Application Forms"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // Tab View Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                StaffJobPage(),
                StaffApplicationFormsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}