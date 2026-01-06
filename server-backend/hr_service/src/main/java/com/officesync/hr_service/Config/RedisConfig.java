package com.officesync.hr_service.Config;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer; // [MỚI] Dùng cái này
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.jsontype.impl.LaissezFaireSubTypeValidator;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
@EnableCaching
public class RedisConfig {

    @Bean
    public RedisCacheConfiguration cacheConfiguration() {
        // 1. Cấu hình ObjectMapper chuẩn
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        // Cho phép lưu class type để khi đọc lên không bị lỗi ép kiểu
        objectMapper.activateDefaultTyping(
            LaissezFaireSubTypeValidator.instance, 
            ObjectMapper.DefaultTyping.NON_FINAL, 
            JsonTypeInfo.As.PROPERTY
        );

        // 2. [SỬA LỖI] Thay GenericJackson2JsonRedisSerializer bằng Jackson2JsonRedisSerializer
        Jackson2JsonRedisSerializer<Object> serializer = new Jackson2JsonRedisSerializer<>(objectMapper, Object.class);

        return RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(60))
            .disableCachingNullValues()
            .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(serializer));
    }

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory redisConnectionFactory) {
    
        Map<String, RedisCacheConfiguration> configurationMap = new HashMap<>();
        configurationMap.put("departments", cacheConfiguration().entryTtl(Duration.ofHours(2)));
        configurationMap.put("hr_department", cacheConfiguration().entryTtl(Duration.ofHours(2)));
        configurationMap.put("employees", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        configurationMap.put("employee_detail", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        configurationMap.put("request_detail", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        configurationMap.put("request_list_user", cacheConfiguration().entryTtl(Duration.ofMinutes(10)));
        configurationMap.put("request_list_manager", cacheConfiguration().entryTtl(Duration.ofMinutes(10)));

        return RedisCacheManager.builder(redisConnectionFactory)
                .cacheDefaults(cacheConfiguration())
                .withInitialCacheConfigurations(configurationMap)
                .build();
    }
}