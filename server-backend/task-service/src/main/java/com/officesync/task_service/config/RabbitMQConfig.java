package com.officesync.task_service.config;

import java.util.Map;
import java.util.HashMap;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.DefaultJackson2JavaTypeMapper;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    // 1. Đồng bộ Nhân sự
    public static final String EMPLOYEE_EXCHANGE = "employee.exchange";
    public static final String TASK_EMPLOYEE_SYNC_QUEUE = "task.employee.sync.queue";

    // 2. Đồng bộ Phòng ban
    public static final String HR_EXCHANGE = "hr_exchange";
    public static final String TASK_DEPT_SYNC_QUEUE = "task.dept.sync.queue";
    public static final String HR_ROUTING_KEY = "hr_routing_key";

    // 3. Thông báo (Output)
    public static final String NOTIFICATION_EXCHANGE = "notification.exchange";
    public static final String NOTIFICATION_ROUTING_KEY = "notification.send";

    //Request
    public static final String SYNC_REQUEST_QUEUE = "sync.request.queue";
    public static final String SYNC_REQUEST_EXCHANGE = "sync.request.exchange";
    public static final String SYNC_REQUEST_ROUTING_KEY = "sync.request.key";

    @Bean
    public Queue syncRequestQueue() {
        return new Queue(SYNC_REQUEST_QUEUE, true);
    }

    @Bean
    public TopicExchange syncRequestExchange() {
        return new TopicExchange(SYNC_REQUEST_EXCHANGE);
    }

    @Bean
    public Binding syncRequestBinding(Queue syncRequestQueue, TopicExchange syncRequestExchange) {
        return BindingBuilder.bind(syncRequestQueue).to(syncRequestExchange).with(SYNC_REQUEST_ROUTING_KEY);
    }

    @Bean
    public TopicExchange employeeExchange() { return new TopicExchange(EMPLOYEE_EXCHANGE); }

    @Bean
    public TopicExchange hrExchange() { return new TopicExchange(HR_EXCHANGE); }

    @Bean
    public Queue employeeQueue() { return new Queue(TASK_EMPLOYEE_SYNC_QUEUE, true); }

    @Bean
    public Queue deptQueue() { return new Queue(TASK_DEPT_SYNC_QUEUE, true); }

    @Bean
    public Binding bindingEmployee(Queue employeeQueue, TopicExchange employeeExchange) {
        return BindingBuilder.bind(employeeQueue).to(employeeExchange).with("employee.#");
    }

    @Bean
    public Binding bindingDept(Queue deptQueue, TopicExchange hrExchange) {
        return BindingBuilder.bind(deptQueue).to(hrExchange).with(HR_ROUTING_KEY);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        // Cấu hình ObjectMapper tương đồng với hr-service
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        // Tránh lỗi khi HR gửi thêm các trường mà Task Service chưa cần đến
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        Jackson2JsonMessageConverter converter = new Jackson2JsonMessageConverter(objectMapper);
        
        // Cấu hình TypeMapper để ánh xạ Class giữa các Microservices
        DefaultJackson2JavaTypeMapper typeMapper = new DefaultJackson2JavaTypeMapper();
        typeMapper.setTrustedPackages("*"); // Tin tưởng dữ liệu đến từ các service nội bộ

        // Ánh xạ đích danh từ Package của HR sang Class cục bộ của Task
        Map<String, Class<?>> idClassMapping = new HashMap<>();
        idClassMapping.put("com.officesync.hr_service.DTO.EmployeeSyncEvent", 
                        com.officesync.task_service.dto.EmployeeSyncEvent.class);
        idClassMapping.put("com.officesync.hr_service.DTO.DepartmentSyncEvent", 
                        com.officesync.task_service.dto.DepartmentSyncEvent.class);
        
        typeMapper.setIdClassMapping(idClassMapping);
        converter.setJavaTypeMapper(typeMapper);
        
        return converter;
    }
}