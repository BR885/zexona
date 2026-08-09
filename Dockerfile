FROM dart:stable

WORKDIR /app

# Copy everything
COPY . .

# List all files and folders
RUN ls -la

# Look for server folder
RUN ls -la ze* || echo "No ze folder found"
RUN ls -la *server* || echo "No server folder found"

# Try to go to the server folder
WORKDIR /app/zeXona_server || WORKDIR /app/zexona_server || WORKDIR /app/zecona_server

# Show current directory
RUN pwd

# Show files in current directory
RUN ls -la

# Get dependencies
RUN dart pub get

CMD ["dart", "simple_server.dart"]