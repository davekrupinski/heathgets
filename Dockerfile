FROM ruby:3.3-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends tzdata ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY lib ./lib
COPY bin ./bin

ENV TZ=America/New_York \
    HEATHGETS_DATA=/data \
    HEATHGETS_RUN_HOURS=6,12

# Default non-root user; override with `user:` in compose to match the NAS share owner.
USER 1000:1000
ENTRYPOINT ["bin/heathgets"]
CMD ["daemon"]
