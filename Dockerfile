FROM dart:stable

WORKDIR /app

COPY zeXona_server/ .

RUN dart pub get

CMD ["dart", "simple_server.dart"]