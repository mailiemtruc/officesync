# [FILE: attendance.py]

import datetime
import httpx
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

# --- 1. ĐỊNH NGHĨA SCHEMA (GIỮ NGUYÊN) ---
TOOL_DEF = {
    "function_declarations": [{
        "name": "get_attendance_history",
        "description": "Lấy dữ liệu lịch sử chấm công theo tháng hoặc ngày cụ thể.",
        "parameters": {
            "type": "object",
            "properties": {
                "day": {"type": "integer", "description": "Ngày cần xem (nếu người dùng hỏi ngày cụ thể)"},
                "month": {"type": "integer", "description": "Tháng cần xem (1-12)"},
                "year": {"type": "integer", "description": "Năm cần xem (VD: 2026)"}
            },
            "required": ["month", "year"]
        }
    }]
}

# --- [CẬP NHẬT MỚI] SYSTEM PROMPT ---
# Thay đổi: Dạy AI cách phân tích dữ liệu thay vì chỉ in ra.
SYSTEM_PROMPT = """
--- HƯỚNG DẪN XỬ LÝ DỮ LIỆU CHẤM CÔNG (ATTENDANCE) ---
Bạn sẽ nhận được dữ liệu JSON từ tool `get_attendance_history`. Hãy xử lý như sau:

1. **Phân tích câu hỏi của User:**
   - Nếu User hỏi: "Tôi có đi muộn không?", hãy trả lời thẳng vào vấn đề trước (Có/Không).
   - Nếu User hỏi chung chung: "Lịch sử chấm công", hãy liệt kê chi tiết.

2. **Quy tắc hiển thị (Tone & Style):**
   - Giọng điệu: Chuyên nghiệp, nhẹ nhàng, hữu ích.
   - **KHÔNG** hiển thị dạng bảng (Markdown Table).
   - Sử dụng Emoji để làm nổi bật:
     + 🟢: Normal / Đúng giờ
     + 🟠: Late / Đi muộn
     + 🔴: Early / Về sớm hoặc Check-out thiếu
     + 📍: Địa điểm

3. **Ví dụ phản hồi mong muốn:**
   *User: "Hôm nay tôi có đi muộn không?"*
   *AI:*
   "Dạ không, hôm nay bạn chấm công **đúng giờ** nhé! 👍
   
   Chi tiết chấm công ngày **10/01/2026**:
   - 🟢 **08:00** | Check-in | VP HCM
   - 🟢 **17:30** | Check-out | VP HCM"
"""

# --- 2. CÁC HÀM XỬ LÝ LOGIC ---
async def fetch_data(user_id: int, month: int, year: int, settings: Any, client: httpx.AsyncClient) -> List[Dict]:
    # (GIỮ NGUYÊN logic gọi API)
    url = f"{settings.ATTENDANCE_SERVICE_URL}/history"
    headers = {"X-User-Id": str(user_id), "Content-Type": "application/json"}
    params = {"month": month, "year": year}
    
    try:
        resp = await client.get(url, headers=headers, params=params)
        if resp.status_code == 200:
            return resp.json()
        return []
    except Exception as e:
        logger.error(f"Error fetching attendance: {e}")
        return []

# --- [CẬP NHẬT MỚI] TRẢ VỀ LIST/DICT THAY VÌ STRING ---
def format_response(data: List[Dict], day_filter: Optional[int] = None) -> List[Dict]:
    """
    Thay vì trả về string cứng nhắc, ta trả về List Dict đã lọc
    để Gemini tự do 'chém gió' dựa trên dữ liệu này.
    """
    if not data: return "NO_DATA"
    
    # Sắp xếp dữ liệu
    data.sort(key=lambda x: x.get("checkInTime", ""))
    result_list = []
    
    for item in data:
        raw = item.get("checkInTime")
        if not raw: continue
        try:
            dt = datetime.datetime.fromisoformat(raw)
            if day_filter and dt.day != day_filter: continue
            
            # Chỉ lấy các trường cần thiết để tiết kiệm token cho Gemini
            info = {
                "date": dt.strftime('%d/%m/%Y'),
                "time": dt.strftime('%H:%M:%S'),
                "type": item.get("type", "Check"),
                "status": item.get("status", "Unknown"), # Quan trọng: Để AI biết là Late hay Normal
                "location": item.get("locationName", "Unknown")
            }
            result_list.append(info)
        except: continue
        
    return result_list if result_list else "NO_DATA_MATCH_FILTER"

# --- 3. HÀM MAIN HANDLER ---
async def execute(user_id: int, args: Dict[str, Any], client: httpx.AsyncClient, settings: Any) -> Any:
    # (Cập nhật kiểu trả về là Any để support List/Dict)
    today = datetime.date.today()
    month = int(args.get("month", today.month))
    year = int(args.get("year", today.year))
    day = args.get("day")
    if day: day = int(day)

    raw_data = await fetch_data(user_id, month, year, settings, client)
    
    # Trả về list dict (JSON) thay vì string
    return format_response(raw_data, day_filter=day)