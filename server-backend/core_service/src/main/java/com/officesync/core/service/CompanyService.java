package com.officesync.core.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.model.Company;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.UserRepository;

@Service
public class CompanyService {

    @Autowired private CompanyRepository companyRepository;
    @Autowired private UserRepository userRepository;

    // --- Cho Admin ---
    public Map<String, Long> getSystemStats() {
        Map<String, Long> stats = new HashMap<>();
        stats.put("companies", companyRepository.count());
        stats.put("users", userRepository.count());
        return stats;
    }

    public List<Company> getAllCompanies() {
        return companyRepository.findAll();
    }

    public Company getCompanyDetail(Long id) {
        return companyRepository.findById(id).orElseThrow(() -> new RuntimeException("Company not found"));
    }

    public void updateCompanyStatus(Long id, String status) {
        Company company = getCompanyDetail(id);
        company.setStatus(status);
        companyRepository.save(company);
    }

    public List<Map<String, Object>> getTopCompanies() {
        List<Company> allCompanies = companyRepository.findAll();
        List<Map<String, Object>> result = new ArrayList<>();

        for (Company c : allCompanies) {
            long userCount = userRepository.countByCompanyId(c.getId());
            Map<String, Object> map = new HashMap<>();
            map.put("id", c.getId());
            map.put("name", c.getName());
            map.put("domain", c.getDomain());
            map.put("status", c.getStatus());
            map.put("userCount", userCount);
            map.put("logoUrl", c.getLogoUrl()); // Thêm logo nếu cần
            map.put("industry", c.getIndustry());
            result.add(map);
        }

        return result.stream()
                .sorted((c1, c2) -> Long.compare((long)c2.get("userCount"), (long)c1.get("userCount")))
                .limit(3)
                .collect(Collectors.toList());
    }

    // --- Cho Company Admin ---
    public Company getMyCompany(Long companyId) {
        if (companyId == null) throw new RuntimeException("User not in company");
        return companyRepository.findById(companyId).orElseThrow(() -> new RuntimeException("Company not found"));
    }

    public Company updateMyCompany(Long companyId, Map<String, Object> req) {
        Company company = getMyCompany(companyId);
        if (req.containsKey("name")) company.setName((String) req.get("name"));
        if (req.containsKey("industry")) company.setIndustry((String) req.get("industry"));
        if (req.containsKey("description")) company.setDescription((String) req.get("description"));
        if (req.containsKey("logoUrl")) company.setLogoUrl((String) req.get("logoUrl"));
        return companyRepository.save(company);
    }
}