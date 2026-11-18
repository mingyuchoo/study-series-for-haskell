FROM node:22-bookworm-slim AS frontend
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /frontend
COPY apps/address-book-elm/ ./
RUN npx --yes --package=elm@0.19.3-0 elm make src/Main.elm --optimize --output=/assets/elm.js

FROM fpco/stack-build:lts-24.21
WORKDIR /app
ENV ADDRESS_BOOK_CONTACTS_FILE=/app/data/contacts.json \
    ADDRESS_BOOK_BIND_ADDRESS=0.0.0.0

COPY stack.yaml stack.yaml.lock ./
COPY packages/ packages/
COPY apps/threepenny-address/ apps/threepenny-address/
RUN mkdir -p /app/data

RUN stack install --no-docker --local-bin-path /app/bin

COPY static/index.html static/index.html
COPY --from=frontend /assets/elm.js static/elm.js

CMD ["/app/bin/ThreepennyAddress-exe"]
