# Backend image (NestJS modular monolith). Multi-stage: build → prod deps → slim runtime.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/
RUN npm ci
COPY apps/backend apps/backend
RUN npm run build --workspace @rideshare/backend

FROM node:24-alpine AS prod-deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/
RUN npm ci --omit=dev

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=4000
COPY --from=prod-deps /app ./
COPY --from=build /app/apps/backend/dist ./apps/backend/dist
USER node
EXPOSE 4000
CMD ["node", "apps/backend/dist/main.js"]
