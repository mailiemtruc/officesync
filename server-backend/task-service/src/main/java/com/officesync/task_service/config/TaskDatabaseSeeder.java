// com.officesync.task_service.config.TaskDatabaseSeeder.java
package com.officesync.task_service.config;


import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class TaskDatabaseSeeder implements CommandLineRunner {
    @Override
    public void run(String... args) {
        log.info("--> [Task Service] Service started. Waiting for sync events from RabbitMQ...");
    }
}