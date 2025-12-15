package com.officesync.core.controller;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.model.Company;
import com.officesync.core.model.User;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.UserRepository;
import com.officesync.core.security.JwtTokenProvider;

import lombok.AllArgsConstructor;
import lombok.Data;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired private UserRepository userRepository;
    @Autowired private CompanyRepository companyRepository;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private JwtTokenProvider tokenProvider;
    @Autowired private JavaMailSender mailSender;

    // --- CLASS LƯU TRỮ OTP (Kèm thời gian hết hạn) ---
    @Data
    @AllArgsConstructor
    static class OtpData {
        String code;
        long expiryTime; // Thời điểm hết hạn (milliseconds)
    }

    // Map lưu OTP đăng ký: Email -> OtpData
    private final Map<String, OtpData> registrationOtpCache = new ConcurrentHashMap<>();

    // --- API LOGIN ---
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        // 1. Tìm User
        User user = userRepository.findByEmail(req.getEmail()).orElse(null);
        
        // 2. Check Password
        if (user == null || !passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            return ResponseEntity.badRequest().body("Incorrect email or password!");
        }

        // Logic: Nếu user thuộc công ty (có companyId) VÀ công ty đó đang bị LOCKED -> Chặn luôn
        if (user.getCompanyId() != null) {
            Company company = companyRepository.findById(user.getCompanyId()).orElse(null);
            
            if (company != null && "LOCKED".equals(company.getStatus())) {
                // Trả về lỗi 403 Forbidden
                return ResponseEntity.status(403) 
                    .body("Your company account has been locked. Please contact support.");
            }
        }

        // Nếu chính tài khoản này bị khóa
        if ("LOCKED".equals(user.getStatus())) {
            return ResponseEntity.status(403)
                .body("Your account has been locked by Administrator.");
        }

        // 4. Nếu mọi thứ OK -> Tạo Token
        String token = tokenProvider.generateToken(user);
        return ResponseEntity.ok(new AuthResponse(token, user));
    }

    // --- 1. API GỬI OTP ĐĂNG KÝ ---
    @PostMapping("/send-register-otp")
    public ResponseEntity<?> sendRegisterOtp(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String mobileNumber = req.get("mobile");

        // Validate
        if (userRepository.findByEmail(email).isPresent()) {
            return ResponseEntity.badRequest().body("Email already exists! Please login.");
        }
        if (mobileNumber != null && userRepository.findByMobileNumber(mobileNumber).isPresent()) {
             return ResponseEntity.badRequest().body("Mobile number already in use!");
        }

        // Tạo OTP
        String otp = String.format("%04d", new Random().nextInt(10000));
        
        // Lưu vào Cache (Hết hạn sau 5 phút = 300,000 ms)
        registrationOtpCache.put(email, new OtpData(otp, System.currentTimeMillis() + 300000));

        try {
            sendEmail(email, "Verify Email - OfficeSync", 
                "Your registration code is: " + otp + "\nValid for 5 minutes.");
            return ResponseEntity.ok("OTP sent to email!");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to send email.");
        }
    }

    // --- 2. API CHECK OTP ĐĂNG KÝ (MỚI THÊM CHO APP) ---
    // Frontend gọi cái này ở Dialog trước khi cho User qua màn hình Set Password
    @PostMapping("/verify-register-otp")
    public ResponseEntity<?> verifyRegisterOtp(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String otp = req.get("otp");

        OtpData cachedData = registrationOtpCache.get(email);
        
        if (cachedData == null) {
            return ResponseEntity.badRequest().body("OTP request not found. Please resend.");
        }
        
        if (System.currentTimeMillis() > cachedData.getExpiryTime()) {
             return ResponseEntity.badRequest().body("OTP has expired.");
        }

        // So sánh chuỗi (có trim() để xóa khoảng trắng thừa)
        if (otp == null || !cachedData.getCode().equals(otp.trim())) {
            return ResponseEntity.badRequest().body("Invalid verification code!");
        }

        return ResponseEntity.ok("OTP is valid!");
    }

    // --- 3. API ĐĂNG KÝ (FINAL STEP) ---
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest req) {
        // A. Kiểm tra OTP Lần Cuối (Double Check)
        OtpData cachedData = registrationOtpCache.get(req.getEmail());
        
        if (cachedData == null || System.currentTimeMillis() > cachedData.getExpiryTime()) {
            return ResponseEntity.badRequest().body("OTP expired or invalid. Please start over.");
        }
        
        if (req.getOtp() == null || !cachedData.getCode().equals(req.getOtp().trim())) {
            return ResponseEntity.badRequest().body("Invalid verification code!");
        }

        // B. Logic tạo User (Giữ nguyên)
        if (userRepository.findByEmail(req.getEmail()).isPresent()) {
            return ResponseEntity.badRequest().body("Email already exists!");
        }

        try {
            Company company = new Company();
            company.setName(req.getCompanyName());
            String domainSlug = req.getCompanyName().toLowerCase().replaceAll("[^a-z0-9]", "") 
                                + new Random().nextInt(10000);
            company.setDomain(domainSlug);
            Company savedCompany = companyRepository.save(company);

            User user = new User();
            user.setEmail(req.getEmail());
            user.setFullName(req.getFullName());
            user.setPassword(passwordEncoder.encode(req.getPassword()));
            user.setRole("COMPANY_ADMIN"); 
            user.setCompanyId(savedCompany.getId()); 
            user.setMobileNumber(req.getMobileNumber());

            if (req.getDateOfBirth() != null && !req.getDateOfBirth().isEmpty()) {
                DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");
                user.setDateOfBirth(LocalDate.parse(req.getDateOfBirth(), formatter));
            }
            
            userRepository.save(user);

            // Xóa OTP sau khi thành công
            registrationOtpCache.remove(req.getEmail());

            return ResponseEntity.ok("Company created successfully!");

        } catch (Exception e) {
            e.printStackTrace(); 
            return ResponseEntity.internalServerError().body("Registration failed: " + e.getMessage());
        }
    }

    // --- 4. API FORGOT PASSWORD ---
    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) return ResponseEntity.badRequest().body("Email does not exist!");

        String otp = String.format("%04d", new Random().nextInt(10000));
        user.setOtpCode(otp);
        user.setOtpExpiry(LocalDateTime.now().plusSeconds(60)); // 60 giây
        userRepository.save(user);

        sendEmail(email, "Reset Password OTP", "Your OTP: " + otp + "\nExpires in 60s.");
        return ResponseEntity.ok("OTP sent!");
    }

    // --- 5. API VERIFY OTP (FORGOT PASS UI) ---
    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String otp = req.get("otp");
        User user = userRepository.findByEmail(email).orElse(null);

        if (user == null) return ResponseEntity.badRequest().body("User not found!");
        
        if (user.getOtpCode() == null || !user.getOtpCode().equals(otp.trim())) {
            return ResponseEntity.badRequest().body("Invalid OTP!");
        }
        if (user.getOtpExpiry().isBefore(LocalDateTime.now())) {
            return ResponseEntity.badRequest().body("OTP has expired!");
        }
        return ResponseEntity.ok("OTP Verified!");
    }

    // --- 6. API RESET PASSWORD (ĐÃ SỬA BẢO MẬT) ---
    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String otp = req.get("otp"); // 🔴 BẮT BUỘC PHẢI CÓ
        String newPassword = req.get("password");

        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) return ResponseEntity.badRequest().body("User not found!");

        // 🔴 KIỂM TRA LẠI OTP TRƯỚC KHI ĐỔI PASS
        if (user.getOtpCode() == null || !user.getOtpCode().equals(otp.trim())) {
            return ResponseEntity.badRequest().body("Invalid OTP! Cannot reset password.");
        }
        if (user.getOtpExpiry().isBefore(LocalDateTime.now())) {
            return ResponseEntity.badRequest().body("OTP has expired!");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        user.setOtpCode(null); // Xóa OTP sau khi dùng
        user.setOtpExpiry(null);
        userRepository.save(user);

        return ResponseEntity.ok("Password reset successfully!");
    }

    // Helper Send Mail
    private void sendEmail(String to, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(to);
        message.setSubject(subject);
        message.setText(body);
        message.setFrom("OfficeSync Security <mailientruc05@gmail.com>");
        mailSender.send(message);
    }

    // DTOs
    @Data static class LoginRequest { private String email; private String password; }
    @Data static class RegisterRequest {
        private String companyName; private String fullName; private String email;
        private String mobileNumber; private String dateOfBirth; private String password;
        private String otp; 
    }
    @Data @AllArgsConstructor static class AuthResponse { private String token; private User user; }
}