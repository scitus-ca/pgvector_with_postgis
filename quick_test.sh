#!/bin/bash

# Quick test script for PostgreSQL with PostGIS and pgvector

set -e

echo "======================================"
echo "Quick Extension Test"
echo "======================================"
echo ""

# Test PostGIS
echo "Testing PostGIS..."
docker exec pgvector-postgis-test psql -U postgres -c "
SELECT postgis_version();
SELECT ST_AsText(ST_MakePoint(1,2)) AS test_point;
SELECT ST_Distance(ST_MakePoint(0,0), ST_MakePoint(3,4)) AS distance;
SELECT ST_Area(ST_MakePolygon(ST_GeomFromText('LINESTRING(0 0,0 1,1 1,1 0,0 0)'))) AS area;
"

echo ""
echo "Testing pgvector..."
docker exec pgvector-postgis-test psql -U postgres -c "
SELECT extversion FROM pg_extension WHERE extname = 'vector';
CREATE TABLE IF NOT EXISTS test_vectors (id serial PRIMARY KEY, vec vector(3));
INSERT INTO test_vectors (vec) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT vec, vec <-> '[1,2,3]' AS l2_distance FROM test_vectors ORDER BY l2_distance;
SELECT vec, vec <=> '[1,2,3]' AS cosine_distance FROM test_vectors ORDER BY cosine_distance;
DROP TABLE test_vectors;
"

echo ""
echo "Testing combined functionality..."
docker exec pgvector-postgis-test psql -U postgres -c "
CREATE TABLE IF NOT EXISTS spatial_vectors (
    id serial PRIMARY KEY,
    location geometry(Point, 4326),
    embedding vector(3)
);
INSERT INTO spatial_vectors (location, embedding) VALUES
    (ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326), '[1,2,3]'),
    (ST_SetSRID(ST_MakePoint(-74.006020, 40.712776), 4326), '[4,5,6]');

SELECT
    ST_AsText(location) as location,
    embedding,
    ST_Distance(location::geography, ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326)::geography) as geo_distance_meters,
    embedding <-> '[1,2,3]' as vector_distance
FROM spatial_vectors
ORDER BY vector_distance;

DROP TABLE spatial_vectors;
"

echo ""
echo "======================================"
echo "✅ All tests completed successfully!"
echo "======================================"
echo ""
echo "Summary:"
echo "  - PostGIS: Working ✓"
echo "  - pgvector: Working ✓"
echo "  - Combined operations: Working ✓"
echo ""
echo "Both extensions are fully functional!"