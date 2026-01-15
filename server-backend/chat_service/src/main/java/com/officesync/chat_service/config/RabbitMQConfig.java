package com.officesync.chat_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    // ========================================================================
    // 1. CẤU HÌNH CŨ (Đồng bộ User từ Core Service) - GIỮ NGUYÊN
    // ========================================================================
    public static final String EXCHANGE_INTERNAL = "internal.exchange";
    public static final String ROUTING_KEY_COMPANY_CREATE = "company.create"; 
    public static final String QUEUE_CHAT_USER_SYNC = "chat.user.sync.queue";

    @Bean
    public TopicExchange internalExchange() {
        return new TopicExchange(EXCHANGE_INTERNAL);
    }

    @Bean
    public Queue chatUserSyncQueue() {
        return new Queue(QUEUE_CHAT_USER_SYNC);
    }

    @Bean
    public Binding bindingChatUserSync(Queue chatUserSyncQueue, TopicExchange internalExchange) {
        return BindingBuilder.bind(chatUserSyncQueue)
                .to(internalExchange)
                .with(ROUTING_KEY_COMPANY_CREATE);
    }

    // ========================================================================
    // 2. CẤU HÌNH MỚI (Đồng bộ Department từ HR Service) - THÊM VÀO
    // ========================================================================
    public static final String HR_EXCHANGE = "hr_exchange";          // Exchange riêng của HR
    public static final String HR_EVENT_QUEUE = "hr_event_queue";    // Queue hứng sự kiện HR
    public static final String HR_ROUTING_KEY = "hr_routing_key";    // Key định tuyến

    @Bean
    public TopicExchange hrExchange() {
        return new TopicExchange(HR_EXCHANGE);
    }

    @Bean
    public Queue hrEventQueue() {
        return new Queue(HR_EVENT_QUEUE, true); // durable = true
    }

    @Bean
    public Binding bindingHrEvent(Queue hrEventQueue, TopicExchange hrExchange) {
        return BindingBuilder.bind(hrEventQueue)
                .to(hrExchange)
                .with(HR_ROUTING_KEY);
    }

    // ========================================================================
    // 3. CONVERTER CHUNG (Dùng cho cả 2)
    // ========================================================================
    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}