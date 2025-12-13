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

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CompanyRepository companyRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider tokenProvider;

    @Autowired
    private JavaMailSender mailSender;

    // Bộ nhớ tạm để lưu OTP đăng ký (Email -> OTP)
    private final Map<String, String> registrationOtpCache = new ConcurrentHashMap<>();

    // --- API LOGIN ---
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail()).orElse(null);
        if (user == null) {
            return ResponseEntity.badRequest().body("The email address doesn't exist!");
        }
        if (!passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            return ResponseEntity.badRequest().body("Incorrect password!");
        }
        String token = tokenProvider.generateToken(user);
        return ResponseEntity.ok(new AuthResponse(token, user));
    }

    // --- 1. API GỬI OTP ĐĂNG KÝ (MỚI) ---
    // Kiểm tra email chưa tồn tại -> Gửi OTP để xác minh chính chủ
    @PostMapping("/send-register-otp")
    public ResponseEntity<?> sendRegisterOtp(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String mobileNumber = req.get("mobile"); // <--- 1. Lấy số điện thoại từ Client gửi lên

        // 2. Kiểm tra Email
        if (userRepository.findByEmail(email).isPresent()) {
            return ResponseEntity.badRequest().body("Email already exists! Please login.");
        }

        // 3. 🔴 Kiểm tra Số điện thoại (MỚI) 🔴
        if (mobileNumber != null && userRepository.findByMobileNumber(mobileNumber).isPresent()) {
             return ResponseEntity.badRequest().body("Mobile number already in use!");
        }

        // 4. Tạo OTP & Gửi mail (Giữ nguyên)
        String otp = String.format("%04d", new Random().nextInt(10000));
        registrationOtpCache.put(email, otp);

        try {
            sendEmail(email, "Verify Email - OfficeSync", 
                "Your registration verification code is: " + otp + "\nThis code ensures your email is valid.");
            return ResponseEntity.ok("OTP sent to email!");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Failed to send email: " + e.getMessage());
        }
    }

    // --- 2. API ĐĂNG KÝ (ĐÃ SỬA: CHECK OTP) ---
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest req) {
        // A. Kiểm tra OTP trước tiên
        String cachedOtp = registrationOtpCache.get(req.getEmail());
        
        if (cachedOtp == null) {
            return ResponseEntity.badRequest().body("Please verify your email first (Request OTP)!");
        }
        
        if (req.getOtp() == null || !cachedOtp.equals(req.getOtp())) {
            return ResponseEntity.badRequest().body("Invalid verification code!");
        }

        // B. Các kiểm tra cũ
        if (userRepository.findByEmail(req.getEmail()).isPresent()) {
            return ResponseEntity.badRequest().body("Email already exists!");
        }
        if (req.getPassword() == null || req.getPassword().isEmpty()) {
             return ResponseEntity.badRequest().body("Password cannot be empty!");
        }

        try {
            // Tạo Company
            Company company = new Company();
            company.setName(req.getCompanyName());
            String domainSlug = req.getCompanyName().toLowerCase().replaceAll("\\s+", "") 
                                + new Random().nextInt(10000);
            company.setDomain(domainSlug);
            Company savedCompany = companyRepository.save(company);

            // Tạo User
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

            // C. Xóa OTP khỏi bộ nhớ tạm sau khi thành công
            registrationOtpCache.remove(req.getEmail());

            return ResponseEntity.ok("Company created successfully!");

        } catch (Exception e) {
            e.printStackTrace(); 
            return ResponseEntity.internalServerError().body("Registration failed due to a server error.");
        }
    }

    // --- API FORGOT PASSWORD (ĐÃ CÓ LOGIC 60S) ---
    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        User user = userRepository.findByEmail(email).orElse(null);
        
        if (user == null) {
            return ResponseEntity.badRequest().body("Email does not exist!");
        }

        String otp = String.format("%04d", new Random().nextInt(10000));
        user.setOtpCode(otp);
        user.setOtpExpiry(LocalDateTime.now().plusSeconds(60)); // 60 giây
        userRepository.save(user);

        try {
            sendEmail(email, "Reset Password OTP - OfficeSync", 
                "Your OTP code is: " + otp + "\n\nThis code expires in 60 seconds.");
            return ResponseEntity.ok("OTP sent to your email!");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Error sending email: " + e.getMessage());
        }
    }

    // --- HELPER GỬI MAIL ---
    private void sendEmail(String to, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(to);
        message.setSubject(subject);
        message.setText(body);
        message.setFrom("OfficeSync Security <mailientruc05@gmail.com>");
        mailSender.send(message);
    }

    // --- API VERIFY OTP (FORGOT PASS) ---
    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String otp = req.get("otp");
        User user = userRepository.findByEmail(email).orElse(null);

        if (user == null) return ResponseEntity.badRequest().body("User not found!");
        if (user.getOtpCode() == null || !user.getOtpCode().equals(otp)) {
            return ResponseEntity.badRequest().body("Invalid OTP!");
        }
        if (user.getOtpExpiry().isBefore(LocalDateTime.now())) {
            return ResponseEntity.badRequest().body("OTP has expired!");
        }
        return ResponseEntity.ok("OTP Verified!");
    }

    // --- API RESET PASSWORD ---
    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, String> req) {
        String email = req.get("email");
        String newPassword = req.get("password");
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) return ResponseEntity.badRequest().body("User not found!");

        user.setPassword(passwordEncoder.encode(newPassword));
        user.setOtpCode(null);
        user.setOtpExpiry(null);
        userRepository.save(user);

        return ResponseEntity.ok("Password reset successfully!");
    }

    // --- DTO CLASSES ---
    @Data static class LoginRequest {
        private String email;
        private String password;
    }

    @Data static class RegisterRequest {
        private String companyName;
        private String fullName;
        private String email;
        private String mobileNumber; 
        private String dateOfBirth;
        private String password;
        private String otp; // 🔴 QUAN TRỌNG: Thêm trường này để nhận OTP từ App
    }

    @Data
    @AllArgsConstructor
    static class AuthResponse {
        private String token;
        private User user;
    }
}