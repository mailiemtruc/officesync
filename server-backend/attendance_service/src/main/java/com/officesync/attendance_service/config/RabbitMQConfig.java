package com.officesync.attendance_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.fasterxml.jackson.databind.SerializationFeature;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    // --- 1. KHAI BÁO TÊN EXCHANGE VÀ QUEUE ---
    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    
    // Config cho Company/Office (Giữ nguyên)
    public static final String QUEUE_ATTENDANCE_CONFIG = "attendance.config.queue";
    public static final String ROUTING_KEY_COMPANY_CONFIG = "company.config.update";
    
    // Config cho User Sync (SỬA LẠI ĐỂ KHỚP VỚI HR)
    public static final String QUEUE_USER_SYNC = "attendance.user.sync.queue.v2";
    public static final String ROUTING_KEY_USER_SYNC = "user.sync"; // <--- Bắt buộc phải là "user.sync"

    // --- 2. KHỞI TẠO EXCHANGE ---
    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }

    // --- 3. KHỞI TẠO QUEUE ---
    @Bean
    public Queue attendanceConfigQueue() {
        return new Queue(QUEUE_ATTENDANCE_CONFIG, true); // true = durable (bền vững)
    }

    @Bean
    public Queue userSyncQueue() {
        return new Queue(QUEUE_USER_SYNC, true); // true = durable
    }

    // --- 4. BINDING (LIÊN KẾT QUEUE VÀO EXCHANGE) ---

    // Binding nhận cấu hình công ty (Giữ nguyên)
    @Bean
    public Binding bindingAttendanceConfig(Queue attendanceConfigQueue, TopicExchange internalExchange) {
        return BindingBuilder.bind(attendanceConfigQueue)
                .to(internalExchange)
                .with(ROUTING_KEY_COMPANY_CONFIG);
    }

    // [QUAN TRỌNG - ĐÃ SỬA] Binding nhận User Sync từ HR
    @Bean
    public Binding bindingUserSync(Queue userSyncQueue, TopicExchange internalExchange) {
        // Chúng ta bind vào 'internalExchange' với key 'user.sync'
        // Vì bên HR Producer đang gửi: convertAndSend("internal.exchange", "user.sync", ...)
        return BindingBuilder.bind(userSyncQueue)
                .to(internalExchange)
                .with(ROUTING_KEY_USER_SYNC);
    }

    // --- 5. CẤU HÌNH CONVERTER (Giữ nguyên) ---
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }

    @Bean
    public MessageConverter converter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
    
    @Bean
    public RabbitTemplate amqpTemplate(ConnectionFactory connectionFactory, MessageConverter converter) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(converter);
        return rabbitTemplate;
    }
}