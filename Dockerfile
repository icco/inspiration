# Build stage
FROM golang:1.26-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /server .

# Final stage
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /server /server

ENV NAT_ENV="production"
EXPOSE 8080

# Run as the conventional nobody UID; no /etc/passwd is needed for a
# numeric USER directive and scratch images have no useradd utility.
USER 65534:65534

ENTRYPOINT ["/server"]
