#!/bin/bash

# ============================================================================
# IoTKinect LoRaWAN Management Portal - Smart Export + API System
# ============================================================================
# Version: 3.1 - Multi-Version ChirpStack Compatible
# Fixed: Handles ChirpStack v3 and v4 database schema differences
# ============================================================================

# Configuration
CONTAINER_NAME="chirpstack-docker-postgres-1"
DB_USER="chirpstack"
DB_NAME="chirpstack"
BASE_DIR="$(pwd)/chirpstack_exports"
ARCHIVE_DIR="$BASE_DIR/archive"
CURRENT_DIR="$BASE_DIR/current"
CURRENT_JSON_DIR="$CURRENT_DIR/json"
CURRENT_CODEC_DIR="$CURRENT_DIR/codecs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SERVER_NAME="LNS-IoTKinect"
SERVER_URL="https://lns.ca.iotkinect.io"
API_PORT=8750
KEEP_ARCHIVES=10

# CREATE BASE_DIR FIRST
mkdir -p "$BASE_DIR"

# Generate or reuse API token
TOKEN_FILE="$BASE_DIR/.api_token"
if [ -f "$TOKEN_FILE" ]; then
    API_TOKEN=$(cat "$TOKEN_FILE")
else
    API_TOKEN=$(openssl rand -hex 32)
    echo "$API_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create subdirectories
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$CURRENT_DIR"
mkdir -p "$CURRENT_JSON_DIR"
mkdir -p "$CURRENT_CODEC_DIR"

# Working directories for this export
EXPORT_DIR="$ARCHIVE_DIR/export_${TIMESTAMP}"
JSON_DIR="$EXPORT_DIR/json"
CODEC_DIR="$EXPORT_DIR/codecs"
mkdir -p "$EXPORT_DIR"
mkdir -p "$JSON_DIR"
mkdir -p "$CODEC_DIR"

LOG_FILE="$EXPORT_DIR/export.log"

echo "=========================================="
echo "IoTKinect Smart Export + API v3.1"
echo "=========================================="
echo "Server: $SERVER_NAME"
echo "Timestamp: $TIMESTAMP"
echo "Archive: $EXPORT_DIR"
echo "Current: $CURRENT_DIR"
echo "API Port: $API_PORT"
echo ""

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to export data
export_table() {
    local filename=$1
    local query=$2
    local output_file="$EXPORT_DIR/${filename}.csv"

    echo -e "${BLUE}Exporting: $filename...${NC}"
    log_message "Starting export: $filename"

    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "COPY ($query) TO STDOUT WITH CSV HEADER" > "$output_file"

    if [ $? -eq 0 ]; then
        local record_count=$(tail -n +2 "$output_file" | wc -l)
        echo -e "${GREEN}✓ $filename: $record_count records${NC}"
        log_message "SUCCESS: $filename exported with $record_count records"
    else
        echo -e "${RED}✗ Failed: $filename${NC}"
        log_message "ERROR: Failed to export $filename"
    fi
}

# Check Docker container
echo "Checking Docker container..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: Docker container $CONTAINER_NAME is not running${NC}"
    log_message "ERROR: Docker container not running"
    exit 1
fi
echo -e "${GREEN}✓ Docker container is running${NC}"
echo ""

log_message "=== Export Started ==="

# ============================================================================
# DETECT CHIRPSTACK VERSION
# ============================================================================
echo -e "${MAGENTA}Detecting ChirpStack version...${NC}"
HAS_F_CNT_UP=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'device' AND column_name = 'f_cnt_up'
);
" | tr -d '[:space:]')

if [ "$HAS_F_CNT_UP" = "t" ]; then
    echo -e "${GREEN}✓ Detected ChirpStack v4.x${NC}"
    FCNT_COLUMN="d.f_cnt_up"
else
    echo -e "${GREEN}✓ Detected ChirpStack v3.x${NC}"
    FCNT_COLUMN="COALESCE(d.fcntup, 0)"
fi
echo ""

# ============================================================================
# EXPORTS
# ============================================================================

# 1. ChirpStack Servers Registry
cat > "$EXPORT_DIR/chirpstack_servers.csv" << EOF
server_id,server_name,server_url,environment,sync_timestamp,status,notes
$(uuidgen),${SERVER_NAME},${SERVER_URL},Production,$(date -Iseconds),Active,Automated export
EOF
log_message "Created ChirpStack servers registry"

# 2. Tenants
export_table "tenants" "
SELECT
    id::text as tenant_id,
    name as tenant_name,
    description,
    max_device_count,
    max_gateway_count,
    can_have_gateways,
    private_gateways_up,
    private_gateways_down,
    created_at,
    updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM tenant
ORDER BY name
"

# 3. Applications
export_table "applications" "
SELECT
    a.id::text as application_id,
    a.name as application_name,
    a.description,
    t.name as tenant_name,
    a.tenant_id::text,
    a.created_at,
    a.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM application a
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY a.name
"

# 4. Device Profiles
export_table "device_profiles" "
SELECT
    dp.id::text as profile_id,
    dp.name as profile_name,
    dp.description,
    t.name as tenant_name,
    dp.tenant_id::text,
    dp.region,
    dp.mac_version,
    dp.reg_params_revision,
    dp.supports_otaa,
    dp.supports_class_b,
    dp.supports_class_c,
    dp.payload_codec_runtime,
    dp.uplink_interval,
    dp.device_status_req_interval,
    dp.rx1_delay,
    dp.adr_algorithm_id,
    dp.flush_queue_on_activate,
    dp.allow_roaming,
    dp.auto_detect_measurements,
    dp.created_at,
    dp.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM device_profile dp
LEFT JOIN tenant t ON dp.tenant_id = t.id
ORDER BY dp.name
"

# 5. Devices with Keys
# 5. Devices with Keys (FIXED)
export_table "devices" "
SELECT
    encode(d.dev_eui, 'hex') as device_eui,
    encode(d.join_eui, 'hex') as join_eui,
    encode(dk.app_key, 'hex') as app_key,
    encode(dk.nwk_key, 'hex') as network_key,
    d.name as device_name,
    d.description,
    a.name as application_name,
    d.application_id::text,
    dp.name as device_profile_name,
    d.device_profile_id::text,
    t.name as tenant_name,
    a.tenant_id::text,
    d.enabled_class,
    d.is_disabled,
    d.skip_fcnt_check,
    d.external_power_source,
    d.battery_level,
    d.margin,
    d.dr as data_rate,
    d.latitude,
    d.longitude,
    d.altitude,
    encode(d.dev_addr, 'hex') as device_address,
    encode(d.secondary_dev_addr, 'hex') as secondary_device_address,
    d.last_seen_at,
    d.created_at,
    d.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp,
    CASE
        WHEN d.last_seen_at > NOW() - INTERVAL '24 hours' THEN 'Active'
        WHEN d.last_seen_at > NOW() - INTERVAL '7 days' THEN 'Recent'
        WHEN d.last_seen_at IS NULL THEN 'Never'
        ELSE 'Inactive'
    END as activity_status
FROM device d
LEFT JOIN device_keys dk ON d.dev_eui = dk.dev_eui
LEFT JOIN application a ON d.application_id = a.id
LEFT JOIN device_profile dp ON d.device_profile_id = dp.id
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY d.name
"

# 6. Gateways
export_table "gateways" "
SELECT
    encode(g.gateway_id, 'hex') as gateway_eui,
    g.name as gateway_name,
    g.description,
    t.name as tenant_name,
    g.tenant_id::text,
    g.latitude,
    g.longitude,
    g.altitude,
    g.stats_interval_secs,
    g.last_seen_at,
    g.created_at,
    g.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp,
    CASE
        WHEN g.last_seen_at > NOW() - INTERVAL '5 minutes' THEN 'Online'
        WHEN g.last_seen_at > NOW() - INTERVAL '1 hour' THEN 'Recent'
        WHEN g.last_seen_at IS NULL THEN 'Never Seen'
        ELSE 'Offline'
    END as connection_status
FROM gateway g
LEFT JOIN tenant t ON g.tenant_id = t.id
ORDER BY g.name
"

# 7. Device Classes Reference
cat > "$EXPORT_DIR/device_classes.csv" << 'EOF'
class_name,description,power_consumption,downlink_capability,typical_latency,use_cases,max_devices_recommended
Class A,Bi-directional end-devices with scheduled uplink,Lowest (months-years battery),After uplink only,Depends on uplink schedule,"Battery-powered sensors, periodic monitoring, environmental sensors",Unlimited
Class B,Bi-directional with scheduled receive slots,Medium (weeks-months battery),Scheduled ping slots,Predictable (configurable),"Actuators, street lighting, smart metering, parking sensors",10000+
Class C,Bi-directional with continuous receive windows,Highest (mains-powered),Nearly continuous,Very low (<1 second),"Mains-powered devices, critical actuators, emergency systems, alarms",1000+
EOF

# 8. Export Payload Codecs
echo -e "${BLUE}Exporting payload codecs...${NC}"
CODEC_COUNT=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(DISTINCT dp.id)
FROM device_profile dp
WHERE dp.payload_codec_script IS NOT NULL
  AND dp.payload_codec_script != ''
  AND LENGTH(TRIM(dp.payload_codec_script)) > 0
  AND EXISTS (SELECT 1 FROM device d WHERE d.device_profile_id = dp.id);
" | tr -d ' ')

if [ "$CODEC_COUNT" -gt 0 ]; then
    PROFILE_IDS=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT dp.id::text
    FROM device_profile dp
    WHERE dp.payload_codec_script IS NOT NULL
      AND dp.payload_codec_script != ''
      AND LENGTH(TRIM(dp.payload_codec_script)) > 0
      AND EXISTS (SELECT 1 FROM device d WHERE d.device_profile_id = dp.id)
    ORDER BY dp.name;
    ")
    
    EXPORTED_COUNT=0
    for profile_id in $PROFILE_IDS; do
        [ -z "$profile_id" ] && continue
        
        profile_name=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT name FROM device_profile WHERE id = '$profile_id'::uuid;
        " | tr -d '\r')
        
        safe_filename=$(echo "$profile_name" | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-50)
        codec_file="${CODEC_DIR}/${safe_filename}_${profile_id}.js"
        
        docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT payload_codec_script
        FROM device_profile
        WHERE id = '$profile_id'::uuid;
        " > "$codec_file"
        
        if [ -f "$codec_file" ] && [ -s "$codec_file" ]; then
            echo -e "${GREEN}  ✓ $profile_name${NC}"
            EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
        fi
    done
    log_message "Exported $EXPORTED_COUNT codec scripts"
else
    log_message "No codec scripts to export"
fi

# Export codec metadata
export_table "payload_codecs_metadata" "
SELECT
    dp.id::text as profile_id,
    dp.name as profile_name,
    dp.payload_codec_runtime as codec_runtime,
    LENGTH(dp.payload_codec_script) as codec_size_bytes,
    dp.description,
    t.name as tenant_name,
    t.id::text as tenant_id,
    dp.created_at as codec_created,
    dp.updated_at as codec_updated,
    '1.0' as codec_version,
    COUNT(d.dev_eui) as devices_using_profile,
    REPLACE(REPLACE(dp.name, ' ', '_'), '/', '_') || '_' || dp.id::text || '.js' as codec_filename,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM device_profile dp
LEFT JOIN tenant t ON dp.tenant_id = t.id
LEFT JOIN device d ON d.device_profile_id = dp.id
WHERE dp.payload_codec_script IS NOT NULL
  AND dp.payload_codec_script != ''
  AND LENGTH(TRIM(dp.payload_codec_script)) > 0
  AND EXISTS (SELECT 1 FROM device dev WHERE dev.device_profile_id = dp.id)
GROUP BY dp.id, dp.name, dp.payload_codec_runtime, dp.payload_codec_script,
         dp.description, t.name, t.id, dp.created_at, dp.updated_at
ORDER BY t.name, dp.name
"

# 9-21. Continue with all other exports...
export_table "device_summary" "
SELECT
    t.name as tenant_name,
    t.id::text as tenant_id,
    COUNT(d.dev_eui) as total_devices,
    COUNT(CASE WHEN d.is_disabled = false THEN 1 END) as active_devices,
    COUNT(CASE WHEN d.is_disabled = true THEN 1 END) as disabled_devices,
    COUNT(CASE WHEN d.last_seen_at > NOW() - INTERVAL '24 hours' THEN 1 END) as devices_seen_24h,
    COUNT(CASE WHEN d.last_seen_at > NOW() - INTERVAL '7 days' THEN 1 END) as devices_seen_7d,
    COUNT(CASE WHEN d.battery_level IS NOT NULL THEN 1 END) as battery_powered_devices,
    ROUND(AVG(CASE WHEN d.battery_level IS NOT NULL THEN d.battery_level END), 2) as avg_battery_level,
    COUNT(CASE WHEN d.battery_level < 20 THEN 1 END) as low_battery_devices,
    COUNT(CASE WHEN d.enabled_class = 'A' THEN 1 END) as class_a_devices,
    COUNT(CASE WHEN d.enabled_class = 'B' THEN 1 END) as class_b_devices,
    COUNT(CASE WHEN d.enabled_class = 'C' THEN 1 END) as class_c_devices,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as report_timestamp
FROM tenant t
LEFT JOIN application a ON t.id = a.tenant_id
LEFT JOIN device d ON a.id = d.application_id
GROUP BY t.name, t.id
ORDER BY t.name
"

export_table "gateway_summary" "
SELECT
    t.name as tenant_name,
    t.id::text as tenant_id,
    COUNT(g.gateway_id) as total_gateways,
    COUNT(CASE WHEN g.last_seen_at > NOW() - INTERVAL '5 minutes' THEN 1 END) as online_gateways,
    COUNT(CASE WHEN g.last_seen_at BETWEEN NOW() - INTERVAL '1 hour' AND NOW() - INTERVAL '5 minutes' THEN 1 END) as recent_gateways,
    COUNT(CASE WHEN g.last_seen_at <= NOW() - INTERVAL '1 hour' OR g.last_seen_at IS NULL THEN 1 END) as offline_gateways,
    MAX(g.last_seen_at) as last_gateway_activity,
    MIN(g.last_seen_at) as oldest_gateway_activity,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as report_timestamp
FROM tenant t
LEFT JOIN gateway g ON t.id = g.tenant_id
GROUP BY t.name, t.id
ORDER BY t.name
"

export_table "users" "
SELECT
    u.id::text as user_id,
    u.email,
    u.is_admin,
    u.is_active,
    u.email_verified,
    u.external_id,
    u.note,
    u.created_at,
    u.updated_at,
    STRING_AGG(t.name, ', ') as tenant_access,
    COUNT(t.id) as tenant_count,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM \"user\" u
LEFT JOIN tenant_user tu ON u.id = tu.user_id
LEFT JOIN tenant t ON tu.tenant_id = t.id
GROUP BY u.id, u.email, u.is_admin, u.is_active, u.email_verified, u.external_id, u.note, u.created_at, u.updated_at
ORDER BY u.email
"

export_table "tenant_user_roles" "
SELECT
    t.name as tenant_name,
    t.id::text as tenant_id,
    u.email as user_email,
    u.id::text as user_id,
    tu.is_admin as is_tenant_admin,
    tu.is_device_admin,
    tu.is_gateway_admin,
    tu.created_at,
    tu.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM tenant_user tu
LEFT JOIN tenant t ON tu.tenant_id = t.id
LEFT JOIN \"user\" u ON tu.user_id = u.id
ORDER BY t.name, u.email
"

export_table "integrations" "
SELECT
    a.id::text || '_' || ai.kind as integration_id,
    a.name as application_name,
    a.id::text as application_id,
    t.name as tenant_name,
    ai.kind as integration_type,
    ai.configuration::text as configuration_json,
    ai.created_at,
    ai.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM application_integration ai
LEFT JOIN application a ON ai.application_id = a.id
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY a.name, ai.kind
"

# 18. Multicast Groups (FIXED)
export_table "multicast_groups" "
SELECT
    mg.id::text as multicast_group_id,
    mg.name as group_name,
    mg.application_id::text,
    a.name as application_name,
    t.name as tenant_name,
    mg.region,
    encode(mg.mc_addr, 'hex') as multicast_address,
    encode(mg.mc_nwk_s_key, 'hex') as network_session_key,
    encode(mg.mc_app_s_key, 'hex') as application_session_key,
    mg.f_cnt as frame_counter,
    mg.group_type,
    mg.dr as data_rate,
    mg.frequency,
    mg.class_c_scheduling_type,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM multicast_group mg
LEFT JOIN application a ON mg.application_id = a.id
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY mg.name
"

export_table "multicast_group_devices" "
SELECT
    mg.name as multicast_group_name,
    mg.id::text as multicast_group_id,
    encode(mgd.dev_eui, 'hex') as device_eui,
    d.name as device_name,
    a.name as application_name,
    t.name as tenant_name,
    mgd.created_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM multicast_group_device mgd
LEFT JOIN multicast_group mg ON mgd.multicast_group_id = mg.id
LEFT JOIN device d ON mgd.dev_eui = d.dev_eui
LEFT JOIN application a ON mg.application_id = a.id
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY mg.name, d.name
"

export_table "device_queue" "
SELECT
    dq.id::text as queue_item_id,
    encode(dq.dev_eui, 'hex') as device_eui,
    d.name as device_name,
    dq.f_port as frame_port,
    dq.confirmed,
    dq.is_pending,
    dq.is_encrypted,
    dq.f_cnt_down as frame_counter_down,
    dq.timeout_after,
    dq.expires_at,
    dq.created_at,
    a.name as application_name,
    t.name as tenant_name,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM device_queue_item dq
LEFT JOIN device d ON dq.dev_eui = d.dev_eui
LEFT JOIN application a ON d.application_id = a.id
LEFT JOIN tenant t ON a.tenant_id = t.id
WHERE dq.is_pending = true
ORDER BY dq.created_at DESC
"

export_table "api_keys" "
SELECT
    ak.id::text as api_key_id,
    ak.name as api_key_name,
    ak.is_admin,
    t.name as tenant_name,
    ak.tenant_id::text,
    ak.created_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM api_key ak
LEFT JOIN tenant t ON ak.tenant_id = t.id
ORDER BY ak.name
"

export_table "relay_devices" "
SELECT
    encode(rd.relay_dev_eui, 'hex') as relay_device_eui,
    dr.name as relay_device_name,
    encode(rd.dev_eui, 'hex') as device_eui,
    d.name as device_name,
    rd.created_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM relay_device rd
LEFT JOIN device dr ON rd.relay_dev_eui = dr.dev_eui
LEFT JOIN device d ON rd.dev_eui = d.dev_eui
ORDER BY dr.name, d.name
"

export_table "relay_gateways" "
SELECT
    encode(rg.relay_id, 'hex') as relay_gateway_id,
    rg.name as relay_gateway_name,
    rg.description,
    t.name as tenant_name,
    rg.tenant_id::text,
    rg.region_config_id,
    rg.stats_interval_secs,
    rg.last_seen_at,
    rg.created_at,
    rg.updated_at,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp,
    CASE
        WHEN rg.last_seen_at > NOW() - INTERVAL '5 minutes' THEN 'Online'
        WHEN rg.last_seen_at > NOW() - INTERVAL '1 hour' THEN 'Recent'
        WHEN rg.last_seen_at IS NULL THEN 'Never Seen'
        ELSE 'Offline'
    END as connection_status
FROM relay_gateway rg
LEFT JOIN tenant t ON rg.tenant_id = t.id
ORDER BY rg.name
"

FUOTA_EXISTS=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'fuota_deployment'
);
" | tr -d '[:space:]')

if [ "$FUOTA_EXISTS" = "t" ]; then
    export_table "fuota_deployments" "
    SELECT
        fd.id::text as deployment_id,
        fd.name as deployment_name,
        a.name as application_name,
        fd.application_id::text,
        dp.name as device_profile_name,
        fd.device_profile_id::text,
        t.name as tenant_name,
        encode(fd.multicast_addr, 'hex') as multicast_address,
        fd.multicast_group_type,
        fd.multicast_class_c_scheduling_type,
        fd.multicast_dr as data_rate,
        fd.multicast_frequency,
        fd.multicast_timeout,
        fd.fragmentation_fragment_size,
        fd.fragmentation_redundancy_percentage,
        fd.request_fragmentation_session_status,
        fd.created_at,
        fd.updated_at,
        fd.started_at,
        fd.completed_at,
        CASE
            WHEN fd.completed_at IS NOT NULL THEN 'Completed'
            WHEN fd.started_at IS NOT NULL THEN 'In Progress'
            ELSE 'Pending'
        END as deployment_status,
        '${SERVER_NAME}' as source_server,
        '${TIMESTAMP}' as export_timestamp
    FROM fuota_deployment fd
    LEFT JOIN application a ON fd.application_id = a.id
    LEFT JOIN device_profile dp ON fd.device_profile_id = dp.id
    LEFT JOIN tenant t ON a.tenant_id = t.id
    ORDER BY fd.created_at DESC
    "
else
    echo -e "${YELLOW}ℹ️  Skipping FUOTA deployments (not supported in this version)${NC}"
    log_message "INFO: fuota_deployment table does not exist"
    cat > "$EXPORT_DIR/fuota_deployments.csv" << 'EOF'
deployment_id,deployment_name,application_name,application_id,device_profile_name,device_profile_id,tenant_name,multicast_address,multicast_group_type,multicast_class_c_scheduling_type,data_rate,multicast_frequency,multicast_timeout,fragmentation_fragment_size,fragmentation_redundancy_percentage,request_fragmentation_session_status,created_at,updated_at,started_at,completed_at,deployment_status,source_server,export_timestamp
EOF
fi

log_message "=== All Exports Completed ==="
echo ""

# ============================================================================
# CONVERT TO JSON
# ============================================================================
echo -e "${MAGENTA}Converting to JSON...${NC}"
for csv_file in "$EXPORT_DIR"/*.csv; do
    if [ -f "$csv_file" ]; then
        filename=$(basename "$csv_file" .csv)
        json_file="$JSON_DIR/${filename}.json"
        
        python3 << PYEOF
import csv
import json
with open('$csv_file', 'r') as f:
    reader = csv.DictReader(f)
    rows = list(reader)
with open('$json_file', 'w') as f:
    json.dump(rows, f, indent=2)
PYEOF
    fi
done
log_message "Converted all CSVs to JSON"
echo -e "${GREEN}✓ JSON conversion complete${NC}"
echo ""

# ============================================================================
# COPY TO CURRENT (LATEST) DIRECTORY
# ============================================================================
echo -e "${MAGENTA}Updating current data...${NC}"

# Copy CSVs to current directory (for backup/reference)
rsync -a --delete "$EXPORT_DIR"/*.csv "$CURRENT_DIR/" 2>/dev/null

# Copy JSON files to current/json (API serves from here)
rsync -a --delete "$JSON_DIR/" "$CURRENT_JSON_DIR/" 2>/dev/null

# Copy codec scripts to current/codecs
if [ -d "$CODEC_DIR" ] && [ "$(ls -A $CODEC_DIR 2>/dev/null)" ]; then
    rsync -a --delete "$CODEC_DIR/" "$CURRENT_CODEC_DIR/" 2>/dev/null
fi

# Create metadata file for current export
cat > "$CURRENT_DIR/metadata.json" << METAEOF
{
  "server_name": "$SERVER_NAME",
  "server_url": "$SERVER_URL",
  "export_timestamp": "$TIMESTAMP",
  "export_date": "$(date -Iseconds)",
  "archive_path": "$EXPORT_DIR",
  "api_port": $API_PORT
}
METAEOF

log_message "Updated current directory with latest data"
echo -e "${GREEN}✓ Current data updated${NC}"
echo ""

# ============================================================================
# CLEANUP OLD ARCHIVES
# ============================================================================
echo -e "${MAGENTA}Cleaning up old archives...${NC}"
ARCHIVE_COUNT=$(ls -1d "$ARCHIVE_DIR"/export_* 2>/dev/null | wc -l)

if [ "$ARCHIVE_COUNT" -gt "$KEEP_ARCHIVES" ]; then
    TO_DELETE=$((ARCHIVE_COUNT - KEEP_ARCHIVES))
    ls -1dt "$ARCHIVE_DIR"/export_* | tail -n $TO_DELETE | while read old_export; do
        echo "  Removing: $(basename $old_export)"
        rm -rf "$old_export"
        log_message "Deleted old archive: $(basename $old_export)"
    done
    echo -e "${GREEN}✓ Cleaned up $TO_DELETE old archives (keeping last $KEEP_ARCHIVES)${NC}"
else
    echo "  Keeping all $ARCHIVE_COUNT archives (limit: $KEEP_ARCHIVES)"
fi
echo ""

# ============================================================================
# CREATE/UPDATE API SERVER
# ============================================================================
API_DIR="$BASE_DIR/api_server"
mkdir -p "$API_DIR"

if [ ! -f "$API_DIR/package.json" ]; then
    echo -e "${MAGENTA}Creating API server...${NC}"
    
    cat > "$API_DIR/package.json" << 'PKGEOF'
{
  "name": "chirpstack-export-api",
  "version": "3.0.0",
  "description": "ChirpStack Smart Export API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5"
  }
}
PKGEOF

    cat > "$API_DIR/server.js" << 'SRVEOF'
const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.API_PORT || 8750;
const API_TOKEN = process.env.API_TOKEN || '';
const CURRENT_JSON_DIR = process.env.CURRENT_JSON_DIR || '../current/json';
const CURRENT_CODEC_DIR = process.env.CURRENT_CODEC_DIR || '../current/codecs';
const CURRENT_DIR = process.env.CURRENT_DIR || '../current';

// Security
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100
});
app.use(limiter);

// Auth middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }
    
    if (token !== API_TOKEN) {
        return res.status(403).json({ error: 'Invalid token' });
    }
    
    next();
};

// Helper to read metadata
function getMetadata() {
    try {
        const metaPath = path.join(CURRENT_DIR, 'metadata.json');
        if (fs.existsSync(metaPath)) {
            return JSON.parse(fs.readFileSync(metaPath, 'utf8'));
        }
    } catch (error) {
        console.error('Error reading metadata:', error);
    }
    return null;
}

// Health check
app.get('/health', (req, res) => {
    const metadata = getMetadata();
    res.json({ 
        status: 'ok',
        timestamp: new Date().toISOString(),
        last_export: metadata?.export_date || 'unknown',
        server: metadata?.server_name || 'ChirpStack Export API'
    });
});

// Get metadata
app.get('/api/metadata', authenticateToken, (req, res) => {
    const metadata = getMetadata();
    if (metadata) {
        res.json(metadata);
    } else {
        res.status(404).json({ error: 'Metadata not found' });
    }
});

// List available exports
app.get('/api/exports', authenticateToken, (req, res) => {
    try {
        const files = fs.readdirSync(CURRENT_JSON_DIR)
            .filter(f => f.endsWith('.json'))
            .map(f => ({
                name: f.replace('.json', ''),
                filename: f,
                size: fs.statSync(path.join(CURRENT_JSON_DIR, f)).size,
                modified: fs.statSync(path.join(CURRENT_JSON_DIR, f)).mtime
            }));
        
        const metadata = getMetadata();
        res.json({ 
            exports: files,
            total: files.length,
            last_export: metadata?.export_date || null
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to list exports', message: error.message });
    }
});

// Get specific export
app.get('/api/exports/:name', authenticateToken, (req, res) => {
    try {
        const filename = req.params.name.endsWith('.json') 
            ? req.params.name 
            : `${req.params.name}.json`;
        
        const filePath = path.join(CURRENT_JSON_DIR, filename);
        
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'Export not found' });
        }
        
        const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        
        res.json({
            name: req.params.name,
            count: data.length,
            data: data
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to read export', message: error.message });
    }
});

// Get paginated export
app.get('/api/exports/:name/paginated', authenticateToken, (req, res) => {
    try {
        const filename = req.params.name.endsWith('.json') 
            ? req.params.name 
            : `${req.params.name}.json`;
        
        const filePath = path.join(CURRENT_JSON_DIR, filename);
        
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'Export not found' });
        }
        
        const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 100;
        const startIndex = (page - 1) * limit;
        const endIndex = page * limit;
        
        const results = {
            name: req.params.name,
            total: data.length,
            page: page,
            limit: limit,
            totalPages: Math.ceil(data.length / limit),
            data: data.slice(startIndex, endIndex)
        };
        
        if (endIndex < data.length) {
            results.nextPage = page + 1;
        }
        
        if (startIndex > 0) {
            results.previousPage = page - 1;
        }
        
        res.json(results);
    } catch (error) {
        res.status(500).json({ error: 'Failed to read export', message: error.message });
    }
});

// List codecs
app.get('/api/codecs', authenticateToken, (req, res) => {
    try {
        if (!fs.existsSync(CURRENT_CODEC_DIR)) {
            return res.json({ codecs: [], total: 0 });
        }
        
        const files = fs.readdirSync(CURRENT_CODEC_DIR)
            .filter(f => f.endsWith('.js'))
            .map(f => ({
                name: f.replace('.js', ''),
                filename: f,
                size: fs.statSync(path.join(CURRENT_CODEC_DIR, f)).size,
                modified: fs.statSync(path.join(CURRENT_CODEC_DIR, f)).mtime
            }));
        
        res.json({ 
            codecs: files,
            total: files.length
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to list codecs', message: error.message });
    }
});

// Get codec script
app.get('/api/codecs/:name', authenticateToken, (req, res) => {
    try {
        const filename = req.params.name.endsWith('.js') 
            ? req.params.name 
            : `${req.params.name}.js`;
        
        const filePath = path.join(CURRENT_CODEC_DIR, filename);
        
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'Codec not found' });
        }
        
        const script = fs.readFileSync(filePath, 'utf8');
        
        res.json({
            name: req.params.name,
            filename: filename,
            script: script
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to read codec', message: error.message });
    }
});

// Search devices
app.get('/api/search/devices', authenticateToken, (req, res) => {
    try {
        const devicesFile = path.join(CURRENT_JSON_DIR, 'devices.json');
        if (!fs.existsSync(devicesFile)) {
            return res.status(404).json({ error: 'Devices export not found' });
        }
        
        const devices = JSON.parse(fs.readFileSync(devicesFile, 'utf8'));
        const query = req.query.q ? req.query.q.toLowerCase() : '';
        
        const filtered = devices.filter(d => 
            d.device_name?.toLowerCase().includes(query) ||
            d.device_eui?.toLowerCase().includes(query) ||
            d.application_name?.toLowerCase().includes(query)
        );
        
        res.json({
            query: query,
            count: filtered.length,
            data: filtered.slice(0, 100)
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to search devices', message: error.message });
    }
});

// Get statistics
app.get('/api/stats', authenticateToken, (req, res) => {
    try {
        const metadata = getMetadata();
        const deviceSummaryFile = path.join(CURRENT_JSON_DIR, 'device_summary.json');
        const gatewaySummaryFile = path.join(CURRENT_JSON_DIR, 'gateway_summary.json');
        
        const stats = {
            server_name: metadata?.server_name || 'Unknown',
            last_export: metadata?.export_date || null,
            exports_available: fs.readdirSync(CURRENT_JSON_DIR).filter(f => f.endsWith('.json')).length,
            codecs_available: fs.existsSync(CURRENT_CODEC_DIR) ? fs.readdirSync(CURRENT_CODEC_DIR).filter(f => f.endsWith('.js')).length : 0
        };
        
        if (fs.existsSync(deviceSummaryFile)) {
            stats.device_summary = JSON.parse(fs.readFileSync(deviceSummaryFile, 'utf8'));
        }
        
        if (fs.existsSync(gatewaySummaryFile)) {
            stats.gateway_summary = JSON.parse(fs.readFileSync(gatewaySummaryFile, 'utf8'));
        }
        
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Failed to get stats', message: error.message });
    }
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Internal server error', message: err.message });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    const metadata = getMetadata();
    console.log(`✓ ChirpStack Export API running on port ${PORT}`);
    console.log(`  Server: ${metadata?.server_name || 'Unknown'}`);
    console.log(`  Last Export: ${metadata?.export_date || 'Unknown'}`);
    console.log(`  JSON: ${CURRENT_JSON_DIR}`);
    console.log(`  Codecs: ${CURRENT_CODEC_DIR}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});
SRVEOF

    # Install dependencies
    cd "$API_DIR"
    npm install --silent >/dev/null 2>&1
    cd - > /dev/null
    
    log_message "API server created"
    echo -e "${GREEN}✓ API server created${NC}"
fi

# ============================================================================
# START/RESTART API SERVER
# ============================================================================
echo -e "${MAGENTA}Managing API server...${NC}"  # ADD THIS LINE

touch "$BASE_DIR/.api_pid" 2>/dev/null || true
touch "$BASE_DIR/api_server.log" 2>/dev/null || true
mkdir -p "$API_DIR" 2>/dev/null || true

# Kill any existing server
API_PID_FILE="$BASE_DIR/.api_pid"
if [ -f "$API_PID_FILE" ] && [ -s "$API_PID_FILE" ]; then
    OLD_PID=$(cat "$API_PID_FILE")
    if kill -0 $OLD_PID 2>/dev/null; then
        echo "  Stopping old API server (PID: $OLD_PID)"
        kill $OLD_PID 2>/dev/null
        sleep 2
    fi
fi

# Also kill by port
lsof -ti:$API_PORT | xargs kill -9 2>/dev/null || true
sleep 1

# Start API server
export API_PORT=$API_PORT
export API_TOKEN=$API_TOKEN
export CURRENT_JSON_DIR=$(realpath "$CURRENT_JSON_DIR")
export CURRENT_CODEC_DIR=$(realpath "$CURRENT_CODEC_DIR")
export CURRENT_DIR=$(realpath "$CURRENT_DIR")

# Ensure files exist before redirect
API_PID_FILE="$BASE_DIR/.api_pid"
API_LOG_FILE="$BASE_DIR/api_server.log"
touch "$API_PID_FILE" "$API_LOG_FILE"

cd "$API_DIR"
nohup node server.js > "$API_LOG_FILE" 2>&1 &
NEW_PID=$!
echo $NEW_PID > "$API_PID_FILE"
cd - > /dev/null


sleep 2

if kill -0 $NEW_PID 2>/dev/null; then
    log_message "API server started (PID: $NEW_PID)"
    echo -e "${GREEN}✓ API server started (PID: $NEW_PID)${NC}"
else
    log_message "ERROR: Failed to start API server"
    echo -e "${RED}✗ Failed to start API server${NC}"
    [ -f "$BASE_DIR/api_server.log" ] && tail -20 "$BASE_DIR/api_server.log"

fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo "=========================================="
echo -e "${GREEN}Export Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}Archive:${NC} $EXPORT_DIR"
echo -e "${BLUE}Current:${NC} $CURRENT_DIR"

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "Unable to detect")
INTERNAL_IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}API (Internal):${NC} http://$INTERNAL_IP:$API_PORT"
echo -e "${BLUE}API (Public):${NC} http://$PUBLIC_IP:$API_PORT"
echo -e "${BLUE}Token:${NC} $API_TOKEN"
echo ""


# Count records
TOTAL_RECORDS=0
for file in "$EXPORT_DIR"/*.csv; do
    [ -f "$file" ] || continue
    RECORDS=$(tail -n +2 "$file" | wc -l)
    TOTAL_RECORDS=$((TOTAL_RECORDS + RECORDS))
done

echo -e "${GREEN}✓ Exported $TOTAL_RECORDS records${NC}"
echo -e "${GREEN}✓ Keeping last $KEEP_ARCHIVES archives${NC}"
echo -e "${GREEN}✓ API serving latest data${NC}"
echo ""

log_message "=== Export Completed Successfully ==="
echo -e "${YELLOW}Test API (Internal):${NC} curl http://$INTERNAL_IP:$API_PORT/health"
echo -e "${YELLOW}Test API (Public):${NC} curl http://$PUBLIC_IP:$API_PORT/health"
echo ""
