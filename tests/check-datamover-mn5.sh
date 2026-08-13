#!/usr/bin/env bash
set -e

# Smoke test for MareNostrum5 datamover connectivity
# Verifies SSH access, required paths, and critical binaries

DATAMOVER_HOST="${DATAMOVER_HOST:-mn5-prod-client1}"
DATAMOVER_USER="${DATAMOVER_USER:-datamover}"

echo "Checking SSH connectivity to ${DATAMOVER_USER}@${DATAMOVER_HOST}..."

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "${DATAMOVER_USER}@${DATAMOVER_HOST}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "ERROR: Cannot connect to ${DATAMOVER_USER}@${DATAMOVER_HOST}"
    echo "Ensure SSH keys are configured and the host is reachable"
    exit 1
fi

echo "SSH connection established"
echo ""

echo "Checking required paths..."
required_paths=(
    "/staging"
    "/home/service/databridge"
    "/home/service/gateway"
    "/opt/ecmwf/mars-client-cpp/bin"
)

paths_ok=true
for path in "${required_paths[@]}"; do
    if ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "test -d '${path}'" 2>/dev/null; then
        echo "  OK: ${path}"
    else
        echo "  MISSING: ${path}"
        paths_ok=false
    fi
done

if [ "$paths_ok" = false ]; then
    echo ""
    echo "ERROR: Some required paths are missing"
    exit 1
fi

echo ""
echo "Checking critical binaries and versions..."
required_binaries=(
    "/home/datamover/apptainer-install-dir/bin/apptainer"
    "/opt/ecmwf/mars-client-cpp/bin/fdb-copy"
    "/opt/ecmwf/mars-client-cpp/bin/fdb-list"
)

binaries_ok=true
for binary in "${required_binaries[@]}"; do
    if ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "test -x '${binary}'" 2>/dev/null; then
        echo "  OK: ${binary}"
    else
        echo "  MISSING: ${binary}"
        binaries_ok=false
    fi
done

if [ "$binaries_ok" = false ]; then
    echo ""
    echo "ERROR: Some required binaries are missing"
    exit 1
fi

# Collect version information
echo ""
echo "Collecting version information..."
APPTAINER_VERSION=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "/home/datamover/apptainer-install-dir/bin/apptainer --version 2>/dev/null" | head -1 || echo "unknown")
FDB_COPY_VERSION=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "/opt/ecmwf/mars-client-cpp/bin/fdb-copy --version 2>&1" | head -1 || echo "unknown")
FDB_LIST_VERSION=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "/opt/ecmwf/mars-client-cpp/bin/fdb-list --version 2>&1" | head -1 || echo "unknown")
echo "  apptainer: ${APPTAINER_VERSION}"
echo "  fdb-copy: ${FDB_COPY_VERSION}"
echo "  fdb-list: ${FDB_LIST_VERSION}"

# Collect disk space information
echo ""
echo "Collecting disk space information..."
STAGING_DISK_INFO=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "df -B1 /staging 2>/dev/null | tail -1" || echo "")
if [ -n "${STAGING_DISK_INFO}" ]; then
    STAGING_TOTAL=$(echo "${STAGING_DISK_INFO}" | awk '{print $2}')
    STAGING_USED=$(echo "${STAGING_DISK_INFO}" | awk '{print $3}')
    STAGING_AVAIL=$(echo "${STAGING_DISK_INFO}" | awk '{print $4}')
    STAGING_PERCENT=$(echo "${STAGING_DISK_INFO}" | awk '{print $5}' | tr -d '%')
    echo "  /staging: ${STAGING_AVAIL} bytes available (${STAGING_PERCENT}% used)"
else
    STAGING_TOTAL="unknown"
    STAGING_USED="unknown"
    STAGING_AVAIL="unknown"
    STAGING_PERCENT="unknown"
fi

DATABRIDGE_DISK_INFO=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "df -B1 /home/service/databridge 2>/dev/null | tail -1" || echo "")
if [ -n "${DATABRIDGE_DISK_INFO}" ]; then
    DATABRIDGE_TOTAL=$(echo "${DATABRIDGE_DISK_INFO}" | awk '{print $2}')
    DATABRIDGE_USED=$(echo "${DATABRIDGE_DISK_INFO}" | awk '{print $3}')
    DATABRIDGE_AVAIL=$(echo "${DATABRIDGE_DISK_INFO}" | awk '{print $4}')
    DATABRIDGE_PERCENT=$(echo "${DATABRIDGE_DISK_INFO}" | awk '{print $5}' | tr -d '%')
    echo "  /home/service/databridge: ${DATABRIDGE_AVAIL} bytes available (${DATABRIDGE_PERCENT}% used)"
else
    DATABRIDGE_TOTAL="unknown"
    DATABRIDGE_USED="unknown"
    DATABRIDGE_AVAIL="unknown"
    DATABRIDGE_PERCENT="unknown"
fi

echo ""
echo "Testing data transfer..."

# Create a small test file with xarray tutorial-like data
TEST_DIR=$(mktemp -d)
TEST_FILE="${TEST_DIR}/xarray_test_data.nc"
REMOTE_TEST_DIR="/staging/smoke_test_$$"

# Generate minimal NetCDF-like test data (just a small binary file for transfer test)
# In a real scenario this could be actual xarray data, but for smoke testing
# we just need to verify the transfer mechanism works
python3 -c "
import os
try:
    import xarray as xr
    # Use xarray's tutorial dataset (air temperature - small subset)
    ds = xr.tutorial.load_dataset('air_temperature').isel(time=slice(0, 10), lat=slice(0, 5), lon=slice(0, 5))
    ds.to_netcdf('${TEST_FILE}')
    print('Created test NetCDF using xarray tutorial data')
except ImportError:
    # Fallback: create a simple test file if xarray not available
    with open('${TEST_FILE}', 'wb') as f:
        f.write(b'SMOKE_TEST_DATA_' + os.urandom(1024))
    print('Created simple test file (xarray not available)')
"

if [ ! -f "${TEST_FILE}" ]; then
    echo "ERROR: Failed to create test file"
    rm -rf "${TEST_DIR}"
    exit 1
fi

TEST_FILE_SIZE=$(stat -f%z "${TEST_FILE}" 2>/dev/null || stat -c%s "${TEST_FILE}")
echo "  Created test file: ${TEST_FILE} (${TEST_FILE_SIZE} bytes)"

# Create remote directory and transfer
echo "  Transferring to ${DATAMOVER_HOST}:${REMOTE_TEST_DIR}..."
ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "mkdir -p '${REMOTE_TEST_DIR}'"

if ! scp -q "${TEST_FILE}" "${DATAMOVER_USER}@${DATAMOVER_HOST}:${REMOTE_TEST_DIR}/"; then
    echo "ERROR: Failed to transfer test file"
    ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "rm -rf '${REMOTE_TEST_DIR}'" 2>/dev/null || true
    rm -rf "${TEST_DIR}"
    exit 1
fi

# Verify transfer
REMOTE_SIZE=$(ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "stat -c%s '${REMOTE_TEST_DIR}/xarray_test_data.nc'" 2>/dev/null || echo "0")
if [ "${REMOTE_SIZE}" != "${TEST_FILE_SIZE}" ]; then
    echo "ERROR: Transfer verification failed (size mismatch: local=${TEST_FILE_SIZE}, remote=${REMOTE_SIZE})"
    ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "rm -rf '${REMOTE_TEST_DIR}'" 2>/dev/null || true
    rm -rf "${TEST_DIR}"
    exit 1
fi

echo "  Transfer verified (${REMOTE_SIZE} bytes)"

# Cleanup
echo "  Cleaning up..."
ssh "${DATAMOVER_USER}@${DATAMOVER_HOST}" "rm -rf '${REMOTE_TEST_DIR}'"
rm -rf "${TEST_DIR}"
echo "  Cleanup complete"

# Export dotenv for downstream jobs
echo ""
echo "Exporting datamover info..."
cat >de340-datamover-mn5.env <<EOF
MN5_DATAMOVER_ACCESSIBLE=true
MN5_DATAMOVER_INFO='{"versions":{"apptainer":"${APPTAINER_VERSION}","fdb_copy":"${FDB_COPY_VERSION}","fdb_list":"${FDB_LIST_VERSION}"},"disk":{"staging":{"total_bytes":${STAGING_TOTAL:-0},"used_bytes":${STAGING_USED:-0},"avail_bytes":${STAGING_AVAIL:-0},"used_percent":${STAGING_PERCENT:-0}},"databridge":{"total_bytes":${DATABRIDGE_TOTAL:-0},"used_bytes":${DATABRIDGE_USED:-0},"avail_bytes":${DATABRIDGE_AVAIL:-0},"used_percent":${DATABRIDGE_PERCENT:-0}}}}'
EOF
echo "Exported to de340-datamover-mn5.env"

echo ""
echo "SUCCESS: MareNostrum5 datamover is accessible and configured correctly"
