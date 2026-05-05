# Use a lightweight Node.js image
FROM node:18-alpine

# Set environment to production
ENV NODE_ENV=production

# Set the working directory
WORKDIR /app


# Copy only package files first for better caching
COPY package.json package-lock.json ./

# Install only production dependencies
RUN npm install --omit=dev && npm cache clean --force

# Copy only necessary application files
COPY index.js ./
# (Optional) Simple healthcheck for container
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
	CMD wget --spider -q http://localhost:3000/ || exit 1

# Expose port 3000
EXPOSE 3000

# Use non-root user for security
USER node

# Start the application
CMD ["node", "index.js"]