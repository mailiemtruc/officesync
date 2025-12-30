package com.officesync.note_service.service;

import java.util.List;

// [1] Thêm import này
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.officesync.note_service.model.Note;
import com.officesync.note_service.repository.NoteRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class NoteService {

    private final NoteRepository noteRepository;
    // [2] Inject công cụ mã hóa (Bean này được tạo trong SecurityConfig)
    private final PasswordEncoder passwordEncoder;

    public List<Note> getNotes(Long userId) {
        return noteRepository.findByUserIdOrderByIsPinnedDescUpdatedAtDesc(userId);
    }

    public Note createNote(Long userId, Note note) {
        note.setUserId(userId);
        
        if (note.getTitle() == null || note.getTitle().isEmpty()) {
            note.setTitle("No Title");
        }
        if (note.getColor() == null) {
            note.setColor("0xFFFFFFFF");
        }
        
        // [3] Mã hóa PIN khi tạo mới (Nếu có)
        if (note.getPin() != null && !note.getPin().isEmpty()) {
            note.setPin(passwordEncoder.encode(note.getPin()));
        }
        
        return noteRepository.save(note);
    }

    public Note updateNote(Long userId, Long noteId, Note req) {
        Note note = noteRepository.findById(noteId)
                .orElseThrow(() -> new RuntimeException("Note not found"));

        if (!note.getUserId().equals(userId)) {
            throw new RuntimeException("Unauthorized");
        }

        if (req.getTitle() != null) note.setTitle(req.getTitle());
        if (req.getContent() != null) note.setContent(req.getContent());
        if (req.getColor() != null) note.setColor(req.getColor());
        
        note.setPinned(req.isPinned());

        // [4] LOGIC CẬP NHẬT PIN BẢO MẬT
        String incomingPin = req.getPin();
        
        if (incomingPin == null) {
            // Trường hợp 1: Mobile gửi null -> Gỡ bỏ khóa
            note.setPin(null); 
        } else {
            // Trường hợp 2: Có gửi PIN lên
            // Kiểm tra xem PIN này là "số mới" hay là "mã hash cũ" mobile gửi lại?
            // BCrypt hash luôn bắt đầu bằng "$2a$"
            if (incomingPin.startsWith("$2a$")) {
                // Đây là mã hash cũ, giữ nguyên không làm gì cả
                note.setPin(incomingPin);
            } else {
                // Đây là mã PIN mới (VD: "123456") -> Cần mã hóa
                note.setPin(passwordEncoder.encode(incomingPin));
            }
        }

        return noteRepository.save(note);
    }

    public void deleteNote(Long userId, Long noteId) {
        Note note = noteRepository.findById(noteId)
                .orElseThrow(() -> new RuntimeException("Note not found"));
        
        if (!note.getUserId().equals(userId)) {
            throw new RuntimeException("Unauthorized");
        }
        noteRepository.delete(note);
    }

    public List<Note> searchNotes(Long userId, String query) {
        return noteRepository.findByUserIdAndTitleContainingIgnoreCaseOrContentContainingIgnoreCase(userId, query, query);
    }
}