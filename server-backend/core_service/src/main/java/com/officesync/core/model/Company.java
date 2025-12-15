package com.officesync.core.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "companies")
@Data
public class Company {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String domain; // Ví dụ: fpt, viettel...

    @Column(columnDefinition = "ENUM('ACTIVE', 'LOCKED') DEFAULT 'ACTIVE'")
    private String status = "ACTIVE";

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "logo_url")
    private String logoUrl;

    @Column(name = "industry")
    private String industry;

    @Column(name = "description", length = 1000)
    private String description;
}