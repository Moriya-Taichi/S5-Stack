FROM swift:6.2-noble AS build
WORKDIR /src
COPY . .
RUN swift build -c release --product Server --static-swift-stdlib
RUN swift run -c release Frontend
RUN mkdir /out && cp .build/release/Server /out/ && \
    find .build/release -maxdepth 1 -type d -name '*.resources' -exec cp -R {} /out/ \;

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libcurl4t64 libxml2 libsqlite3-0 tzdata && \
    rm -rf /var/lib/apt/lists/* && useradd --create-home --uid 10001 s5
WORKDIR /app
COPY --from=build --chown=s5:s5 /out/ /app/
COPY --from=build --chown=s5:s5 /src/Public /app/Public
RUN mkdir /data && chown s5:s5 /data
ENV DATABASE_PATH=/data/db.sqlite
USER s5
EXPOSE 8080
ENTRYPOINT ["/app/Server"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
