FROM dart:stable

WORKDIR /app

# Copy the entire project
COPY . .

# Debug: List all files
RUN ls -la

# Debug: Find the server folder
RUN find . -name "simple_server.dart" -type f

# The server file is at zeXona_server/simple_server.dart
WORKDIR /app/zeXona_server

# Debug: Show current folder
RUN pwd
RUN ls -la

# Get dependencies
RUN dart pub get

# Run the server
CMD ["dart", "simple_server.dart"]