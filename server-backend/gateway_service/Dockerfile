# Build Stage
FROM maven:3.9.6-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Run Stage
FROM eclipse-temurin:21-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

RUN apk add --no-cache tzdata
ENV TZ=Asia/Ho_Chi_Minh

# [NÊN THÊM] Để rõ ràng là Gateway chạy port 8080
EXPOSE 8080 

ENTRYPOINT ["java", "-jar", "app.jar"]