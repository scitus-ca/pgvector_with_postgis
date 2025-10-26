# PostgreSQL with PostGIS and pgvector

<div align="center">

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?style=for-the-badge&logo=postgresql&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-3.5-green?style=for-the-badge&logo=postgresql&logoColor=white)
![pgvector](https://img.shields.io/badge/pgvector-0.8.0-purple?style=for-the-badge&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

**A production-ready PostgreSQL Docker image combining spatial and vector capabilities for AI-powered geospatial applications**
 
Brought to you by [**Scitus Solutions Ltd.**](https://scitus.ca) 

</div>

---

## Why This Image?

The intersection of AI and geospatial technology is revolutionizing how we understand and interact with location-based data. Modern applications increasingly need to:

- **Perform semantic searches** on location descriptions using embeddings
- **Find similar places** based on both geographic proximity and contextual similarity
- **Build intelligent geographic recommendation systems** that understand both "where" and "what"
- **Process satellite imagery** with vector embeddings while maintaining spatial reference
- **Create location-aware chatbots and AI assistants** that understand geographic context

This Docker image bridges the gap between traditional GIS operations and modern AI vector similarity search, enabling developers to build sophisticated geospatial AI applications without managing complex infrastructure.

## Key Features

- **PostgreSQL 16**: Latest stable version with performance improvements
- **PostGIS 3.5**: Industry-standard spatial database extender
  - Full OGC compliant spatial operations
  - Geographic and geometric data types
  - Spatial indexing with R-tree/GIST
  - Topology and raster support
  - Tiger Geocoder for address standardization
- **pgvector 0.8.0**: State-of-the-art vector similarity search
  - Store embeddings up to 16,000 dimensions
  - L2 distance, inner product, and cosine distance operations
  - IVFFlat and HNSW indexing for billion-scale similarity search
  - Perfect for LLM embeddings, image vectors, and feature representations

## Installation

### Using Docker Hub

```bash
docker pull scitus/pgvector-postgis:latest
```

### Building from Source

```bash
git clone https://github.com/scitus-solutions/pgvector-postgis.git
cd pgvector-postgis

# Standard build (1.47GB)
docker build -t pgvector-postgis .

# Optimized build (635MB - 57% smaller!)
docker build -f Dockerfile.optimized -t pgvector-postgis:optimized .
```

## Quick Start

### Basic Usage

```bash
docker run -d \
  --name postgis-vector-db \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  scitus/pgvector-postgis:latest
```

### Docker Compose

```yaml
version: '3.8'
services:
  db:
    image: scitus/pgvector-postgis:latest
    environment:
      POSTGRES_DB: geodata
      POSTGRES_USER: geoai
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

volumes:
  pgdata:
```

## Use Cases

### 1. Semantic Location Search
```sql
-- Store locations with their embeddings
CREATE TABLE places (
    id SERIAL PRIMARY KEY,
    name TEXT,
    location GEOMETRY(POINT, 4326),
    description TEXT,
    description_embedding VECTOR(1536)  -- OpenAI embedding dimension
);

-- Find places similar to "cozy coffee shop with outdoor seating"
SELECT name, ST_AsText(location)
FROM places
ORDER BY description_embedding <=> '[...]'::vector
LIMIT 5;
```

### 2. Geospatial Similarity with Context
```sql
-- Find similar locations within 5km that match the vibe
SELECT
    name,
    ST_Distance(location::geography, query_point::geography) / 1000 AS distance_km,
    description_embedding <=> query_embedding AS similarity
FROM places
WHERE ST_DWithin(
    location::geography,
    ST_MakePoint(-79.3832, 43.6532)::geography,
    5000
)
ORDER BY description_embedding <=> query_embedding
LIMIT 10;
```

### 3. Image-based Geographic Search
```sql
-- Store satellite/drone imagery with vectors
CREATE TABLE imagery (
    id SERIAL PRIMARY KEY,
    captured_at TIMESTAMP,
    bounds GEOMETRY(POLYGON, 4326),
    image_vector VECTOR(2048),
    metadata JSONB
);

-- Find visually similar regions
SELECT id, ST_AsGeoJSON(bounds) AS geojson
FROM imagery
WHERE ST_Intersects(bounds, region_of_interest)
ORDER BY image_vector <-> query_vector
LIMIT 20;
```

### 4. Multi-modal Geographic Recommendations
```sql
-- Combine user preferences, location, and contextual embeddings
WITH user_context AS (
    SELECT
        ST_MakePoint(user_lon, user_lat)::geography AS user_location,
        preference_embedding
    FROM users WHERE id = ?
)
SELECT
    p.name,
    p.category,
    ST_Distance(p.location::geography, u.user_location) / 1000 AS distance_km,
    1 - (p.feature_embedding <=> u.preference_embedding) AS match_score
FROM places p, user_context u
WHERE ST_DWithin(p.location::geography, u.user_location, 10000)
ORDER BY
    (0.3 * (1/(1+distance_km))) +
    (0.7 * match_score) DESC
LIMIT 10;
```

## Testing

We provide comprehensive test scripts to verify your installation:

```bash
# Quick verification test
./quick_test.sh

# Comprehensive test suite
./test_extensions.sh
```

## Performance Considerations

### Image Size Optimization

We provide two Docker image variants:

| Variant | Size | Build Time | Use Case |
|---------|------|------------|----------|
| **Standard** | 1.47GB | Faster | Development, when disk space isn't critical |
| **Optimized** | 635MB | Slower | Production, cloud deployments, Kubernetes |

The optimized image achieves **57% size reduction** through:
- Multi-stage builds separating compilation from runtime
- Minimal package installation with `--no-install-recommends`
- Aggressive cleanup of build dependencies
- Shallow git cloning with `--depth 1`

### Indexing Strategies

```sql
-- Spatial index for geographic queries
CREATE INDEX idx_location ON places USING GIST (location);

-- Vector index for similarity search
CREATE INDEX idx_embedding ON places
USING ivfflat (description_embedding vector_l2_ops)
WITH (lists = 100);  -- Adjust based on data size

-- Combined query optimization
CREATE INDEX idx_location_id ON places USING GIST (location) INCLUDE (id);
```

### Best Practices

1. **Dimension Selection**: Use appropriate vector dimensions (384-1536 for text, 2048-4096 for images)
2. **Index Tuning**: Adjust IVFFlat lists parameter based on dataset size (sqrt(n) is a good starting point)
3. **Query Optimization**: Use ST_DWithin for radius searches instead of ST_Distance with WHERE clause
4. **Connection Pooling**: Implement connection pooling for production workloads
5. **Resource Allocation**: Ensure adequate shared_buffers and work_mem for both spatial and vector operations

## Real-World Applications

This image powers various AI-geospatial applications including:

- **Smart City Planning**: Analyzing urban patterns with combined spatial and semantic understanding
- **Environmental Monitoring**: Tracking changes using satellite imagery embeddings with precise geographic context
- **Location Intelligence**: Building recommendation systems that understand both proximity and preference
- **Autonomous Navigation**: Storing and querying high-dimensional sensor data with spatial context
- **Real Estate Tech**: Matching properties based on location, features, and visual similarity
- **Emergency Response**: Finding similar incident patterns across geographic regions

## Contributing

We welcome contributions! Please feel free to submit issues and pull requests to improve this image.

## License

This Docker image is provided by [Scitus Solutions Ltd](https://scitus.ca) and is available for public use under the MIT License.

**AS-IS WARRANTY DISCLAIMER**: This software is provided "as is" without warranty of any kind, either expressed or implied, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose. The entire risk as to the quality and performance of the software is with you.

## Architecture

```
┌─────────────────────────────────────────┐
│          Your Application               │
│  (Geospatial AI / ML / Analytics)       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         PostgreSQL 16                    │
│                                          │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │   PostGIS    │  │    pgvector     │  │
│  │              │  │                 │  │
│  │ • Spatial    │  │ • Embeddings    │  │
│  │ • Geography  │  │ • Similarity    │  │
│  │ • Topology   │  │ • L2/Cosine     │  │
│  │ • Geocoding  │  │ • IVFFlat/HNSW  │  │
│  └──────────────┘  └─────────────────┘  │
│                                          │
│         Optimized for AI + GIS          │
└──────────────────────────────────────────┘
```

## Links

- **Company**: [Scitus Solutions Ltd.](https://scitus.ca)
- **Documentation**: [PostgreSQL](https://www.postgresql.org/docs/16/) | [PostGIS](https://postgis.net/documentation/) | [pgvector](https://github.com/pgvector/pgvector)
- **Issues**: [GitHub Issues](https://github.com/scitus-solutions/pgvector-postgis/issues)
- **Docker Hub**: [scitus/pgvector-postgis](https://hub.docker.com/r/scitus/pgvector-postgis)

## Support

For commercial support and consulting services for AI-powered geospatial applications, contact [Scitus Solutions Ltd](https://scitus.ca).

---

<div align="center">

**Built with ❤️ by [Scitus Solutions Ltd.](https://scitus.ca)**

*Empowering the next generation of geospatial AI applications*

</div>
