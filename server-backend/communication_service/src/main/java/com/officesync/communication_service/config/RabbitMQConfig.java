package com.officesync.communication_service.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.fasterxml.jackson.databind.ObjectMapper; // <--- Nhớ import dòng này
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule; // <--- Import để parse ngày tháng (LocalDate)

@Configuration
public class RabbitMQConfig {

    public static final String QUEUE_NEWSFEED_USER_SYNC = "newsfeed.user.sync.queue";
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

    @Bean
    public Binding bindingNewsfeed(Queue newsfeedUserQueue, TopicExchange internalExchange) {
        return BindingBuilder.bind(newsfeedUserQueue).to(internalExchange).with(ROUTING_KEY_COMPANY_CREATE);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    // ✅✅✅ THÊM ĐOẠN NÀY ĐỂ FIX LỖI "Could not be found"
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // Đăng ký module để xử lý LocalDate/LocalDateTime (tránh lỗi parse ngày tháng sau này)
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }
}