package com.officesync.core.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

// Import các class của Jackson
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    public static final String QUEUE_COMPANY_CREATE = "company.create.queue";
    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    public static final String ROUTING_KEY_COMPANY_CREATE = "company.create";
    public static final String ROUTING_KEY_USER_STATUS = "user.status.update";
    public static final String QUEUE_EMPLOYEE_CREATE = "employee.create.queue";

    @Bean
    public Queue queue() {
        return new Queue(QUEUE_COMPANY_CREATE);
    }

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }

    @Bean
    public Binding binding(Queue queue, TopicExchange exchange) {
        return BindingBuilder.bind(queue).to(exchange).with(ROUTING_KEY_COMPANY_CREATE);
    }

    // 🔴 1. TỰ TẠO BEAN OBJECT MAPPER (Để sửa lỗi "Bean not found")
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // Đăng ký module xử lý ngày tháng Java 8 (LocalDateTime)
        mapper.registerModule(new JavaTimeModule());
        // Tắt tính năng viết ngày tháng dưới dạng timestamp (số) -> chuyển sang dạng chuỗi ISO-8601
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }

    // 🔴 2. SỬ DỤNG BEAN OBJECT MAPPER VỪA TẠO
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

    @Bean
    public Queue employeeQueue() {
        return new Queue(QUEUE_EMPLOYEE_CREATE);
    }
}