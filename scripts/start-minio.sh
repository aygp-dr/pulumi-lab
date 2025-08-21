#!/bin/sh
# Start Minio S3-compatible storage on FreeBSD

MINIO_DATA="$HOME/minio-data"
MINIO_LOG="/tmp/minio.log"
MINIO_PID="/tmp/minio.pid"

echo "========================================="
echo "Starting Minio S3-Compatible Storage"
echo "========================================="
echo ""

# Check if Minio is installed
if ! command -v minio >/dev/null 2>&1; then
    echo "✗ Minio not installed"
    echo "Install with: sudo pkg install minio minio-client"
    exit 1
fi

echo "✓ Minio version: $(minio --version 2>&1 | head -1)"
echo ""

# Check if already running
if pgrep minio >/dev/null 2>&1; then
    echo "⚠️  Minio is already running"
    echo "Stop with: pkill minio"
    exit 1
fi

# Create data directory
mkdir -p "$MINIO_DATA"
echo "✓ Data directory: $MINIO_DATA"

# Start Minio in background
echo "Starting Minio server..."
echo ""

# Export credentials
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin

# Start Minio
nohup minio server "$MINIO_DATA" \
    --address ":9000" \
    --console-address ":9001" \
    > "$MINIO_LOG" 2>&1 &

echo $! > "$MINIO_PID"

echo "Waiting for Minio to start..."
sleep 3

# Check if running
if pgrep minio >/dev/null 2>&1; then
    echo "✓ Minio is running (PID: $(cat $MINIO_PID))"
    echo ""
    echo "========================================="
    echo "Minio Started Successfully!"
    echo "========================================="
    echo ""
    echo "Endpoints:"
    echo "  S3 API:  http://localhost:9000"
    echo "  Console: http://localhost:9001"
    echo ""
    echo "Credentials:"
    echo "  Access Key: minioadmin"
    echo "  Secret Key: minioadmin"
    echo ""
    echo "Logs: tail -f $MINIO_LOG"
    echo "Stop: pkill minio"
    echo ""
    echo "Configure AWS CLI:"
    echo "  export AWS_ENDPOINT=http://localhost:9000"
    echo "  export AWS_ACCESS_KEY_ID=minioadmin"
    echo "  export AWS_SECRET_ACCESS_KEY=minioadmin"
    echo ""
    echo "Test connection:"
    echo "  aws --endpoint-url=http://localhost:9000 s3 ls"
    echo ""
    echo "Configure Minio client:"
    echo "  mc alias set local http://localhost:9000 minioadmin minioadmin"
    echo "  mc ls local"
    echo "========================================="
else
    echo "✗ Failed to start Minio"
    echo "Check logs: cat $MINIO_LOG"
    exit 1
fi