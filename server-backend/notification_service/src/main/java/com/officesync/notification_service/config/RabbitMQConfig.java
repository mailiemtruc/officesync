// package com.officesync.notification_service.config;

// import org.springframework.amqp.core.*;
// import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter; // Import này
// import org.springframework.amqp.support.converter.MessageConverter; // Import này
// import org.springframework.context.annotation.Bean;
// import org.springframework.context.annotation.Configuration;
// import com.fasterxml.jackson.databind.ObjectMapper;

// @Configuration
// public class RabbitMQConfig {

//     public static final String NOTIFICATION_EXCHANGE = "notification.exchange";
//     public static final String NOTIFICATION_ROUTING_KEY = "notification.send";
//     public static final String NOTIFICATION_QUEUE = "notification.queue";

//     @Bean
//     public TopicExchange notificationExchange() {
//         return new TopicExchange(NOTIFICATION_EXCHANGE);
//     }

//     @Bean
//     public Queue notificationQueue() {
//         return new Queue(NOTIFICATION_QUEUE);
//     }

//     @Bean
//     public Binding binding(Queue notificationQueue, TopicExchange notificationExchange) {
//         return BindingBuilder.bind(notificationQueue).to(notificationExchange).with(NOTIFICATION_ROUTING_KEY);
//     }
 
//     @Bean
//     public ObjectMapper objectMapper() {
//         return new ObjectMapper();
//     }

//     // [THÊM ĐOẠN NÀY] Để Consumer tự hiểu JSON
//     @Bean
//     public MessageConverter jsonMessageConverter() {
//         return new Jackson2JsonMessageConverter();
//     }
// }
package com.officesync.notification_service.config;

import org.springframework.amqp.core.*;
// import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter; // ❌ COMMENT DÒNG NÀY
// import org.springframework.amqp.support.converter.MessageConverter; // ❌ COMMENT DÒNG NÀY
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
public class RabbitMQConfig {

    public static final String NOTIFICATION_EXCHANGE = "notification.exchange";
    public static final String NOTIFICATION_ROUTING_KEY = "notification.send";
    public static final String NOTIFICATION_QUEUE = "notification.queue";

    @Bean
    public TopicExchange notificationExchange() {
        return new TopicExchange(NOTIFICATION_EXCHANGE);
    }

    @Bean
    public Queue notificationQueue() {
        return new Queue(NOTIFICATION_QUEUE);
    }

    @Bean
    public Binding binding(Queue notificationQueue, TopicExchange notificationExchange) {
        return BindingBuilder.bind(notificationQueue).to(notificationExchange).with(NOTIFICATION_ROUTING_KEY);
    }
 
    // @Bean
    // public ObjectMapper objectMapper() {
    //     return new ObjectMapper();
    // }

    // ❌❌❌ XÓA HOẶC COMMENT ĐOẠN NÀY ĐI ❌❌❌
    // Khi xóa bean này, Spring sẽ dùng "SimpleMessageConverter" mặc định.
    // Nó sẽ không cố đọc header __TypeId__ nữa -> Hết lỗi ClassNotFound.
    /*
    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
    */
}