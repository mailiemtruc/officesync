package com.officesync.hr_service.Config;

import org.springframework.stereotype.Component;

/**
 * Snowflake ID Generator (Phiên bản Single Server)
 * Đảm bảo:
 * 1. ID Duy nhất toàn cầu (Unique).
 * 2. Tăng dần theo thời gian (Sortable).
 * 3. An toàn tuyệt đối với đa luồng (Thread-safe).
 */
@Component
public class SnowflakeIdGenerator {

    // CẤU HÌNH CỨNG: ID của Server này là 1 (Vì bạn chạy 1 server duy nhất)
    private final long machineId = 1L;

    // Mốc thời gian bắt đầu (Epoch): 01/01/2024 (Giúp ID nhỏ gọn hơn so với dùng từ năm 1970)
    private final long epoch = 1704067200000L;

    // Cấu hình số Bit
    private final long sequenceBits = 12L;   // 12 bit cho số thứ tự (tối đa 4096 ID/mili-giây)
    private final long machineIdBits = 10L;  // 10 bit cho mã máy (tối đa 1024 máy)

    // Tính toán dịch chuyển Bit (Shift)
    private final long machineIdShift = sequenceBits;
    private final long timestampLeftShift = sequenceBits + machineIdBits;
    
    // Mặt nạ để reset sequence (4095)
    private final long sequenceMask = -1L ^ (-1L << sequenceBits);

    // Biến lưu trạng thái
    private long sequence = 0L;
    private long lastTimestamp = -1L;

    /**
     * Hàm sinh ID kế tiếp.
     * Từ khóa 'synchronized' đảm bảo chỉ 1 luồng được chạy tại 1 thời điểm.
     * Nếu 1000 người bấm cùng lúc, họ sẽ được xếp hàng lần lượt -> KHÔNG BAO GIỜ TRÙNG.
     */
    public synchronized long nextId() {
        long timestamp = System.currentTimeMillis();

        // Trường hợp hiếm: Đồng hồ hệ thống bị quay ngược -> Báo lỗi ngay để bảo vệ dữ liệu
        if (timestamp < lastTimestamp) {
            throw new RuntimeException("Clock moved backwards. Refusing to generate id");
        }

        // Nếu trùng thời điểm (cùng 1 mili-giây)
        if (lastTimestamp == timestamp) {
            // Tăng số thứ tự lên 1
            sequence = (sequence + 1) & sequenceMask;
            
            // Nếu số thứ tự vượt quá giới hạn (4096), chờ sang mili-giây tiếp theo
            if (sequence == 0) {
                timestamp = tilNextMillis(lastTimestamp);
            }
        } else {
            // Nếu sang mili-giây mới -> Reset số thứ tự về 0
            sequence = 0L;
        }

        lastTimestamp = timestamp;

        // Phép toán Bitwise để ghép các phần lại thành 1 số Long duy nhất
        return ((timestamp - epoch) << timestampLeftShift) |
               (machineId << machineIdShift) |
               sequence;
    }

    // Hàm chờ cho đến khi sang mili-giây tiếp theo
    private long tilNextMillis(long lastTimestamp) {
        long timestamp = System.currentTimeMillis();
        while (timestamp <= lastTimestamp) {
            timestamp = System.currentTimeMillis();
        }
        return timestamp;
    }
}