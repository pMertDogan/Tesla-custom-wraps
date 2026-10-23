# Production image for Tesla Wrap Studio.
#
#   docker build -t tesla-wrap-studio .
#   docker run --rm -p 8080:8080 tesla-wrap-studio
#
# The bundle is built with `--base-href /`, which is right for a root domain.
# Pass `--build-arg BASE_HREF=/studio/` to serve it from a sub path.

# --- Build stage -----------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG BASE_HREF=/
ENV BASE_HREF=${BASE_HREF}

WORKDIR /app

# Dependencies first: this layer is reused until pubspec changes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter build web --release --base-href "${BASE_HREF}"

# --- Runtime stage ---------------------------------------------------------
FROM nginx:1.27-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
