# Build Stage:
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y gcc make

## Add Source Code
ADD . /wander
WORKDIR /wander

## Build Step
RUN make

# Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
COPY --from=builder /wander/Wander /
COPY --from=builder /wander/a3.misc /
COPY --from=builder /wander/a3.wrld /
