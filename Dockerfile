FROM dart:stable

WORKDIR /app

COPY zeXona_server/ zeXona_server/

WORKDIR /app/zeXona_server

RUN dart pub get

CMD ["dart", "simple_server.dart"]