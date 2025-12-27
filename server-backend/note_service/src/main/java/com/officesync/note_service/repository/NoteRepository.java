package com.officesync.note_service.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.note_service.model.Note;

@Repository
public interface NoteRepository extends JpaRepository<Note, Long> {

    // Lấy list note của user: Ghim lên đầu -> Mới sửa lên đầu
    List<Note> findByUserIdOrderByIsPinnedDescUpdatedAtDesc(Long userId);

    // Tìm kiếm
    List<Note> findByUserIdAndTitleContainingIgnoreCaseOrContentContainingIgnoreCase(Long userId, String title, String content);
}
