FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY package*.json ./
ENV MCP_TRANSPORT=stdio
EXPOSE 3001
CMD ["sh", "-c", "if [ \"$MCP_TRANSPORT\" = 'http' ]; then node dist/index-http.js; else node dist/index.js; fi"]
