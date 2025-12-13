package com.officesync.core.config;

import java.time.LocalDate;
import java.util.List;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.officesync.core.model.Company;
import com.officesync.core.model.User;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.UserRepository;

@Configuration
public class DatabaseSeeder {

    @Bean
    CommandLineRunner initDatabase(UserRepository userRepository, 
                                   CompanyRepository companyRepository, 
                                   PasswordEncoder passwordEncoder) {
        return args -> {
            // 1. TẠO CÔNG TY "FPT Software" NẾU CHƯA CÓ
            Company fptCompany = null;
            // Tìm xem công ty đã có chưa (dựa theo domain hoặc tên)
            // Ở đây mình tìm trong list, nếu project lớn nên viết hàm findByDomain trong Repository
            List<Company> companies = companyRepository.findAll();
            for (Company c : companies) {
                if ("fpt".equals(c.getDomain())) {
                    fptCompany = c;
                    break;
                }
            }

            if (fptCompany == null) {
                fptCompany = new Company();
                fptCompany.setName("FPT Software");
                fptCompany.setDomain("fpt");
                fptCompany.setStatus("ACTIVE");
                fptCompany = companyRepository.save(fptCompany);
                System.out.println("--> Đã tạo công ty: FPT Software");
            }

            // 2. TẠO CÁC USER (Mật khẩu '123456' sẽ được mã hóa BCrypt)
            createUserIfNotFound(userRepository, passwordEncoder, 
                "admin@system.com", "Super Admin", "SUPER_ADMIN", null);

            createUserIfNotFound(userRepository, passwordEncoder, 
                "boss@fpt.com", "FPT Boss", "COMPANY_ADMIN", fptCompany);

            createUserIfNotFound(userRepository, passwordEncoder, 
                "manager@abc.com", "Nguyen Van B", "MANAGER", fptCompany);

            createUserIfNotFound(userRepository, passwordEncoder, 
                "staff@abc.com", "Nguyen Van A", "STAFF", fptCompany);
        };
    }

    private void createUserIfNotFound(UserRepository userRepository, 
                                      PasswordEncoder passwordEncoder,
                                      String email, String fullName, String role, Company company) {
        if (userRepository.findByEmail(email).isEmpty()) {
            User user = new User();
            user.setEmail(email);
            user.setFullName(fullName);
            // Mã hóa mật khẩu "123456" bằng BCrypt để đăng nhập được
            user.setPassword(passwordEncoder.encode("123456")); 
            user.setRole(role);
            
            if (company != null) {
                user.setCompanyId(company.getId());
            }
            
            // Set thêm dữ liệu giả cho mobile/dob để không bị null
            user.setMobileNumber("0900000000");
            user.setDateOfBirth(LocalDate.of(1990, 1, 1));

            userRepository.save(user);
            System.out.println("--> Đã tạo User: " + email + " (Pass: 123456)");
        }
    }
}