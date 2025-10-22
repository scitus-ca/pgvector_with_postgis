# PostgreSQL 16 with PostGIS 3.5 and pgvector 0.8.0
FROM postgis/postgis:16-3.5

# Install build dependencies and pgvector
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-16 \
    git \
    && git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd / \
    && rm -rf /pgvector \
    && apt-get remove -y build-essential git \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create init script to enable extensions by default
RUN echo "#!/bin/bash\n\
set -e\n\
\n\
# Create extensions in template database so all new databases have them\n\
psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" --dbname template1 <<-EOSQL\n\
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;\n\
    CREATE EXTENSION IF NOT EXISTS postgis;\n\
    CREATE EXTENSION IF NOT EXISTS postgis_topology;\n\
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;\n\
    CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;\n\
    CREATE EXTENSION IF NOT EXISTS vector;\n\
EOSQL\n\
\n\
# Also create in default postgres database\n\
psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" --dbname postgres <<-EOSQL\n\
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;\n\
    CREATE EXTENSION IF NOT EXISTS postgis;\n\
    CREATE EXTENSION IF NOT EXISTS postgis_topology;\n\
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;\n\
    CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;\n\
    CREATE EXTENSION IF NOT EXISTS vector;\n\
EOSQL\n\
\n\
echo \"PostGIS and pgvector extensions have been installed\"" > /docker-entrypoint-initdb.d/10-init-extensions.sh \
    && chmod +x /docker-entrypoint-initdb.d/10-init-extensions.sh

# Labels for metadata
LABEL maintainer="Scitus Solutions" \
      description="PostgreSQL 16 with PostGIS 3.5 and pgvector 0.8.0" \
      postgres.version="16" \
      postgis.version="3.5" \
      pgvector.version="0.8.0"