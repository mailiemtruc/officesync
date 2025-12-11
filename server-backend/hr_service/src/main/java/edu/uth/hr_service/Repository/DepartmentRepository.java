package edu.uth.hr_service.Repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import edu.uth.hr_service.Model.Department;

@Repository
public interface DepartmentRepository extends JpaRepository<Department, Long> {

    boolean existsByCode(String code);

    // Tìm phòng ban theo code
    Optional<Department> findByCode(String code);
}