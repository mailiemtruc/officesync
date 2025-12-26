package com.officesync.core.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Random; // [QUAN TRỌNG] Đã thêm dòng này để sửa lỗi
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.core.controller.AuthController.AuthResponse;
import com.officesync.core.controller.AuthController.LoginRequest;
import com.officesync.core.controller.AuthController.RegisterRequest;
import com.officesync.core.dto.EmployeeSyncEvent;
import com.officesync.core.dto.UserCreatedEvent;
import com.officesync.core.model.Company;
import com.officesync.core.model.PasswordHistory;
import com.officesync.core.model.User;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.PasswordHistoryRepository;
import com.officesync.core.repository.UserRepository;
import com.officesync.core.security.JwtTokenProvider;

import lombok.AllArgsConstructor;
import lombok.Data;

@Service
public class AuthService {

    @Autowired private UserRepository userRepository;
    @Autowired private CompanyRepository companyRepository;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private JwtTokenProvider tokenProvider;
    @Autowired private JavaMailSender mailSender;
    
    @Autowired private PasswordHistoryRepository passwordHistoryRepository;
    
    // 🔴 INJECT RABBITMQ PRODUCER
    @Autowired private RabbitMQProducer rabbitMQProducer;

    // Cache OTP
    @Data @AllArgsConstructor
    static class OtpData {
        String code;
        long expiryTime;
    }
    private final Map<String, OtpData> registrationOtpCache = new ConcurrentHashMap<>();

    // --- LOGIN ---
    public AuthResponse login(LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail()).orElse(null);
        if (user == null || !passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect email or password!");
        }

        if (user.getCompanyId() != null) {
            Company company = companyRepository.findById(user.getCompanyId()).orElse(null);
            if (company != null && "LOCKED".equals(company.getStatus())) {
                throw new RuntimeException("Your company account has been locked.");
            }
        }

        if ("LOCKED".equals(user.getStatus())) {
            throw new RuntimeException("Your account has been locked by Administrator.");
        }

        String token = tokenProvider.generateToken(user);
        return new AuthResponse(token, user);
    }

    // --- OTP LOGIC ---
    public void sendRegisterOtp(String email, String mobileNumber) {
        if (userRepository.findByEmail(email).isPresent()) {
            throw new RuntimeException("Email already exists!");
        }
        if (mobileNumber != null && userRepository.findByMobileNumber(mobileNumber).isPresent()) {
            throw new RuntimeException("Mobile number already in use!");
        }

        String otp = String.format("%04d", new Random().nextInt(10000));
        
        registrationOtpCache.put(email, new OtpData(otp, System.currentTimeMillis() + 300000));
        sendEmail(email, "Verify Email - OfficeSync", "Your registration code is: " + otp + "\nValid for 5 minutes.");
    }

    public void verifyRegisterOtp(String email, String otp) {
        OtpData cachedData = registrationOtpCache.get(email);
        if (cachedData == null) throw new RuntimeException("OTP request not found.");
        if (System.currentTimeMillis() > cachedData.getExpiryTime()) throw new RuntimeException("OTP has expired.");
        if (otp == null || !cachedData.getCode().equals(otp.trim())) throw new RuntimeException("Invalid verification code!");
    }

    // --- REGISTER ---
    @Transactional
    public void register(RegisterRequest req) {
        // Verify OTP again
        verifyRegisterOtp(req.getEmail(), req.getOtp());

        if (userRepository.findByEmail(req.getEmail()).isPresent()) {
            throw new RuntimeException("Email already exists!");
        }

        // Tạo Company
        Company company = new Company();
        company.setName(req.getCompanyName());
        String domainSlug = req.getCompanyName().toLowerCase().replaceAll("[^a-z0-9]", "")
                + String.format("%04d", new Random().nextInt(10000));
        company.setDomain(domainSlug);
        company.setStatus("ACTIVE");
        Company savedCompany = companyRepository.save(company);

        // Tạo User Admin
        User user = new User();
        user.setEmail(req.getEmail());
        user.setFullName(req.getFullName());
        user.setPassword(passwordEncoder.encode(req.getPassword()));
        user.setRole("COMPANY_ADMIN");
        user.setCompanyId(savedCompany.getId());
        user.setMobileNumber(req.getMobileNumber());
        user.setStatus("ACTIVE");

        if (req.getDateOfBirth() != null && !req.getDateOfBirth().isEmpty()) {
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");
            user.setDateOfBirth(LocalDate.parse(req.getDateOfBirth(), formatter));
        }

        User savedUser = userRepository.save(user); // Lưu ý: Lấy user đã save để chắc chắn có ID
        
        savePasswordHistory(user);
        registrationOtpCache.remove(req.getEmail());

        // 🔴 GỬI SỰ KIỆN SANG RABBITMQ (ĐỂ WALLET/PROFILE SERVICE XỬ LÝ)
        try {
            UserCreatedEvent event = new UserCreatedEvent();
            
            event.setId(savedUser.getId());              
            event.setCompanyId(savedUser.getCompanyId()); 
            event.setEmail(savedUser.getEmail());        
            event.setFullName(savedUser.getFullName());   
            event.setMobileNumber(savedUser.getMobileNumber()); 
            event.setDateOfBirth(savedUser.getDateOfBirth());   
            event.setRole(savedUser.getRole());           
            event.setStatus(savedUser.getStatus());       

            // Gửi đi
            rabbitMQProducer.sendUserCreatedEvent(event);
            
        } catch (Exception e) {
            System.err.println("--> Lỗi gửi RabbitMQ: " + e.getMessage());
        }
    }

    // --- FORGOT PASSWORD ---
    public void forgotPassword(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Email does not exist!"));
        String otp = String.format("%04d", new Random().nextInt(10000));
        user.setOtpCode(otp);
        user.setOtpExpiry(LocalDateTime.now().plusMinutes(5));  
        userRepository.save(user);
        sendEmail(email, "Reset Password OTP", "Your OTP: " + otp + "\nExpires in 5 minutes.");
    }

    public void verifyForgotPasswordOtp(String email, String otp) {
        User user = userRepository.findByEmail(email).orElseThrow(() -> new RuntimeException("User not found!"));
        if (user.getOtpCode() == null || !user.getOtpCode().equals(otp.trim())) throw new RuntimeException("Invalid OTP!");
        if (user.getOtpExpiry().isBefore(LocalDateTime.now())) throw new RuntimeException("OTP has expired!");
    }

    public void resetPassword(String email, String otp, String newPassword) {
        verifyForgotPasswordOtp(email, otp);
        User user = userRepository.findByEmail(email).get();
        validateNewPassword(user, newPassword);
        savePasswordHistory(user);
        user.setPassword(passwordEncoder.encode(newPassword));
        user.setOtpCode(null);
        user.setOtpExpiry(null);
        userRepository.save(user);
    }

    // --- CHANGE PASSWORD ---
    public void changePassword(Long userId, String currentPassword, String newPassword) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
            throw new RuntimeException("Current password is incorrect!");
        }
        validateNewPassword(user, newPassword);
        savePasswordHistory(user);
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    // =========================================================
    // [MỚI] HÀM SYNC DUY NHẤT (UPSERT: Create or Update)
    // =========================================================
    @Transactional
    public void syncEmployeeAccount(EmployeeSyncEvent event) {
        User user = null;

        // ƯU TIÊN 1: Tìm theo ID (Chính xác 100% vì đã đồng bộ)
        if (event.getId() != null) {
            System.out.println("--> [Sync] Tìm User theo ID: " + event.getId());
            user = userRepository.findById(event.getId()).orElse(null);
        }

        // ƯU TIÊN 2: Nếu không có ID hoặc tìm không thấy, mới tìm theo Email (Fallback)
        if (user == null) {
            System.out.println("--> [Sync] Không có ID, tìm theo Email: " + event.getEmail());
            user = userRepository.findByEmail(event.getEmail()).orElse(null);
        }

        // --- XỬ LÝ UPSERT ---
        if (user != null) {
            // === UPDATE ===
            // Vì đã tìm được đúng người (qua ID), ta cứ thế set Email mới
            if (!user.getEmail().equals(event.getEmail())) {
                System.out.println("--> [Sync] Phát hiện đổi Email: " + user.getEmail() + " -> " + event.getEmail());
                user.setEmail(event.getEmail());
            }

            // Cập nhật các thông tin khác
            user.setFullName(event.getFullName());
            user.setMobileNumber(event.getPhone());
            user.setDateOfBirth(event.getDateOfBirth());
            
            if (event.getRole() != null) user.setRole(event.getRole());
            if (event.getStatus() != null) user.setStatus(event.getStatus());
            
            if (event.getPassword() != null && !event.getPassword().isEmpty()) {
                user.setPassword(passwordEncoder.encode(event.getPassword()));
            }

            userRepository.save(user);

        } else {
            // --- CREATE (Như cũ) ---
            System.out.println("--> [Sync] Không tìm thấy User cũ/mới, tạo mới: " + event.getEmail());
            
            User newUser = new User();
            newUser.setCompanyId(event.getCompanyId());
            newUser.setEmail(event.getEmail()); // Luôn set email mới nhất
            newUser.setFullName(event.getFullName());
            newUser.setMobileNumber(event.getPhone());
            newUser.setDateOfBirth(event.getDateOfBirth());
            
            String rawPass = (event.getPassword() != null) ? event.getPassword() : "123456";
            newUser.setPassword(passwordEncoder.encode(rawPass));
            
            newUser.setRole(event.getRole());
            newUser.setStatus(event.getStatus());

            User savedUser = userRepository.save(newUser);
            savePasswordHistory(savedUser);

            // 🔴 BẮN EVENT CHO CÁC SERVICE KHÁC (Wallet, etc.)
            try {
                UserCreatedEvent responseEvent = new UserCreatedEvent();
                responseEvent.setId(savedUser.getId());
                responseEvent.setCompanyId(savedUser.getCompanyId());
                responseEvent.setEmail(savedUser.getEmail());
                responseEvent.setFullName(savedUser.getFullName());
                responseEvent.setMobileNumber(savedUser.getMobileNumber());
                responseEvent.setDateOfBirth(savedUser.getDateOfBirth());
                responseEvent.setRole(savedUser.getRole());
                responseEvent.setStatus(savedUser.getStatus());
                
                rabbitMQProducer.sendUserCreatedEvent(responseEvent);
                System.out.println("    -> Đã bắn UserCreatedEvent cho Wallet Service");
            } catch (Exception e) {
                System.err.println("Lỗi bắn event UserCreated: " + e.getMessage());
            }
        }
    }

    // --- HELPER FUNCTIONS ---
    private void validateNewPassword(User user, String newPassword) {
        if (passwordEncoder.matches(newPassword, user.getPassword())) {
            throw new RuntimeException("New password cannot be the same as your current password!");
        }
        List<PasswordHistory> historyList = passwordHistoryRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        int checkLimit = Math.min(historyList.size(), 2);
        for (int i = 0; i < checkLimit; i++) {
            if (passwordEncoder.matches(newPassword, historyList.get(i).getPasswordHash())) {
                throw new RuntimeException("Password has been used recently. Please choose a different one.");
            }
        }
    }

    private void savePasswordHistory(User user) {
        PasswordHistory history = new PasswordHistory(user, user.getPassword());
        passwordHistoryRepository.save(history);
        List<PasswordHistory> allHistory = passwordHistoryRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        if (allHistory.size() > 2) {
            passwordHistoryRepository.deleteAll(allHistory.subList(2, allHistory.size()));
        }
    }

    private void sendEmail(String to, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(to);
        message.setSubject(subject);
        message.setText(body);
        message.setFrom("OfficeSync Security <mailientruc05@gmail.com>");
        mailSender.send(message);
    }
}