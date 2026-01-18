package com.officesync.core.service;

import java.time.LocalDate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.officesync.core.model.SystemDailyStat;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.SystemDailyStatRepository;
import com.officesync.core.repository.UserRepository;

@Component
public class StatScheduler {

    @Autowired private UserRepository userRepository;
    @Autowired private CompanyRepository companyRepository;
    @Autowired private SystemDailyStatRepository statRepository;

    // Chạy lúc 23:59:00 mỗi ngày
    @Scheduled(cron = "0 59 23 * * ?")
    public void recordDailyStats() {
        long users = userRepository.count();
        long companies = companyRepository.count();
        
        SystemDailyStat stat = new SystemDailyStat(LocalDate.now(), users, companies);
        statRepository.save(stat);
        
        System.out.println("--> [Scheduler] Đã lưu thống kê ngày: " + LocalDate.now());
    }
}