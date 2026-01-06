package com.officesync.attendance_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    public static final String QUEUE_ATTENDANCE_CONFIG = "attendance.config.queue";
    public static final String ROUTING_KEY_COMPANY_CONFIG = "company.config.update";

    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }

    @Bean
    public Queue attendanceConfigQueue() {
        return new Queue(QUEUE_ATTENDANCE_CONFIG);
    }

    @Bean
    public Binding bindingAttendanceConfig(Queue attendanceConfigQueue, TopicExchange internalExchange) {
        return BindingBuilder.bind(attendanceConfigQueue)
                .to(internalExchange)
                .with(ROUTING_KEY_COMPANY_CONFIG);
    }

    // [QUAN TRỌNG] Khai báo ObjectMapper là @Bean để Spring có thể Inject vào nơi khác
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // Đăng ký module JavaTime để xử lý ngày tháng (LocalDate/LocalDateTime)
        mapper.registerModule(new JavaTimeModule());
        return mapper;
    }

    // Sử dụng ObjectMapper vừa tạo ở trên cho Converter
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