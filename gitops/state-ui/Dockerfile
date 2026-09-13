# state-ui image — build React SPA, serve with nginx (non-root).
FROM node:20-alpine AS builder
WORKDIR /build
COPY src/package.json src/tsconfig.json src/vite.config.ts src/index.html ./
COPY src/src ./src
RUN npm install --no-audit --no-fund && npm run build

FROM nginx:1.27-alpine
# Non-root nginx: use unprivileged config listening on 8080
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/state-ui.conf
COPY --from=builder /build/dist /usr/share/nginx/html
# nginx:alpine runs as nginx user with master as root; use the official
# unprivileged pattern — pid in /tmp, no setuid needed on port 8080.
RUN sed -i 's/^user  nginx;/user  nginx;/' /etc/nginx/nginx.conf \
    && mkdir -p /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi \
    && chown -R nginx:nginx /usr/share/nginx/html /tmp/nginx-* /var/cache/nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1
CMD ["nginx", "-g", "daemon off;"]
