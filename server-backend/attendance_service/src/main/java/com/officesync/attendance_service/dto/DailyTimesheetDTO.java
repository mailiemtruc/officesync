package com.officesync.attendance_service.dto;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DailyTimesheetDTO {
    private LocalDate date;             // Ngày làm việc
    private double totalWorkingHours;   // Tổng giờ làm (VD: 8.5)
    private String status;              // "OK", "MISSING_CHECKOUT", "ABSENT"
    private List<Session> sessions;     // Chi tiết các ca (Sáng, Chiều, Tối...)

    @Data
    @AllArgsConstructor
    public static class Session {
        private LocalTime checkIn;
        private LocalTime checkOut;
        private double duration; // Giờ làm của session này
    }
}