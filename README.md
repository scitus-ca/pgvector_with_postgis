# PostgreSQL with PostGIS and pgvector

Custom Docker image that combines PostgreSQL 16 with PostGIS 3.5 and pgvector 0.8.0 extensions.

## Features

- **PostgreSQL 16**: Latest stable version
- **PostGIS 3.5**: Full spatial database capabilities
- **pgvector 0.8.0**: Vector similarity search for AI/ML applications
- **Auto-enabled extensions**: Extensions are automatically created in template database

## Extensions Included

- `postgis` - Spatial and geographic objects for PostgreSQL
- `postgis_topology` - PostGIS topology spatial types and functions
- `fuzzystrmatch` - Fuzzy string matching
- `postgis_tiger_geocoder` - PostGIS tiger geocoder and reverse geocoder 
- `vector` - Open-source vector similarity search

## Usage

### Pull from Google Container Registry

```bash
docker pull northamerica-northeast2-docker.pkg.dev/bwis-production-460718/bwis-v8/postgres-postgis-pgvector:latest
```

### Run locally

```bash
docker run -d \
  --name postgres-postgis-pgvector \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  northamerica-northeast2-docker.pkg.dev/bwis-production-460718/bwis-v8/postgres-postgis-pgvector:latest
```

### Use in Kubernetes

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  template:
    spec:
      containers:
      - name: postgres
        image: northamerica-northeast2-docker.pkg.dev/bwis-production-460718/bwis-v8/postgres-postgis-pgvector:latest
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
```

## Build Process

The image is automatically built and pushed to Google Container Registry when changes are pushed to the main branch.

### Manual Build

```bash
# Build locally
docker build -t postgres-postgis-pgvector:latest .

# Test locally
docker run -d \
  --name test-postgres \
  -e POSTGRES_PASSWORD=testpass \
  -p 5432:5432 \
  postgres-postgis-pgvector:latest

# Verify extensions
docker exec test-postgres psql -U postgres -c "SELECT name, default_version FROM pg_available_extensions WHERE name IN ('postgis', 'vector');"
```

## Google Cloud Build Trigger Setup

1. Go to [Cloud Build Triggers](https://console.cloud.google.com/cloud-build/triggers) in GCP Console
2. Click "Create Trigger"
3. Configure:
   - **Name**: `pgvector-with-postgis-build`
   - **Repository**: Connect to this GitHub repository
   - **Branch**: `^main$`
   - **Build Configuration**: `/cloudbuild.yaml`
4. Click "Create"

## Version Information

- Base Image: `postgis/postgis:16-3.5`
- PostgreSQL: 16
- PostGIS: 3.5
- pgvector: 0.8.0

## License

This Docker image combines several open-source projects:
- PostgreSQL: PostgreSQL License
- PostGIS: GNU GPL v2
- pgvector: PostgreSQL License
