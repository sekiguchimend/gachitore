# syntax=docker/dockerfile:1

# Note: Using 1.83 for stability. Some newer dependencies require 1.85+
FROM rust:1.83-bookworm AS builder
WORKDIR /app

# Cache dependencies
COPY services/api_rust/Cargo.toml services/api_rust/Cargo.lock ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release

# Build actual binary
COPY services/api_rust/src ./src
RUN touch src/main.rs && cargo build --release

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


