# Multi-stage build for production optimization
FROM public.ecr.aws/docker/library/node:20-alpine AS base

# Install security updates and curl for health checks
RUN apk add --no-cache curl \
    && apk upgrade --no-cache

# Create app user for security
RUN addgroup -g 1001 -S nodejs \
    && adduser -S nodejs -u 1001

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production --silent \
    && npm cache clean --force

# Copy application code
COPY . .

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /app
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Expose port
EXPOSE 3000

# Use non-root user
ENV NODE_ENV=production
ENV PORT=3000

# Start application
CMD ["node", "index.js"]
