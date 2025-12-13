package com.officesync.core.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.officesync.core.model.Company;

public interface CompanyRepository extends JpaRepository<Company, Long> {
}