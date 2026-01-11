# [FILE: services/attendance.py]

import datetime
import httpx
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

# --- 1. ĐỊNH NGHĨA SCHEMA ---
TOOL_DEF = {
    "function_declarations": [
        {
            "name": "get_attendance_history",
            "description": "Lấy chi tiết lịch sử Check-in/Check-out. Dùng cho: 'Hôm qua tôi đi làm lúc nào?', 'Sáng nay check-in chưa?', 'Lịch sử ngày 15'.",
            "parameters": {
                "type": "object",
                "properties": {
                    "day": {
                        "type": "integer", 
                        "description": "Ngày (1-31). Dựa vào 'hôm nay' để tính. VD: Nay 11, 'hôm qua' -> điền 10."
                    },
                    "month": {
                        "type": "integer", 
                        "description": "Tháng (1-12). TỰ TÍNH dựa vào tháng hiện tại. VD: Nay tháng 2, 'tháng trước' -> điền 1. Nay tháng 1, 'tháng trước' -> điền 12."
                    },
                    "year": {
                        "type": "integer", 
                        "description": "Năm. TỰ TÍNH. Lưu ý: Nếu lùi tháng ra khỏi năm hiện tại (VD: T1 lùi về T12) phải giảm năm đi 1."
                    }
                },
                "required": [] 
            }
        },
        {
            "name": "get_monthly_timesheet",
            "description": "Xem bảng công tổng hợp (Tổng giờ, số phút trễ). Dùng cho: 'Tháng trước tôi đi trễ bao nhiêu?', 'Công tháng này', 'Tháng 12 làm bao nhiêu giờ'.",
            "parameters": {
                "type": "object",
                "properties": {
                    "month": {
                        "type": "integer", 
                        "description": "Tháng (1-12). Nếu user nói 'tháng trước', hãy lấy tháng hiện tại TRỪ 1."
                    },
                    "year": {
                        "type": "integer", 
                        "description": "Năm. Lưu ý xử lý trường hợp chuyển giao năm (Giao thừa)."
                    }
                },
                "required": []
            }
        }
    ]
}

# --- 2. SYSTEM PROMPT (NÂNG CẤP LOGIC THỜI GIAN) ---
SYSTEM_PROMPT = """
--- HƯỚNG DẪN ATTENDANCE SERVICE ---

1. **QUY TẮC TÍNH THỜI GIAN (QUAN TRỌNG):**
   Bạn (AI) phải tự tính toán ngày tháng dựa trên "Thời gian hiện tại" được cung cấp ở đầu hội thoại. KHÔNG ĐƯỢC HỎI LẠI USER những câu dư thừa.
   
   *Ví dụ giả sử hôm nay là: 2026-01-11 (Tháng 1, Năm 2026)*
   - User: "Tháng này"   -> Gọi tool với `month=1, year=2026`.
   - User: "Tháng trước" -> Gọi tool với `month=12, year=2025` (Lùi 1 tháng, lùi 1 năm).
   - User: "Hôm qua"     -> Gọi tool với `day=10, month=1, year=2026`.
   - User: "Hôm kia"     -> Gọi tool với `day=9, month=1, year=2026`.

2. **Quy tắc hiển thị:**
   - Nếu `late_minutes_total` > 0: "Bạn đi trễ X phút" 🟠.
   - Nếu `status` == "MISSING_CHECKOUT": Cảnh báo quên check-out 🔴.
   - Nếu hỏi "Check-in chưa?": Nếu API trả về list rỗng -> "Chưa check-in".

3. **Phản hồi mẫu:**
   - User: "Tháng trước tôi có đi trễ không?"
   - AI (Sau khi gọi get_monthly_timesheet): "Dạ, trong tháng 12/2025, bạn có 3 ngày đi trễ (Tổng 45 phút) ạ 🟠."
"""

# --- 3. CÁC HÀM GỌI API ---
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

# --- 4. FORMATTERS ---
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
        
        # [QUAN TRỌNG] TÍNH TỔNG SỐ PHÚT TRỄ TRONG NGÀY
        total_late = 0
        sessions = day.get("sessions", [])
        if sessions:
            for s in sessions:
                # Cộng dồn lateMinutes từ từng ca (nếu có)
                total_late += s.get("lateMinutes", 0)

        summary.append({
            "date": day.get("date"),
            "total_hours": day.get("totalWorkingHours"),
            "status": day.get("status"),
            "sessions_count": len(sessions),
            "late_minutes_total": total_late  # <--- Trường quan trọng gửi cho AI
        })
    return summary

# --- 5. EXECUTE HANDLER ---
async def execute(user_id: int, args: Dict[str, Any], client: httpx.AsyncClient, settings: Any, tool_name: str = None) -> Any:
    # Lấy ngày hiện tại
    today = datetime.date.today()
    
    # Logic: Nếu AI gửi tham số (do nó tự tính), thì dùng tham số đó.
    # Nếu AI không gửi (None), thì fallback về today.
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