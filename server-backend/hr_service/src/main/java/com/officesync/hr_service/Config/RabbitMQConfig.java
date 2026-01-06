package com.officesync.hr_service.Config;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
public class RabbitMQConfig {

    // Tên hàng đợi phải TRÙNG KHỚP với bên Core Service
    public static final String QUEUE_COMPANY_CREATE = "company.create.queue";

    // 1. Định nghĩa tên Exchange và Routing Key của Core
    public static final String INTERNAL_EXCHANGE = "internal.exchange";
    public static final String ROUTING_KEY_USER_STATUS = "user.status.change";

   
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
// [SỬA LỖI] Inject ObjectMapper vào để khởi tạo Converter chuẩn
    @Bean
    public MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter jsonMessageConverter) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(jsonMessageConverter);
        return template;
    }

    // =========================================================
    // CẤU HÌNH MỚI CHO CHIỀU: HR -> CORE
    // =========================================================
    
    public static final String EMPLOYEE_EXCHANGE = "employee.exchange";
    public static final String EMPLOYEE_ROUTING_KEY = "employee.create";
    public static final String EMPLOYEE_QUEUE = "employee.create.queue";
    public static final String EMPLOYEE_UPDATE_ROUTING_KEY = "employee.update";
    public static final String EMPLOYEE_ROUTING_WILDCARD = "employee.#";
    public static final String FILE_EXCHANGE = "file.exchange";
    public static final String FILE_DELETE_ROUTING_KEY = "file.delete";
    public static final String FILE_DELETE_QUEUE = "file.delete.queue";
    public static final String EMPLOYEE_DELETE_ROUTING_KEY = "employee.delete";
    // [MỚI] Cấu hình cho Notification
    public static final String NOTIFICATION_EXCHANGE = "notification.exchange";
    public static final String NOTIFICATION_ROUTING_KEY = "notification.send";

    @Bean
    public TopicExchange notificationExchange() {
        return new TopicExchange(NOTIFICATION_EXCHANGE);
    }
    
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



    @Bean
    public Queue fileDeleteQueue() {
        return new Queue(FILE_DELETE_QUEUE);
    }
    
    @Bean 
    public TopicExchange fileExchange() {
        return new TopicExchange(FILE_EXCHANGE);
    }

    @Bean
    public Binding fileBinding(Queue fileDeleteQueue, TopicExchange fileExchange) {
        return BindingBuilder.bind(fileDeleteQueue).to(fileExchange).with(FILE_DELETE_ROUTING_KEY);
    }

     // 2. Khai báo Exchange (Để code bên dưới có cái mà dùng)
    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(INTERNAL_EXCHANGE);
    }

    // 3. [QUAN TRỌNG NHẤT] Nối dây: Bảo Exchange đẩy tin "Status" vào Queue "company.create"
    @Bean
    public Binding bindingUserStatus(
            @Qualifier("queue") Queue companyQueue, 
            TopicExchange internalExchange) {
        
        return BindingBuilder
                .bind(companyQueue)
                .to(internalExchange)
                .with(ROUTING_KEY_USER_STATUS);
    }
}