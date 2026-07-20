# Backend image (NestJS modular monolith + admin console). Multi-stage.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/
COPY apps/admin/package.json apps/admin/
RUN npm ci
COPY apps/backend apps/backend
COPY apps/admin apps/admin
RUN npm run build --workspace @rideshare/backend && npm run build --workspace admin

FROM node:24-alpine AS prod-deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/
RUN npm ci --omit=dev --workspace @rideshare/backend

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=4000 ADMIN_STATIC_DIR=/app/admin-dist
COPY --from=prod-deps /app ./
COPY --from=build /app/apps/backend/dist ./apps/backend/dist
COPY --from=build /app/apps/admin/dist ./admin-dist
USER node
EXPOSE 4000
CMD ["node", "apps/backend/dist/main.js"]
