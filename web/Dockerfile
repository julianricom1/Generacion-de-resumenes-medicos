# Stage 1: Build the React app
FROM node:22 AS build

# Accept build arguments
ARG VITE_CLASSIFICATION_DOMAIN
ARG VITE_GENERATION_DOMAIN
ARG VITE_METRICS_DOMAIN

# Set them as environment variables for the build
ENV VITE_CLASSIFICATION_DOMAIN=${VITE_CLASSIFICATION_DOMAIN}
ENV VITE_GENERATION_DOMAIN=${VITE_GENERATION_DOMAIN}
ENV VITE_METRICS_DOMAIN=${VITE_METRICS_DOMAIN}

WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN yarn
COPY web/. .
RUN yarn run build

# Stage 2: Serve the app with a lightweight web server
FROM nginx:alpine
COPY --from=build /web/dist /usr/share/nginx/html
COPY web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
