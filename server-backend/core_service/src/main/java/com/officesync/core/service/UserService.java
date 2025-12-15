package com.officesync.core.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.model.User;
import com.officesync.core.repository.UserRepository;

@Service
public class UserService {

    @Autowired private UserRepository userRepository;

    public List<User> getUsersByCompanyId(Long companyId) {
        return userRepository.findByCompanyId(companyId);
    }

    public void updateUserStatus(Long userId, String status) {
        User user = userRepository.findById(userId).orElseThrow(() -> new RuntimeException("User not found"));
        user.setStatus(status);
        userRepository.save(user);
    }
}