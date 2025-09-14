FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -g 1001 -S cloudbridge && adduser -u 1001 -S cloudbridge -G cloudbridge

# Копируем бинарник из артефактов
COPY artifacts/linux/cloudbridge-client-linux-amd64 /usr/local/bin/cloudbridge-client
COPY config/config.yaml /etc/cloudbridge/config.yaml

RUN mkdir -p /var/lib/cloudbridge /var/log/cloudbridge && \
    chown -R cloudbridge:cloudbridge /var/lib/cloudbridge /var/log/cloudbridge /etc/cloudbridge

USER cloudbridge
WORKDIR /var/lib/cloudbridge

EXPOSE 8080 8443

CMD ["cloudbridge-client"]
