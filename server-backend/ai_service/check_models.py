import google.generativeai as genai
import os
from dotenv import load_dotenv

# Load key từ .env
load_dotenv()
api_key = os.getenv("GOOGLE_API_KEY")

if not api_key:
    print("❌ Lỗi: Không tìm thấy API Key trong file .env")
else:
    genai.configure(api_key=api_key)
    print(f"✅ Đang kiểm tra các model khả dụng cho Key: {api_key[:5]}...")

    try:
        print("\n--- DANH SÁCH MODEL ---")
        found = False
        for m in genai.list_models():
            # Chỉ hiện các model có hỗ trợ tạo nội dung (chat)
            if 'generateContent' in m.supported_generation_methods:
                print(f"🔹 Tên model: {m.name}")
                found = True
        
        if not found:
            print("⚠️ Không tìm thấy model nào. Hãy kiểm tra lại API Key của bạn.")
            
    except Exception as e:
        print(f"❌ Lỗi khi kết nối Google: {e}")