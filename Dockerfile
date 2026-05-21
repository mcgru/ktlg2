# Build stage
FROM crystallang/crystal:1.20-alpine AS builder

WORKDIR /app
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src ./src
RUN crystal build src/main.cr --release --no-debug --static -o /app/ktlg2

# Runtime stage
FROM alpine:3.23
RUN apk add --no-cache libexif ffmpeg
COPY --from=builder /app/ktlg2 /usr/local/bin/ktlg2
ENTRYPOINT ["/usr/local/bin/ktlg2"]
