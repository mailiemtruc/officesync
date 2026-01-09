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
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.jsontype.BasicPolymorphicTypeValidator;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Configuration
@EnableCaching
public class RedisConfig {

    @Bean
    public RedisCacheConfiguration cacheConfiguration() {
        ObjectMapper objectMapper = new ObjectMapper();
        
        // 1. Module ngày tháng
        objectMapper.registerModule(new JavaTimeModule());
        
        // 2. Bỏ qua lỗi field thừa
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        // Thay thế đoạn activateDefaultTyping bằng:
    objectMapper.activateDefaultTyping(
    BasicPolymorphicTypeValidator.builder()
        .allowIfBaseType(Object.class) // Cho phép cơ bản
        .allowIfSubType("com.officesync.hr_service") // Chỉ cho phép class của dự án
        .allowIfSubType("java.util.ArrayList")
        .allowIfSubType("java.util.HashMap")
        .build(),
    ObjectMapper.DefaultTyping.NON_FINAL,
    JsonTypeInfo.As.PROPERTY
    );

        // 4. Tạo Serializer
        GenericJackson2JsonRedisSerializer serializer = new GenericJackson2JsonRedisSerializer(objectMapper);

        return RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(60))
            .disableCachingNullValues()
            .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(serializer));
    }

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory redisConnectionFactory) {
        // ... (Giữ nguyên phần Map cấu hình của bạn)
        Map<String, RedisCacheConfiguration> configurationMap = new HashMap<>();
        
        configurationMap.put("departments", cacheConfiguration().entryTtl(Duration.ofHours(2)));
        configurationMap.put("hr_department", cacheConfiguration().entryTtl(Duration.ofHours(2)));
        
        configurationMap.put("employees", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        configurationMap.put("employee_detail", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        
        configurationMap.put("request_detail", cacheConfiguration().entryTtl(Duration.ofMinutes(30)));
        // Lưu ý: TTL ngắn cho list request vì nó thay đổi liên tục
        configurationMap.put("request_list_user", cacheConfiguration().entryTtl(Duration.ofMinutes(10))); 
        configurationMap.put("request_list_manager", cacheConfiguration().entryTtl(Duration.ofMinutes(10)));

        return RedisCacheManager.builder(redisConnectionFactory)
                .cacheDefaults(cacheConfiguration())
                .withInitialCacheConfigurations(configurationMap)
                .build();
    }
}