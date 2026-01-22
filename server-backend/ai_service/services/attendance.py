# [FILE: services/attendance.py]

import datetime
import httpx
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

# --- 1. ĐỊNH NGHĨA SCHEMA (PHIÊN BẢN ĐÃ FIX LỖI HỎI LẠI) ---
TOOL_DEF = {
    "function_declarations": [
        {
            "name": "get_attendance_history",
            "description": "Lấy lịch sử chấm công. Hỗ trợ xem 'tất cả', 'hôm nay', 'tháng này'.",
            "parameters": {
                "type": "object",
                "properties": {
                    "day": {
                        "type": "integer", 
                        "description": "Ngày (1-31). BỎ TRỐNG nếu muốn xem toàn bộ tháng."
                    },
                    "month": {
                        "type": "integer", 
                        "description": "Tháng (1-12). QUAN TRỌNG: Nếu user không nói tháng nào, MẶC ĐỊNH lấy tháng hiện tại."
                    },
                    "year": {
                        "type": "integer", 
                        "description": "Năm. Mặc định năm hiện tại."
                    }
                },
                "required": [] # Bot tự tin điền default nhờ description ở trên
            }
        },
        {
            "name": "get_monthly_timesheet",
            "description": "Xem bảng công tổng hợp (Tổng giờ, số phút trễ).",
            "parameters": {
                "type": "object",
                "properties": {
                    "month": {
                        "type": "integer", 
                        "description": "Tháng (1-12). Mặc định tháng hiện tại."
                    },
                    "year": {
                        "type": "integer", 
                        "description": "Năm. Mặc định năm hiện tại."
                    }
                },
                "required": []
            }
        }
    ]
}

# --- 2. SYSTEM PROMPT (BỔ SUNG QUY TẮC 'XEM TẤT CẢ') ---
SYSTEM_PROMPT = """
--- HƯỚNG DẪN ATTENDANCE SERVICE ---

1. **QUY TẮC XỬ LÝ THỜI GIAN (BẮT BUỘC):**
   - User nói: "Xem tất cả", "Xem lịch sử", "Full history" -> **GỌI NGAY** tool với `month` và `year` hiện tại. KHÔNG ĐƯỢC HỎI LẠI "Ngày nào?".
   - User nói: "Tháng trước" -> Tự lùi 1 tháng.
   - User nói: "Hôm qua" -> Tự tính ngày hôm qua.

2. **Quy tắc hiển thị:**
   - Nếu `late_minutes` > 0: Thêm icon 🟠.
   - Nếu `status` == "MISSING_CHECKOUT": Cảnh báo 🔴.
   - Trả lời ngắn gọn, đi thẳng vào dữ liệu.
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
    if not data: return "Không tìm thấy dữ liệu (API trả về rỗng)."
    
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
                "type": item.get("type"),     
                "status": item.get("status"), 
                "late_minutes": item.get("lateMinutes", 0),
                "location": item.get("locationName")
            })
        except: continue
        
    if day_filter and not result: return "NO_RECORD_TODAY" 
    return result if result else "Không có dữ liệu."

def format_timesheet_response(data: List[Dict]) -> Any:
    if not data: return "Chưa có bảng công."
    summary = []
    for day in data:
        if day.get("totalWorkingHours", 0) == 0 and day.get("status") == "ABSENT": continue
        
        total_late = 0
        sessions = day.get("sessions", [])
        if sessions:
            first_session = sessions[0] 
            total_late = first_session.get("lateMinutes", 0)

        summary.append({
            "date": day.get("date"),
            "total_hours": day.get("totalWorkingHours"),
            "status": day.get("status"),
            "sessions_count": len(sessions),
            "late_minutes_total": total_late 
        })
    return summary

# --- 5. EXECUTE HANDLER ---
async def execute(user_id: int, args: Dict[str, Any], client: httpx.AsyncClient, settings: Any, tool_name: str = None) -> Any:
    today = datetime.date.today()
    
    # Logic fallback: Nếu Bot gửi None (do prompt bảo mặc định) -> code tự lấy today
    month = int(args.get("month") or today.month)
    year = int(args.get("year") or today.year)
    day = args.get("day")

    logger.info(f"🤖 Attendance Tool: {tool_name} | Params: day={day}, month={month}, year={year}")

    if tool_name == "get_attendance_history":
        raw_data = await fetch_history(user_id, month, year, settings, client)
        return format_history_response(raw_data, day_filter=int(day) if day else None)

    elif tool_name == "get_monthly_timesheet":
        raw_data = await fetch_timesheet(user_id, month, year, settings, client)
        return format_timesheet_response(raw_data)

    return "Function not supported."