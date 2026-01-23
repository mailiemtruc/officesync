# STAGE 1: Build
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /app

# 1. Copy và Cài đặt Core Service trước (Để tạo thư viện trong local repo của Docker)
COPY core_service /app/core_service
RUN mvn -f /app/core_service/pom.xml clean install -DskipTests

# 2. Thiết lập cho Communication Service
WORKDIR /app/communication_service

# Copy file pom.xml riêng của service này
COPY communication_service/pom.xml .
# Tải các thư viện về (Lúc này nó sẽ tìm thấy core_service vừa cài ở trên)
RUN mvn dependency:go-offline

# Copy source code và build
COPY communication_service/src ./src
RUN mvn package -DskipTests

# STAGE 2: Run
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# Lưu ý đường dẫn copy file jar đã thay đổi
COPY --from=builder /app/communication_service/target/*.jar app.jar

EXPOSE 8088
ENTRYPOINT ["java", "-jar", "app.jar"]