package com.officesync.core.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Random;
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
    
    // Inject Repository quản lý lịch sử mật khẩu
    @Autowired private PasswordHistoryRepository passwordHistoryRepository;

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

        // Check Company Status
        if (user.getCompanyId() != null) {
            Company company = companyRepository.findById(user.getCompanyId()).orElse(null);
            if (company != null && "LOCKED".equals(company.getStatus())) {
                throw new RuntimeException("Your company account has been locked.");
            }
        }

        // Check User Status
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
        // Logic tự sinh domain
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

        userRepository.save(user); // User có ID tại đây
        
        // 🔴 QUAN TRỌNG: Lưu mật khẩu khởi tạo vào lịch sử luôn
        // Để tránh việc vừa tạo xong đổi pass quay lại pass cũ
        savePasswordHistory(user);

        registrationOtpCache.remove(req.getEmail());
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

        // Kiểm tra lịch sử & trùng lặp
        validateNewPassword(user, newPassword);

        // Lưu mật khẩu cũ vào lịch sử
        savePasswordHistory(user);

        // Cập nhật mật khẩu mới
        user.setPassword(passwordEncoder.encode(newPassword));
        user.setOtpCode(null);
        user.setOtpExpiry(null);
        userRepository.save(user);
    }

    // 🔴 MỚI THÊM: CHANGE PASSWORD (Đổi chủ động khi đã đăng nhập)
    public void changePassword(Long userId, String currentPassword, String newPassword) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 1. Kiểm tra mật khẩu cũ nhập vào có đúng không
        if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
            throw new RuntimeException("Current password is incorrect!");
        }

        // 2. Kiểm tra lịch sử & trùng lặp (Dùng chung logic với reset)
        validateNewPassword(user, newPassword);

        // 3. Lưu lịch sử
        savePasswordHistory(user);

        // 4. Cập nhật
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    // --- HELPER FUNCTIONS ---
    
    // Hàm validate tách riêng để dùng chung cho cả Reset và Change password
    private void validateNewPassword(User user, String newPassword) {
        // 1. Kiểm tra có trùng mật khẩu HIỆN TẠI không
        if (passwordEncoder.matches(newPassword, user.getPassword())) {
            throw new RuntimeException("New password cannot be the same as your current password!");
        }

        // 2. Kiểm tra có trùng 2 mật khẩu GẦN NHẤT không
        List<PasswordHistory> historyList = passwordHistoryRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        int checkLimit = Math.min(historyList.size(), 2);
        
        for (int i = 0; i < checkLimit; i++) {
            if (passwordEncoder.matches(newPassword, historyList.get(i).getPasswordHash())) {
                throw new RuntimeException("Password has been used recently. Please choose a different one.");
            }
        }
    }

    // Hàm lưu lịch sử
    private void savePasswordHistory(User user) {
        PasswordHistory history = new PasswordHistory(user, user.getPassword());
        passwordHistoryRepository.save(history);

        // Dọn dẹp: Chỉ giữ lại 2 cái cũ nhất + cái vừa thêm = 3 bản ghi
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