FROM dart:stable

WORKDIR /app

# Copy everything
COPY . .

# List files to debug
RUN ls -la

# Go to the server folder
WORKDIR /app/zeXona_server

# Get dependencies
RUN dart pub get

# Run the server
CMD ["dart", "simple_server.dart"]