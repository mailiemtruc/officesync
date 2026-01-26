# [FILE: services/attendance.py]
import datetime
import httpx
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

# --- 1. ĐỊNH NGHĨA SCHEMA (GIỮ NGUYÊN) ---
TOOL_DEF = {
    "function_declarations": [
        {
            "name": "get_attendance_history",
            "description": "Lấy lịch sử chấm công. Hỗ trợ xem cụ thể ngày hoặc cả tháng.",
            "parameters": {
                "type": "object",
                "properties": {
                    "day": {"type": "integer", "description": "Ngày cụ thể (1-31)."},
                    "month": {"type": "integer", "description": "Tháng (1-12)."},
                    "year": {"type": "integer", "description": "Năm (YYYY)."}
                },
                "required": [] 
            }
        },
        {
            "name": "get_monthly_timesheet",
            "description": "Xem bảng công tổng hợp (Tổng giờ, số phút trễ) theo tháng.",
            "parameters": {
                "type": "object",
                "properties": {
                    "month": {"type": "integer", "description": "Tháng cần xem."},
                    "year": {"type": "integer", "description": "Năm cần xem."}
                },
                "required": []
            }
        }
    ]
}

# --- 2. SYSTEM PROMPT (TỐI ƯU HÓA CHO LOGIC THỜI GIAN THỰC) ---
SYSTEM_PROMPT = """
--- HƯỚNG DẪN DỊCH VỤ CHẤM CÔNG ---
1. **XỬ LÝ THỜI GIAN**: 
   - Bạn PHẢI sử dụng 'Thời gian hệ thống' được cung cấp để tính toán ngày/tháng trước khi gọi tool.
   - Nếu User hỏi về "Hôm nay", "Sáng nay", "Vừa nãy": Điền chính xác ngày, tháng, năm hiện tại vào tham số.
   - Nếu User hỏi "Tháng trước": Tự thực hiện phép trừ tháng và điền vào tool.

2. **QUY TẮC HIỂN THỊ**:
   - Luôn sử dụng icon 🟠 cho trường hợp đi trễ (`late_minutes` > 0).
   - Sử dụng cảnh báo 🔴 nếu trạng thái là `MISSING_CHECKOUT`.
   - Trả lời bằng ngôn ngữ người dùng đã thiết lập (Vietnamese/English).
"""

# --- 3. CÁC HÀM GỌI API (GIỮ NGUYÊN) ---
async def fetch_history(user_id: int, month: int, year: int, settings: Any, client: httpx.AsyncClient) -> List[Dict]:
    url = f"{settings.ATTENDANCE_SERVICE_URL}/history"
    headers = {"X-User-Id": str(user_id)}
    params = {"month": month, "year": year}
    try:
        resp = await client.get(url, headers=headers, params=params)
        return resp.json() if resp.status_code == 200 else []
    except Exception as e:
        logger.error(f"Error fetching history: {e}")
        return []

async def fetch_timesheet(user_id: int, month: int, year: int, settings: Any, client: httpx.AsyncClient) -> List[Dict]:
    url = f"{settings.ATTENDANCE_SERVICE_URL}/timesheet"
    headers = {"X-User-Id": str(user_id)}
    params = {"month": month, "year": year}
    try:
        resp = await client.get(url, headers=headers, params=params)
        return resp.json() if resp.status_code == 200 else []
    except Exception as e:
        logger.error(f"Error fetching timesheet: {e}")
        return []

# --- 4. FORMATTERS (GIỮ NGUYÊN) ---
def format_history_response(data: List[Dict], day_filter: Optional[int] = None) -> Any:
    if not data: return "Không tìm thấy dữ liệu chấm công."
    result = []
    for item in data:
        raw = item.get("checkInTime")
        if not raw: continue
        try:
            dt = datetime.datetime.fromisoformat(raw)
            if day_filter and dt.day != day_filter: continue
            result.append({
                "date": dt.strftime('%d/%m/%Y'),
                "time": dt.strftime('%H:%M:%S'),
                "status": item.get("status"), 
                "late_minutes": item.get("lateMinutes", 0),
                "location": item.get("locationName")
            })
        except: continue
    if day_filter and not result: return "Không có bản ghi nào cho ngày này." 
    return result if result else "Không có dữ liệu trong khoảng thời gian này."

def format_timesheet_response(data: List[Dict]) -> Any:
    if not data: return "Chưa có dữ liệu bảng công cho tháng này."
    summary = []
    for day in data:
        if day.get("totalWorkingHours", 0) == 0 and day.get("status") == "ABSENT": continue
        summary.append({
            "date": day.get("date"),
            "total_hours": day.get("totalWorkingHours"),
            "status": day.get("status"),
            "late_minutes": day.get("sessions", [{}])[0].get("lateMinutes", 0) if day.get("sessions") else 0
        })
    return summary

# --- 5. EXECUTE HANDLER (CẢI TIẾN VIỆC ÉP KIỂU) ---
async def execute(user_id: int, args: Dict[str, Any], client: httpx.AsyncClient, settings: Any, tool_name: str = None) -> Any:
    today = datetime.date.today()
    
    # Ép kiểu an toàn từ AI gửi về (AI thường gửi dạng số hoặc chuỗi số)
    try:
        month = int(args.get("month")) if args.get("month") else today.month
        year = int(args.get("year")) if args.get("year") else today.year
        day = int(args.get("day")) if args.get("day") else None
        
        # Sửa lỗi nếu AI tính toán tháng bị tràn (ví dụ tháng 0 hoặc 13)
        if month < 1:
            month = 12
            year -= 1
        elif month > 12:
            month = 1
            year += 1
    except (ValueError, TypeError):
        month, year, day = today.month, today.year, None

    logger.info(f"🚀 [Attendance Tool] {tool_name} | Target: {day}/{month}/{year}")

    if tool_name == "get_attendance_history":
        raw_data = await fetch_history(user_id, month, year, settings, client)
        return format_history_response(raw_data, day_filter=day)

    elif tool_name == "get_monthly_timesheet":
        raw_data = await fetch_timesheet(user_id, month, year, settings, client)
        return format_timesheet_response(raw_data)

    return "Yêu cầu không được hỗ trợ."