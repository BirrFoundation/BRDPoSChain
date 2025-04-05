FROM golang:1.22-alpine as builder

RUN apk add --no-cache make gcc musl-dev linux-headers git

ADD . /BRDPoSChain
RUN cd /BRDPoSChain && make BRC

FROM alpine:latest

WORKDIR /BRDPoSChain

COPY --from=builder /BRDPoSChain/build/bin/BRC /usr/local/bin/BRC

RUN chmod +x /usr/local/bin/BRC

EXPOSE 8545
EXPOSE 30303

ENTRYPOINT ["/usr/local/bin/BRC"]

CMD ["--help"]
