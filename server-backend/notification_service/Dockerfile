# STAGE 1: Build
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# STAGE 2: Run
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
# Copy file key firebase vào container (nếu build gói vào jar thì bước này optional, nhưng cứ copy cho chắc)
COPY src/main/resources/service-account.json /app/service-account.json

RUN apk add --no-cache tzdata
ENV TZ=Asia/Ho_Chi_Minh

EXPOSE 8089
ENTRYPOINT ["java", "-jar", "app.jar"]