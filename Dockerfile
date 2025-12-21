FROM postgres:18

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential git postgresql-server-dev-18

# Build and install pg_textsearch
RUN git clone https://github.com/timescale/pg_textsearch /tmp/pg_textsearch \
    && cd /tmp/pg_textsearch \
    && make && make install