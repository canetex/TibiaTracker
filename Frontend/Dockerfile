# =============================================================================
# TIBIA TRACKER - FRONTEND DOCKERFILE
# =============================================================================
# Multi-stage build para React + Nginx
# =============================================================================

# Stage 1: Build da aplicação React
FROM node:18-alpine AS builder

# Declarar argumentos de build
ARG REACT_APP_API_URL
ARG REACT_APP_ENVIRONMENT

# Converter argumentos em variáveis de ambiente
ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV REACT_APP_ENVIRONMENT=$REACT_APP_ENVIRONMENT

# Definir diretório de trabalho
WORKDIR /app

# Copiar package.json e package-lock.json
COPY package*.json ./

# Instalar dependências
RUN npm install --silent

# Copiar código fonte
COPY . .

# Build da aplicação para produção
RUN npm run build

# Stage 2: Servidor Nginx
FROM nginx:alpine

# Copiar configuração customizada do Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copiar arquivos buildados do React
COPY --from=builder /app/build /usr/share/nginx/html

# Criar diretório para logs
RUN mkdir -p /var/log/nginx

# Expor porta 80
EXPOSE 80

# Comando para iniciar o Nginx
CMD ["nginx", "-g", "daemon off;"] 