# Stage 1: Build the React app
FROM node:22 AS build
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
