package com.officesync.core.config;

import org.springframework.amqp.core.Binding; // Import đủ
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
@Configuration
public class RabbitMQConfig {

    // --- 1. INTERNAL EXCHANGE (Giữ nguyên cho các event nội bộ Core bắn đi) ---
    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    public static final String QUEUE_COMPANY_CREATE = "company.create.queue";
    public static final String ROUTING_KEY_COMPANY_CREATE = "company.create";
    public static final String ROUTING_KEY_USER_STATUS = "user.status.change";

    // --- 2. EMPLOYEE EXCHANGE (NHẬN TỪ HR) ---
    public static final String EMPLOYEE_EXCHANGE = "employee.exchange";
    
    // [QUAN TRỌNG] Chỉ dùng 1 hàng đợi duy nhất cho Employee
    public static final String QUEUE_EMPLOYEE_SYNC = "employee.create.queue"; 
    
    // Wildcard # sẽ hứng tất cả: employee.create, employee.update, employee.delete
    public static final String ROUTING_KEY_EMPLOYEE_WILDCARD = "employee.#"; 

    // --- BEAN DEFINITIONS ---

    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }
    
    @Bean
    public TopicExchange employeeExchange() {
        return new TopicExchange(EMPLOYEE_EXCHANGE);
    }

    @Bean
    public Queue employeeSyncQueue() {
        return new Queue(QUEUE_EMPLOYEE_SYNC);
    }

    // [QUAN TRỌNG] Binding hàng đợi này với tất cả các key bắt đầu bằng "employee."
    @Bean
    public Binding bindingEmployeeSync(Queue employeeSyncQueue, TopicExchange employeeExchange) {
        return BindingBuilder.bind(employeeSyncQueue)
                .to(employeeExchange)
                .with(ROUTING_KEY_EMPLOYEE_WILDCARD);
    }

    // --- JSON CONVERTER (Giữ nguyên để xử lý LocalDate) ---
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