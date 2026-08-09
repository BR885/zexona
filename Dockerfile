FROM dart:stable

WORKDIR /app

COPY . .

RUN cd zeXona_server && dart pub get

CMD ["dart", "zeXona_server/simple_server.dart"]