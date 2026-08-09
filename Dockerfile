FROM dart:stable

WORKDIR /app

# Copy everything
COPY . .

# Copy and go to the server folder (lowercase 'z')
WORKDIR /app/zexona_server

# Check current directory
RUN pwd && ls -la

# Get dependencies
RUN dart pub get

# Run the server
CMD ["dart", "simple_server.dart"]