FROM dart:stable

WORKDIR /app

# Copy everything
COPY . .

# Go to the server folder
WORKDIR /app/zeXona_server

# List files to see what's there
RUN ls -la

# Get dependencies
RUN dart pub get

# Run the server
CMD ["dart", "simple_server.dart"]