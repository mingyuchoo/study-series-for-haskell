FROM fpco/stack-build:lts-24.21
WORKDIR /app
ENV ADDRESS_BOOK_CONTACTS_FILE=/app/data/contacts.json \
    ADDRESS_BOOK_BIND_ADDRESS=0.0.0.0

COPY stack.yaml stack.yaml.lock ./
COPY packages/ packages/
COPY apps/ apps/
COPY static/ static/
RUN mkdir -p /app/data

RUN stack install --no-docker --local-bin-path /app/bin

CMD ["/app/bin/ThreepennyAddress-exe"]
