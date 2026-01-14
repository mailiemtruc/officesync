// com.officesync.task_service.config.RabbitMQConfig.java
package com.officesync.task_service.config;

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

    // Tên Queue phải DUY NHẤT cho Task Service
    public static final String TASK_SYNC_QUEUE = "task.sync.queue";
    
    // Tên Exchange phải KHỚP với HR Service
    public static final String EMPLOYEE_EXCHANGE = "employee.exchange";

    @Bean
    public TopicExchange employeeExchange() {
        return new TopicExchange(EMPLOYEE_EXCHANGE);
    }

    @Bean
    public Queue taskSyncQueue() {
        return new Queue(TASK_SYNC_QUEUE);
    }

    // Binding: Nối Queue vào Exchange để nhận mọi sự kiện employee.*
    @Bean
    public Binding bindingEmployeeSync(Queue taskSyncQueue, TopicExchange employeeExchange) {
        return BindingBuilder.bind(taskSyncQueue)
                .to(employeeExchange)
                .with("employee.#");
    }

    @Bean
    public MessageConverter converter() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        return new Jackson2JsonMessageConverter(mapper);
    }

    @Bean
    public RabbitTemplate amqpTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(converter());
        return rabbitTemplate;
    }
}