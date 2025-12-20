# syntax=docker/dockerfile:1

FROM rust:1.83-bookworm AS builder
WORKDIR /app

# Cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release

# Build actual binary
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim AS runtime
WORKDIR /app

# TLS + CA certs (reqwest rustls still uses OS certs)
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/gachitore-api /app/gachitore-api

ENV HOST=0.0.0.0
ENV PORT=8080
EXPOSE 8080

CMD ["/app/gachitore-api"]


