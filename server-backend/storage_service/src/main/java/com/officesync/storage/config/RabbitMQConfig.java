package com.officesync.storage.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {
    
    public static final String FILE_EXCHANGE = "file.exchange";
    public static final String FILE_DELETE_ROUTING_KEY = "file.delete";
    public static final String FILE_DELETE_QUEUE = "file.delete.queue";

    // 1. Cấu hình Converter để nhận tin nhắn dạng JSON (hoặc String)
    @Bean
    public MessageConverter converter() {
        return new Jackson2JsonMessageConverter();
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
        return BindingBuilder.bind(fileDeleteQueue)
                .to(fileExchange)
                .with(FILE_DELETE_ROUTING_KEY);
    }
}