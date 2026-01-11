import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/timesheet_model.dart';

class DailyTimesheetCard extends StatelessWidget {
  final TimesheetModel data;

  const DailyTimesheetCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isMissingCheckout = data.status == 'MISSING_CHECKOUT';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          // HEADER: Ngày + Tổng giờ làm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, dd/MM').format(data.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (isMissingCheckout)
                    const Text(
                      "Forgot to check out",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2260FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${data.totalWorkingHours}h",
                  style: const TextStyle(
                    color: Color(0xFF2260FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // BODY: Danh sách các ca làm việc
          ...data.sessions.map((session) {
            // [LOGIC MỚI] Kiểm tra có trễ không
            bool isLate = session.lateMinutes > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  // Icon chấm tròn trạng thái
                  Icon(
                    Icons.circle,
                    size: 8,
                    // Nếu trễ thì chấm màu cam/đỏ, bình thường màu xanh
                    color: isLate ? Colors.orange : const Color(0xFF00B894),
                  ),
                  const SizedBox(width: 8),

                  // --- GIỜ VÀO (CHECK-IN) ---
                  Text(
                    session.checkIn.length >= 5
                        ? session.checkIn.substring(0, 5)
                        : session.checkIn,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      // Nếu trễ đổi màu chữ thành đỏ
                      color: isLate ? Colors.red : const Color(0xFF1E293B),
                    ),
                  ),

                  // --- [HIỂN THỊ SỐ PHÚT TRỄ KẾ BÊN] ---
                  if (isLate)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Late ${session.lateMinutes}p",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // ------------------------------------
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_right_alt,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),

                  // --- GIỜ RA (CHECK-OUT) ---
                  Text(
                    session.checkOut != null
                        ? (session.checkOut!.length >= 5
                              ? session.checkOut!.substring(0, 5)
                              : session.checkOut!)
                        : "In progress...",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: session.checkOut == null
                          ? const Color(0xFFFA8231)
                          : Colors.black,
                    ),
                  ),

                  const Spacer(),
                  // Thời lượng
                  Text(
                    "${session.duration}h",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            );
          }),

          if (data.sessions.isEmpty)
            const Text(
              "Absent / No data",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}
