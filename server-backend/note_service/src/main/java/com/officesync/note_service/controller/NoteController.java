package com.officesync.note_service.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping; // Import gọn
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.note_service.model.Note;
import com.officesync.note_service.service.NoteService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/notes")
@RequiredArgsConstructor
public class NoteController {

    private final NoteService noteService; // Controller chỉ cần biết Service

    @GetMapping
    public ResponseEntity<List<Note>> getMyNotes(@RequestHeader("X-User-Id") Long userId) {
        return ResponseEntity.ok(noteService.getNotes(userId));
    }

    @PostMapping
    public ResponseEntity<Note> createNote(@RequestHeader("X-User-Id") Long userId, @RequestBody Note note) {
        return ResponseEntity.ok(noteService.createNote(userId, note));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Note> updateNote(
            @RequestHeader("X-User-Id") Long userId,
            @PathVariable Long id,
            @RequestBody Note note) {
        return ResponseEntity.ok(noteService.updateNote(userId, id, note));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNote(@RequestHeader("X-User-Id") Long userId, @PathVariable Long id) {
        noteService.deleteNote(userId, id);
        return ResponseEntity.ok(Map.of("message", "Deleted successfully"));
    }

    // --- ĐOẠN CODE ĐÃ SỬA ---
    @GetMapping("/search")
    public ResponseEntity<List<Note>> searchNotes(
            @RequestHeader("X-User-Id") Long userId,
            @RequestParam("q") String query) {
        
        // [SỬA LẠI] Gọi qua noteService thay vì noteRepository
        return ResponseEntity.ok(noteService.searchNotes(userId, query));
    }
}