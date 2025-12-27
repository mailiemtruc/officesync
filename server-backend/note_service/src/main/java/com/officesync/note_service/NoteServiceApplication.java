package com.officesync.note_service;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing; // 1. Thêm import này

@SpringBootApplication
@EnableJpaAuditing // 2. Thêm dòng này để kích hoạt tự động điền ngày giờ
public class NoteServiceApplication {

	public static void main(String[] args) {
		SpringApplication.run(NoteServiceApplication.class, args);
	}

}