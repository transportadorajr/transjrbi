# syntax=docker/dockerfile:1
FROM docker.io/library/rust:1.97-slim AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked --bin xlsx_export

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=build /src/target/release/xlsx_export /usr/local/bin/xlsx_export
ENV XLSX_EXPORT_BIND=0.0.0.0:4000
EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["/usr/local/bin/xlsx_export", "healthcheck"]
ENTRYPOINT ["/usr/local/bin/xlsx_export"]
CMD ["serve"]
