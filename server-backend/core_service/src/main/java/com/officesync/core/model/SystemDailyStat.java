package com.officesync.core.model;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "system_daily_stats")
@Data
@NoArgsConstructor
public class SystemDailyStat {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private LocalDate date; // Ngày ghi nhận

    @Column(name = "total_users")
    private Long totalUsers; // Tổng user tại ngày đó

    @Column(name = "total_companies")
    private Long totalCompanies;

    public SystemDailyStat(LocalDate date, Long totalUsers, Long totalCompanies) {
        this.date = date;
        this.totalUsers = totalUsers;
        this.totalCompanies = totalCompanies;
    }
}