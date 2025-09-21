#!/bin/bash

# PostgreSQL with PostGIS and pgvector Extension Test Script
# This script tests both PostGIS 3.5 and pgvector 0.8.0 extensions

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-pgvector-postgis-test}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-testpassword}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
IMAGE_NAME="${IMAGE_NAME:-pgvector-postgis:test}"

echo "======================================"
echo "PostgreSQL Extensions Test Suite"
echo "======================================"
echo ""

# Function to run SQL commands
run_sql() {
    docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -t -A -c "$1" 2>/dev/null
}

# Function to check test result
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        exit 1
    fi
}

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build --platform linux/amd64 -t "$IMAGE_NAME" .
check_result "Docker image built successfully"

# Stop and remove existing container if it exists
echo -e "${YELLOW}Cleaning up existing containers...${NC}"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Start the container
echo -e "${YELLOW}Starting PostgreSQL container...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -p "$POSTGRES_PORT:5432" \
    "$IMAGE_NAME"
check_result "Container started"

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
        break
    fi
    echo -n "."
    sleep 1
done
echo ""
docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER"
check_result "PostgreSQL is ready"

echo ""
echo "======================================"
echo "Testing PostGIS Extension"
echo "======================================"
echo ""

# Test 1: Check PostGIS version
POSTGIS_VERSION=$(run_sql "SELECT PostGIS_Version();" | tr -d '[:space:]')
echo "PostGIS Version: $POSTGIS_VERSION"
check_result "PostGIS version retrieved"

# Test 2: Verify all PostGIS extensions are installed
echo -e "${YELLOW}Checking PostGIS extensions...${NC}"
run_sql "SELECT extname FROM pg_extension WHERE extname LIKE 'postgis%' ORDER BY extname;" | while read ext; do
    echo -e "  ${GREEN}✓${NC} $ext installed"
done

# Test 3: Test basic geometry operations
echo -e "${YELLOW}Testing geometry operations...${NC}"
POINT_TEST=$(run_sql "SELECT ST_AsText(ST_MakePoint(1,2));")
if [ "$POINT_TEST" = "POINT(1 2)" ]; then
    check_result "Point creation works"
else
    echo -e "${RED}✗${NC} Point creation failed"
    exit 1
fi

# Test 4: Test distance calculation
DISTANCE=$(run_sql "SELECT ST_Distance(ST_MakePoint(0,0), ST_MakePoint(3,4));")
if [ "$DISTANCE" = "5" ]; then
    check_result "Distance calculation works"
else
    echo -e "${RED}✗${NC} Distance calculation failed"
    exit 1
fi

# Test 5: Test polygon area calculation
AREA=$(run_sql "SELECT ST_Area(ST_MakePolygon(ST_GeomFromText('LINESTRING(0 0,0 1,1 1,1 0,0 0)')));")
if [ "$AREA" = "1" ]; then
    check_result "Area calculation works"
else
    echo -e "${RED}✗${NC} Area calculation failed"
    exit 1
fi

# Test 6: Test spatial relationships
CONTAINS=$(run_sql "SELECT ST_Contains(
    ST_GeomFromText('POLYGON((0 0, 0 10, 10 10, 10 0, 0 0))'),
    ST_GeomFromText('POINT(5 5)')
);")
if [ "$CONTAINS" = "t" ]; then
    check_result "Spatial relationships work"
else
    echo -e "${RED}✗${NC} Spatial relationships failed"
    exit 1
fi

# Test 7: Test geocoding tables (check if tiger_geocoder is available)
TIGER_EXISTS=$(run_sql "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis_tiger_geocoder');")
if [ "$TIGER_EXISTS" = "t" ]; then
    check_result "Tiger Geocoder extension available"
else
    echo -e "${YELLOW}!${NC} Tiger Geocoder extension not found (optional)"
fi

echo ""
echo "======================================"
echo "Testing pgvector Extension"
echo "======================================"
echo ""

# Test 1: Check pgvector version
PGVECTOR_VERSION=$(run_sql "SELECT extversion FROM pg_extension WHERE extname = 'vector';")
echo "pgvector Version: $PGVECTOR_VERSION"
check_result "pgvector version retrieved"

# Test 2: Create table with vector column
echo -e "${YELLOW}Testing vector operations...${NC}"
run_sql "DROP TABLE IF EXISTS vector_test CASCADE;"
run_sql "CREATE TABLE vector_test (
    id serial PRIMARY KEY,
    embedding vector(3),
    metadata jsonb
);"
check_result "Created table with vector column"

# Test 3: Insert vector data
run_sql "INSERT INTO vector_test (embedding, metadata) VALUES
    ('[1,2,3]', '{\"name\": \"vec1\"}'),
    ('[4,5,6]', '{\"name\": \"vec2\"}'),
    ('[7,8,9]', '{\"name\": \"vec3\"}');"
check_result "Inserted vector data"

# Test 4: Test L2 distance
L2_RESULT=$(run_sql "SELECT COUNT(*) FROM vector_test WHERE embedding <-> '[1,2,3]' < 6;")
if [ "$L2_RESULT" = "2" ]; then
    check_result "L2 distance search works"
else
    echo -e "${RED}✗${NC} L2 distance search failed"
    exit 1
fi

# Test 5: Test cosine distance
COSINE_RESULT=$(run_sql "SELECT COUNT(*) FROM vector_test WHERE embedding <=> '[1,2,3]' < 0.05;")
if [ "$COSINE_RESULT" = "2" ]; then
    check_result "Cosine distance search works"
else
    echo -e "${RED}✗${NC} Cosine distance search failed"
    exit 1
fi

# Test 6: Test inner product
IP_RESULT=$(run_sql "SELECT embedding <#> '[1,1,1]' FROM vector_test ORDER BY embedding <#> '[1,1,1]' LIMIT 1;")
if [ ! -z "$IP_RESULT" ]; then
    check_result "Inner product search works"
else
    echo -e "${RED}✗${NC} Inner product search failed"
    exit 1
fi

# Test 7: Create and test vector index
run_sql "CREATE INDEX ON vector_test USING ivfflat (embedding vector_l2_ops) WITH (lists = 1);"
check_result "Created IVFFlat index"

# Test 8: Test vector aggregation
AVG_VECTOR=$(run_sql "SELECT AVG(embedding) FROM vector_test;")
if [ ! -z "$AVG_VECTOR" ]; then
    check_result "Vector aggregation works"
else
    echo -e "${RED}✗${NC} Vector aggregation failed"
    exit 1
fi

# Clean up test table
run_sql "DROP TABLE vector_test;"

echo ""
echo "======================================"
echo "Combined PostGIS + pgvector Tests"
echo "======================================"
echo ""

# Test combining spatial and vector data
echo -e "${YELLOW}Testing combined spatial-vector operations...${NC}"

run_sql "CREATE TABLE locations_with_embeddings (
    id serial PRIMARY KEY,
    name text,
    location geometry(Point, 4326),
    description_embedding vector(384)
);"
check_result "Created table with both geometry and vector columns"

run_sql "INSERT INTO locations_with_embeddings (name, location, description_embedding) VALUES
    ('Location A', ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326), '[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4]');"
check_result "Inserted combined spatial-vector data"

# Create spatial and vector indexes
run_sql "CREATE INDEX idx_location ON locations_with_embeddings USING GIST (location);"
check_result "Created spatial index"

run_sql "CREATE INDEX idx_embedding ON locations_with_embeddings USING ivfflat (description_embedding vector_l2_ops) WITH (lists = 1);"
check_result "Created vector index on combined table"

# Clean up
run_sql "DROP TABLE locations_with_embeddings;"

echo ""
echo "======================================"
echo -e "${GREEN}All tests passed successfully!${NC}"
echo "======================================"
echo ""

# Show summary
echo "Summary:"
echo "  - PostGIS Version: $POSTGIS_VERSION"
echo "  - pgvector Version: $PGVECTOR_VERSION"
echo "  - Both extensions are working correctly"
echo "  - Spatial operations: ✓"
echo "  - Vector operations: ✓"
echo "  - Combined spatial-vector operations: ✓"

echo ""
echo "Container '$CONTAINER_NAME' is running with both extensions."
echo "Connect using: psql -h localhost -p $POSTGRES_PORT -U $POSTGRES_USER"
echo ""

# Optional: Stop the container
read -p "Do you want to stop and remove the test container? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Stopping and removing container...${NC}"
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
    echo -e "${GREEN}Container removed.${NC}"
fi