# 1) Build stage: Gradle로 컴파일·패키징 (테스트는 CI에서 이미 통과했으니 -x test)
FROM gradle:8.5-jdk21 AS builder
WORKDIR /home/gradle/project

# 캐시 활용을 위해 의존성만 먼저 다운로드
COPY gradle gradle
COPY gradlew .
COPY build.gradle settings.gradle ./
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon

# 소스 복사 및 패키징 (테스트 제외)
COPY src src
RUN ./gradlew build -x test --no-daemon

# 2) Runtime stage: 슬림한 JRE 기반
FROM amazoncorretto:21-alpine
WORKDIR /app

# 빌드된 JAR만 복사
COPY --from=builder /home/gradle/project/build/libs/*.jar app.jar

# 외부 설정 파일(application.yml 등)을 마운트할 디렉토리
VOLUME /app/config

# Spring Boot 에게 외부 설정 위치 알려주기
ENV SPRING_CONFIG_LOCATION=classpath:/,file:/app/config/

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
