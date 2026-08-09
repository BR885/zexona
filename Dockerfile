FROM dart:stable

WORKDIR /app

COPY zecona_server/ .

RUN dart pub get

CMD ["dart", "simple_server.dart"]