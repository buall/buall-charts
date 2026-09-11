# syntax=docker/dockerfile:1

ARG POSTGRESQL_VERSION=15.19
ARG TIMESCALEDB_VERSION=2.28.3
ARG PGDG_VERSION=15.19-1.pgdg13+2

# Build the complete TimescaleDB distribution. Do not set APACHE_ONLY: the
# resulting image must include the TSL modules required for advanced features.
FROM docker.io/library/postgres:${POSTGRESQL_VERSION} AS timescaledb-builder

ARG TIMESCALEDB_VERSION
ARG PGDG_VERSION

USER root

RUN set -eux; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 install -y --no-install-recommends \
        ca-certificates \
        curl \
        build-essential \
        cmake \
        libicu-dev \
        libssl-dev \
        postgresql-server-dev-15=${PGDG_VERSION}; \
    test "$(/usr/lib/postgresql/15/bin/pg_config --version | awk '{print $2}' | cut -d. -f1)" = "15"; \
    curl -fsSL --retry 5 -o /tmp/timescaledb.tar.gz "https://github.com/timescale/timescaledb/archive/refs/tags/${TIMESCALEDB_VERSION}.tar.gz"; \
    mkdir /tmp/timescaledb; \
    tar -xzf /tmp/timescaledb.tar.gz --strip-components=1 -C /tmp/timescaledb; \
    cd /tmp/timescaledb; \
    ./bootstrap -DREGRESS_CHECKS=OFF -DPG_CONFIG=/usr/lib/postgresql/15/bin/pg_config; \
    cmake --build build --parallel 2; \
    cmake --install build; \
    test -f "/usr/lib/postgresql/15/lib/timescaledb-${TIMESCALEDB_VERSION}.so"; \
    test -f "/usr/lib/postgresql/15/lib/timescaledb-tsl-${TIMESCALEDB_VERSION}.so"

FROM docker.io/library/postgres:${POSTGRESQL_VERSION}

ARG TIMESCALEDB_VERSION

USER root

COPY --from=timescaledb-builder /usr/lib/postgresql/15/lib/timescaledb*.so /usr/lib/postgresql/15/lib/
COPY --from=timescaledb-builder /usr/share/postgresql/15/extension/timescaledb* /usr/share/postgresql/15/extension/

RUN set -eux; \
    pg_major="$(pg_config --version | awk '{print $2}' | cut -d. -f1)"; \
    test "${pg_major}" = "15"; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 install -y --no-install-recommends \
        postgresql-15-cron=1.6.8-1.pgdg13+1 \
        postgresql-15-pgaudit=1.7.1-2.pgdg13+1 \
        postgresql-15-repmgr=5.5.0+debpgdg-3.pgdg13+1; \
    rm -rf /var/lib/apt/lists/*; \
    for extension in timescaledb pg_cron pgaudit repmgr; do \
        test -f "/usr/share/postgresql/15/extension/${extension}.control"; \
    done; \
    test -f "/usr/lib/postgresql/15/lib/timescaledb-tsl-${TIMESCALEDB_VERSION}.so"

USER postgres
