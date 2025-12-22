package com.officesync.hr_service.Config;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    // Tên hàng đợi phải TRÙNG KHỚP với bên Core Service
    public static final String QUEUE_COMPANY_CREATE = "company.create.queue";

    // Khai báo Queue để đảm bảo nó tồn tại (nếu Core chưa chạy thì HR chạy lên vẫn tạo queue này)
    @Bean
    public Queue queue() {
        return new Queue(QUEUE_COMPANY_CREATE);
    }

    // Cấu hình Jackson để xử lý LocalDate (Java 8 time)
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

    // =========================================================
    // CẤU HÌNH MỚI CHO CHIỀU: HR -> CORE
    // =========================================================
    
    public static final String EMPLOYEE_EXCHANGE = "employee.exchange";
    public static final String EMPLOYEE_ROUTING_KEY = "employee.create";
    public static final String EMPLOYEE_QUEUE = "employee.create.queue";
    public static final String EMPLOYEE_UPDATE_ROUTING_KEY = "employee.update";
    public static final String EMPLOYEE_ROUTING_WILDCARD = "employee.#";
    @Bean
    public TopicExchange employeeExchange() {
        return new TopicExchange(EMPLOYEE_EXCHANGE);
    }

    @Bean
    public Queue employeeQueue() {
        return new Queue(EMPLOYEE_QUEUE);
    }

    @Bean
    public Binding employeeBinding(Queue employeeQueue, TopicExchange employeeExchange) {
        return BindingBuilder.bind(employeeQueue)
                .to(employeeExchange)
                .with(EMPLOYEE_ROUTING_WILDCARD);
    }
}