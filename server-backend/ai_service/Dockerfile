# Giữ nguyên 3.10 để đảm bảo tương thích thư viện AI tốt nhất
FROM python:3.10-slim

WORKDIR /app

# Tối ưu cache python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# [QUAN TRỌNG] Thiết lập giờ Việt Nam
ENV TZ=Asia/Ho_Chi_Minh

# Cài đặt tzdata (vì image slim không có sẵn)
RUN apt-get update && \
    apt-get install -y tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Upgrade pip để tránh lỗi khi cài các thư viện AI mới
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]