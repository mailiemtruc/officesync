package com.officesync.core.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.officesync.core.model.User;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email); // Tìm user theo email
    Optional<User> findByMobileNumber(String mobileNumber);
}