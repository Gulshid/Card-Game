# Build context = the Flutter project root (the server imports ../lib).
#   docker build -f server/Dockerfile -t spades-server .
FROM dart:stable AS build
WORKDIR /app
# `dart pub get` can't resolve the Flutter SDK, so the server image uses a
# stripped pubspec that keeps only the pure-Dart packages the engine needs.
COPY server/pubspec.server.yaml ./pubspec.yaml
RUN dart pub get
COPY lib ./lib
COPY server ./server
RUN dart compile exe server/spades_server.dart -o /app/spades_server

FROM debian:stable-slim
COPY --from=build /runtime/ /
COPY --from=build /app/spades_server /app/spades_server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/spades_server"]
