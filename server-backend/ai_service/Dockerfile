# Sử dụng Python 3.10 slim (nhẹ và ổn định)
FROM python:3.10-slim

# Thiết lập thư mục làm việc trong container
WORKDIR /app

# Đặt biến môi trường để Python không tạo file .pyc và log in ngay lập tức
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Copy file requirements trước để tận dụng cache của Docker
COPY requirements.txt .

# Cài đặt các thư viện
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ code vào container (bao gồm cả folder services)
COPY . .

# Mở port 5000 (khớp với code main.py của bạn)
EXPOSE 5000

# Lệnh chạy ứng dụng
# Lưu ý: host 0.0.0.0 là bắt buộc để truy cập được từ bên ngoài container
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]