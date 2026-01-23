# STAGE 1: Build (Dùng Maven để đóng gói file .jar)
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
# Tải các thư viện về trước để tận dụng cache của Docker
RUN mvn dependency:go-offline
COPY src ./src
# Build ra file .jar (bỏ qua test để build nhanh hơn)
RUN mvn package -DskipTests

# STAGE 2: Run (Dùng bản JRE nhẹ để chạy ứng dụng)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# Copy file .jar từ giai đoạn builder sang giai đoạn này
COPY --from=builder /app/target/*.jar app.jar

# Mở port 8761 (theo cấu hình server.port trong application.properties)
EXPOSE 8761

ENTRYPOINT ["java", "-jar", "app.jar"]