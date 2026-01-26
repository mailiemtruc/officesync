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
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        // Bảo mật Type Validator
        objectMapper.activateDefaultTyping(
            BasicPolymorphicTypeValidator.builder()
                .allowIfBaseType(Object.class)
                .allowIfSubType("com.officesync.hr_service")
                .allowIfSubType("java.util.ArrayList")
                .allowIfSubType("java.util.HashMap")
                .build(),
            ObjectMapper.DefaultTyping.NON_FINAL,
            JsonTypeInfo.As.PROPERTY
        );

        GenericJackson2JsonRedisSerializer serializer = new GenericJackson2JsonRedisSerializer(objectMapper);

        return RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(60)) // Mặc định 60 phút
            .disableCachingNullValues()
            .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(serializer));
    }

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory redisConnectionFactory) {
        Map<String, RedisCacheConfiguration> configMap = new HashMap<>();
        
      
        
        // 2. Dữ liệu nhân viên - 1 giờ
        configMap.put("employee_detail", cacheConfiguration().entryTtl(Duration.ofHours(1)));
        configMap.put("employees_by_company", cacheConfiguration().entryTtl(Duration.ofHours(1))); 
        configMap.put("employees_by_department", cacheConfiguration().entryTtl(Duration.ofMinutes(30))); 

        // 3. Request Detail - 1 ngày
        configMap.put("request_detail", cacheConfiguration().entryTtl(Duration.ofDays(1))); 
        // Thêm config cho 2 loại cache mới
       configMap.put("departments_metadata", cacheConfiguration().entryTtl(Duration.ofHours(24))); 
       configMap.put("departments_stats", cacheConfiguration().entryTtl(Duration.ofHours(2)));    
        // 4. Request List (User & Manager) - Short Lived (2 phút)
        // Phải khai báo rõ ràng tên cache được dùng trong Service
        RedisCacheConfiguration shortLivedConfig = cacheConfiguration().entryTtl(Duration.ofMinutes(2));
        configMap.put("request_list_user", shortLivedConfig);
        configMap.put("request_list_manager", shortLivedConfig);

        return RedisCacheManager.builder(redisConnectionFactory)
                .cacheDefaults(cacheConfiguration())
                .withInitialCacheConfigurations(configMap)
                .build();
    }
}