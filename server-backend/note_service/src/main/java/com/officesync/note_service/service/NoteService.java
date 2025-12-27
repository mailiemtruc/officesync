package com.officesync.note_service.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.officesync.note_service.model.Note;
import com.officesync.note_service.repository.NoteRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class NoteService {

    private final NoteRepository noteRepository;

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
        note.setPinned(req.isPinned()); // Update trạng thái ghim

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