package com.officesync.communication_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    // Tên hàng đợi riêng của Service Newsfeed
    public static final String QUEUE_NEWSFEED_USER_SYNC = "newsfeed.user.sync.queue";
    
    // Tên Exchange và Routing Key PHẢI KHỚP với bên Core Service
    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    public static final String ROUTING_KEY_COMPANY_CREATE = "company.create";

    @Bean
    public Queue newsfeedUserQueue() {
        return new Queue(QUEUE_NEWSFEED_USER_SYNC);
    }

    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }

    // Gắn hàng đợi này vào Exchange để nhận tin nhắn
    @Bean
    public Binding bindingNewsfeed(Queue newsfeedUserQueue, TopicExchange internalExchange) {
        return BindingBuilder.bind(newsfeedUserQueue).to(internalExchange).with(ROUTING_KEY_COMPANY_CREATE);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}