FROM nginx:alpine

# Copy custom HTML to nginx default location
COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Use nginx default command
CMD ["nginx", "-g", "daemon off;"]