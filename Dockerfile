FROM alpine:latest

RUN apk add --no-cache bash curl

WORKDIR /app
COPY hy2.sh .

RUN chmod +x hy2.sh

CMD ["./hy2.sh"]
