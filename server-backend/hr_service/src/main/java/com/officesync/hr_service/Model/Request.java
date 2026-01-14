package com.officesync.hr_service.Model;

import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import jakarta.persistence.Column; // Sử dụng * cho gọn
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
@Entity
@Table(name = "requests", indexes = {
    @Index(name = "idx_request_user", columnList = "user_id"), 
    @Index(name = "idx_request_dept", columnList = "department_id"),
    @Index(name = "idx_request_status", columnList = "status"), 
    @Index(name = "idx_request_code", columnList = "request_code"), 
    @Index(name = "idx_request_type", columnList = "type"),
    @Index(name = "idx_req_company_created", columnList = "company_id, created_at")
})
@Data
@EqualsAndHashCode(callSuper = true)
@JsonIgnoreProperties(value = {"hibernateLazyInitializer", "handler"}, ignoreUnknown = true)
public class Request extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "request_code", length = 20, unique = true, updatable = false)
    private String requestCode;

   @ManyToOne(fetch = FetchType.LAZY)
   @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "password", "requests"})
    @JoinColumn(name = "user_id", nullable = false)
    private Employee requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "manager", "members", "employees"})
    @JoinColumn(name = "department_id")
    private Department department;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RequestType type; 

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RequestStatus status; 

    @Column(name = "start_time", nullable = false)
    private LocalDateTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalDateTime endTime;

    @Column(name = "duration_val")
    private Float durationVal; 

    @Enumerated(EnumType.STRING)
    @Column(name = "duration_unit")
    private DurationUnit durationUnit;

    @Column(columnDefinition = "TEXT")
    private String reason; 

    @Column(name = "evidence_url")
    private String evidenceUrl; 

    @ManyToOne(fetch = FetchType.LAZY)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "requests"}) // Thêm ignore cho approver
    @JoinColumn(name = "approver_id")
    private Employee approver; 

    @Column(columnDefinition = "TEXT")
    private String rejectReason; 
    // File: Request.java
  @Column(name = "is_hidden")
   private Boolean isHidden = false; // Mặc định là false (hiện)
}
