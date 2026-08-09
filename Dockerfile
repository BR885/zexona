FROM dart:stable

WORKDIR /app

# Copy everything
COPY . .

# Go to the server folder
WORKDIR /app/zexona_server

# Get dependencies
RUN dart pub get

# Run the server on port 8080
CMD ["dart", "simple_server.dart"]