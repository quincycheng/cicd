FROM openjdk:8-jre-alpine

COPY app.war /app.war

CMD ["/usr/bin/java", "-jar", "-Dspring.profiles.active=test", "/app.war"]

