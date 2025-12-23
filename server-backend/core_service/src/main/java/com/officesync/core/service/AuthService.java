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

        // 🔴 GỬI SỰ KIỆN SANG RABBITMQ (ĐỂ PROFILE SERVICE XỬ LÝ)
        try {
            UserCreatedEvent event = new UserCreatedEvent();
            
            event.setId(savedUser.getId());              // ID 5
            event.setCompanyId(savedUser.getCompanyId()); // Company ID
            event.setEmail(savedUser.getEmail());         // mailiemtruc04@gmail.com
            event.setFullName(savedUser.getFullName());   // Mai Van L
            event.setMobileNumber(savedUser.getMobileNumber()); // 0934828105
            event.setDateOfBirth(savedUser.getDateOfBirth());   // 2000-01-01
            event.setRole(savedUser.getRole());           // COMPANY_ADMIN
            event.setStatus(savedUser.getStatus());       // ACTIVE

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
    // XỬ LÝ ĐỒNG BỘ TỪ HR -> CORE
    // =========================================================
    @Transactional
    public void createEmployeeAccount(EmployeeSyncEvent event) {
        // 1. Kiểm tra User tồn tại chưa
        if (userRepository.findByEmail(event.getEmail()).isPresent()) {
            System.out.println("User đã tồn tại: " + event.getEmail());
            return;
        }

        // 2. Map dữ liệu từ Event sang User Entity
        User newUser = new User();
        newUser.setCompanyId(event.getCompanyId());
        newUser.setEmail(event.getEmail());
        newUser.setFullName(event.getFullName());
        newUser.setMobileNumber(event.getPhone());
        newUser.setDateOfBirth(event.getDateOfBirth());
        
        // 3. Xử lý Mật khẩu (Hash)
        // Mật khẩu từ HR gửi sang là bản rõ (raw), cần mã hóa ngay
        newUser.setPassword(passwordEncoder.encode(event.getPassword()));

        // 4. Map Role & Status
        // Lưu ý: Cần đảm bảo string Role khớp với Enum hoặc Logic của bạn
        newUser.setRole(event.getRole()); 
        newUser.setStatus(event.getStatus()); 

        // 5. Lưu vào DB Core
        User savedUser = userRepository.save(newUser);
        
        // Lưu lịch sử mật khẩu
        savePasswordHistory(savedUser);

        System.out.println("--> Đã tạo User từ HR: " + savedUser.getEmail() + " (ID: " + savedUser.getId() + ")");

        // 6. BẮN EVENT NGƯỢC LẠI (Broadcast cho các service khác biết)
        // Profile Service hoặc Notification Service có thể cần thông tin này
        try {
            UserCreatedEvent responseEvent = new UserCreatedEvent();
            
            responseEvent.setId(savedUser.getId());              // ID mới sinh
            responseEvent.setCompanyId(savedUser.getCompanyId());
            responseEvent.setEmail(savedUser.getEmail());
            responseEvent.setFullName(savedUser.getFullName());
            responseEvent.setMobileNumber(savedUser.getMobileNumber());
            responseEvent.setDateOfBirth(savedUser.getDateOfBirth());
            responseEvent.setRole(savedUser.getRole());
            responseEvent.setStatus(savedUser.getStatus());
            
            // Hàm này bạn đã có ở bài trước
            rabbitMQProducer.sendUserCreatedEvent(responseEvent);
            
        } catch (Exception e) {
            System.err.println("Lỗi bắn event UserCreated: " + e.getMessage());
        }
    }

    public void updateEmployeeAccount(EmployeeSyncEvent event) {
        // 1. Tìm user
        User user = userRepository.findByEmail(event.getEmail())
                .orElseThrow(() -> new RuntimeException("User not found: " + event.getEmail()));

        // 2. Cập nhật thông tin cơ bản
        user.setFullName(event.getFullName());
        user.setMobileNumber(event.getPhone());
        user.setDateOfBirth(event.getDateOfBirth());

        // 3. LOGIC CẬP NHẬT QUYỀN (ROLE) [MỚI]
        // Kiểm tra: Nếu Role gửi sang KHÁC NULL và KHÁC với Role hiện tại thì mới cập nhật
        if (event.getRole() != null && !event.getRole().equals(user.getRole())) {
            System.out.println("--> [Core] Phát hiện thay đổi quyền: " + user.getRole() + " -> " + event.getRole());
            user.setRole(event.getRole());
        }

        // 4. LOGIC CẬP NHẬT TRẠNG THÁI (STATUS) (Tương tự Role)
        if (event.getStatus() != null && !event.getStatus().equals(user.getStatus())) {
            System.out.println("--> [Core] Phát hiện thay đổi trạng thái: " + user.getStatus() + " -> " + event.getStatus());
            user.setStatus(event.getStatus());
        }

        // 5. Cập nhật mật khẩu (chỉ khi có password mới)
        if (event.getPassword() != null && !event.getPassword().isEmpty()) {
            user.setPassword(passwordEncoder.encode(event.getPassword()));
        }

        // 6. Lưu thay đổi
        userRepository.save(user);
        System.out.println("--> [Core] Đã đồng bộ xong User: " + user.getEmail());
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