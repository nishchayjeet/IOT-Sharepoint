#!/bin/bash

# ============================================================================
# IoTKinect LoRaWAN Management Portal - ChirpStack Export Script
# ============================================================================
# This script exports data from ChirpStack PostgreSQL database to CSV files
# and prepares them for SharePoint import
#
# Version: 2.2 - FIXED: Exports codecs as separate .js files
# Author: IoTKinect Team
# Date: 2025-11-25
# ============================================================================

# Configuration
CONTAINER_NAME="chirpstack-docker_postgres_1"
DB_USER="chirpstack"
DB_NAME="chirpstack"
EXPORT_DIR="./chirpstack_exports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SERVER_NAME="LNS-IoTKinect"  # Change this for each ChirpStack server
SERVER_URL="https://lns.ca.iotkinect.io"  # Your ChirpStack URL

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create export directory
mkdir -p "$EXPORT_DIR"

# Log file
LOG_FILE="$EXPORT_DIR/export_log_${TIMESTAMP}.txt"

echo "=========================================="
echo "IoTKinect ChirpStack Export Tool v2.2"
echo "=========================================="
echo "Server Name: $SERVER_NAME"
echo "Server URL: $SERVER_URL"
echo "Export directory: $EXPORT_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "All operations will be logged to: $LOG_FILE"
echo ""

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to export data
export_table() {
    local filename=$1
    local query=$2
    local output_file="$EXPORT_DIR/${filename}_${TIMESTAMP}.csv"

    echo -e "${BLUE}Exporting: $filename...${NC}"
    log_message "Starting export: $filename"

    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "COPY ($query) TO STDOUT WITH CSV HEADER" > "$output_file"

    if [ $? -eq 0 ]; then
        local record_count=$(tail -n +2 "$output_file" | wc -l)
        echo -e "${GREEN}✓ Successfully exported to: $output_file${NC}"
        echo "  Records: $record_count"
        log_message "SUCCESS: $filename exported with $record_count records"
    else
        echo -e "${RED}✗ Failed to export $filename${NC}"
        log_message "ERROR: Failed to export $filename"
    fi
    echo ""
}

# Check if Docker container is running
echo "Checking Docker container..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: Docker container $CONTAINER_NAME is not running${NC}"
    log_message "ERROR: Docker container not running"
    exit 1
fi
echo -e "${GREEN}✓ Docker container is running${NC}"
echo ""

# ============================================================================
# 1. CHIRPSTACK SERVERS REGISTRY
# ============================================================================
cat > "$EXPORT_DIR/chirpstack_servers_${TIMESTAMP}.csv" << EOF
server_id,server_name,server_url,environment,sync_timestamp,status,notes
$(uuidgen),${SERVER_NAME},${SERVER_URL},Production,$(date -Iseconds),Active,Automated export from script
EOF
log_message "Created ChirpStack servers registry"
echo -e "${GREEN}✓ ChirpStack servers registry created${NC}"
echo ""

# ============================================================================
# 2. EXPORT TENANTS
# ============================================================================
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

# ============================================================================
# 3. EXPORT APPLICATIONS
# ============================================================================
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

# ============================================================================
# 4. EXPORT DEVICE PROFILES
# ============================================================================
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

# ============================================================================
# 5. EXPORT DEVICES WITH KEYS (MOST CRITICAL)
# ============================================================================
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
    d.f_cnt_up as frame_counter_up,
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

# ============================================================================
# 6. EXPORT GATEWAYS
# ============================================================================
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

# ============================================================================
# 7. EXPORT DEVICE CLASSES (REFERENCE DATA)
# ============================================================================
cat > "$EXPORT_DIR/device_classes_${TIMESTAMP}.csv" << 'EOF'
class_name,description,power_consumption,downlink_capability,typical_latency,use_cases,max_devices_recommended
Class A,Bi-directional end-devices with scheduled uplink,Lowest (months-years battery),After uplink only,Depends on uplink schedule,"Battery-powered sensors, periodic monitoring, environmental sensors",Unlimited
Class B,Bi-directional with scheduled receive slots,Medium (weeks-months battery),Scheduled ping slots,Predictable (configurable),"Actuators, street lighting, smart metering, parking sensors",10000+
Class C,Bi-directional with continuous receive windows,Highest (mains-powered),Nearly continuous,Very low (<1 second),"Mains-powered devices, critical actuators, emergency systems, alarms",1000+
EOF
log_message "Created device classes reference"
echo -e "${GREEN}✓ Device classes reference created${NC}"
echo ""

# ============================================================================
# 8. EXPORT PAYLOAD CODECS AS SEPARATE .JS FILES (FIXED v2.3)
# ============================================================================
echo -e "${BLUE}Exporting payload codecs...${NC}"

# Create codecs subdirectory
CODEC_DIR="$EXPORT_DIR/codec_scripts_${TIMESTAMP}"
mkdir -p "$CODEC_DIR"

# Get count of profiles with codecs
CODEC_COUNT=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(DISTINCT dp.id)
FROM device_profile dp
WHERE dp.payload_codec_script IS NOT NULL
  AND dp.payload_codec_script != ''
  AND LENGTH(TRIM(dp.payload_codec_script)) > 0
  AND EXISTS (SELECT 1 FROM device d WHERE d.device_profile_id = dp.id);
" | tr -d ' ')

echo "  Profiles with devices and codecs: $CODEC_COUNT"
log_message "Found $CODEC_COUNT device profiles with codecs"

# Export each codec to its own .js file
if [ "$CODEC_COUNT" -gt 0 ]; then
    # Get list of profile IDs (just IDs, no names to avoid delimiter issues)
    PROFILE_IDS=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT dp.id::text
    FROM device_profile dp
    WHERE dp.payload_codec_script IS NOT NULL
      AND dp.payload_codec_script != ''
      AND LENGTH(TRIM(dp.payload_codec_script)) > 0
      AND EXISTS (SELECT 1 FROM device d WHERE d.device_profile_id = dp.id)
    ORDER BY dp.name;
    ")
    
    # Counter for exported files
    EXPORTED_COUNT=0
    
    # Process each profile ID
    for profile_id in $PROFILE_IDS; do
        # Skip empty lines
        [ -z "$profile_id" ] && continue
        
        # Get the profile name separately (to avoid delimiter issues)
        profile_name=$(docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT name FROM device_profile WHERE id = '$profile_id'::uuid;
        " | tr -d '\r')
        
        # Sanitize filename (remove spaces and special chars, limit length)
        safe_filename=$(echo "$profile_name" | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-50)
        codec_file="${CODEC_DIR}/${safe_filename}_${profile_id}.js"
        
        # Export the codec script directly to file
        docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT payload_codec_script
        FROM device_profile
        WHERE id = '$profile_id'::uuid;
        " > "$codec_file"
        
        # Check if file was created successfully and has content
        if [ -f "$codec_file" ] && [ -s "$codec_file" ]; then
            file_size=$(ls -lh "$codec_file" | awk '{print $5}')
            echo "  ✓ Exported: $profile_name → ${safe_filename}_${profile_id}.js ($file_size)"
            log_message "Exported codec: $profile_name to ${safe_filename}_${profile_id}.js ($file_size)"
            EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
        else
            echo "  ✗ Failed: $profile_name (ID: $profile_id)"
            log_message "ERROR: Failed to export codec for $profile_name (ID: $profile_id)"
        fi
    done
    
    echo -e "${GREEN}✓ Codec scripts exported to: $CODEC_DIR${NC}"
    echo "  Files created: $EXPORTED_COUNT / $CODEC_COUNT"
    
    if [ "$EXPORTED_COUNT" -ne "$CODEC_COUNT" ]; then
        echo -e "${YELLOW}  ⚠️  Warning: Expected $CODEC_COUNT files, but only exported $EXPORTED_COUNT${NC}"
        log_message "WARNING: Expected $CODEC_COUNT codec files, but only exported $EXPORTED_COUNT"
    else
        log_message "SUCCESS: Exported all $EXPORTED_COUNT codec scripts to individual .js files in $CODEC_DIR"
    fi
else
    echo -e "${YELLOW}  No codec scripts to export${NC}"
    log_message "No codec scripts found for export"
fi
echo ""

# Now export codec metadata WITHOUT the script content
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

# ============================================================================
# 9. EXPORT DEVICE STATISTICS SUMMARY
# ============================================================================
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

# ============================================================================
# 10. EXPORT GATEWAY STATISTICS SUMMARY
# ============================================================================
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

# ============================================================================
# 11. EXPORT USER INFORMATION
# ============================================================================
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

# ============================================================================
# 12. EXPORT TENANT USER ROLES
# ============================================================================
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

# ============================================================================
# 13. EXPORT APPLICATION INTEGRATIONS
# ============================================================================
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

# ============================================================================
# 14. EXPORT MULTICAST GROUPS
# ============================================================================
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
    mg.class_b_ping_slot_periodicity,
    mg.class_c_scheduling_type,
    '${SERVER_NAME}' as source_server,
    '${TIMESTAMP}' as export_timestamp
FROM multicast_group mg
LEFT JOIN application a ON mg.application_id = a.id
LEFT JOIN tenant t ON a.tenant_id = t.id
ORDER BY mg.name
"

# ============================================================================
# 15. EXPORT MULTICAST GROUP DEVICES
# ============================================================================
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

# ============================================================================
# 16. EXPORT DEVICE QUEUE (Downlink Queue Status)
# ============================================================================
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

# ============================================================================
# 17. EXPORT API KEYS
# ============================================================================
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

# ============================================================================
# 18. EXPORT DEVICE PROFILE TEMPLATES (OPTIONAL - SKIPPED)
# ============================================================================
echo -e "${YELLOW}ℹ️  Skipping device profile templates (14,085 records - use ChirpStack UI)${NC}"
log_message "INFO: Skipped device_profile_templates export (not needed for daily ops)"
echo ""

# ============================================================================
# 19. EXPORT RELAY DEVICES (if any)
# ============================================================================
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

# ============================================================================
# 20. EXPORT RELAY GATEWAYS (if any)
# ============================================================================
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

# ============================================================================
# 21. EXPORT FUOTA DEPLOYMENTS (Firmware Updates)
# ============================================================================
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

# ============================================================================
# 22. GENERATE IMPORT MANIFEST
# ============================================================================
cat > "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt" << EOF
========================================
IoTKinect ChirpStack Export Manifest
========================================

Export Information:
------------------
Server Name: ${SERVER_NAME}
Server URL: ${SERVER_URL}
Export Date: $(date)
Export Timestamp: ${TIMESTAMP}

Files Generated:
---------------
EOF

# ============================================================================
# 23. CONVERT CSV TO JSON FOR API UPLOAD
# ============================================================================
echo -e "${BLUE}Converting CSVs to JSON for API upload...${NC}"

JSON_DIR="$EXPORT_DIR/json_${TIMESTAMP}"
mkdir -p "$JSON_DIR"

# Install jq if not available (for JSON processing)
if ! command -v jq &> /dev/null; then
    echo "  Installing jq..."
    apt-get update && apt-get install -y jq
fi

# Convert each CSV to JSON array
for csv_file in "$EXPORT_DIR"/*${TIMESTAMP}.csv; do
    if [ -f "$csv_file" ]; then
        filename=$(basename "$csv_file" .csv)
        json_file="$JSON_DIR/${filename}.json"
        
        # Convert CSV to JSON using Python
        python3 << EOF
import csv
import json

with open('$csv_file', 'r') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

with open('$json_file', 'w') as f:
    json.dump(rows, f, indent=2)

print(f"  ✓ Converted: ${filename}.json")
EOF
    fi
done

echo -e "${GREEN}✓ JSON files created in: $JSON_DIR${NC}"
echo ""
# ============================================================================

# List all generated CSV files
for file in "$EXPORT_DIR"/*${TIMESTAMP}.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        filesize=$(ls -lh "$file" | awk '{print $5}')
        linecount=$(wc -l < "$file")
        echo "  - $filename ($filesize, $linecount lines)" >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt"
    fi
done

# List codec files if they exist
if [ -d "$CODEC_DIR" ] && [ "$(ls -A $CODEC_DIR 2>/dev/null)" ]; then
    echo "" >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt"
    echo "Codec Scripts:" >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt"
    echo "---------------" >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt"
    for file in "$CODEC_DIR"/*.js; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            filesize=$(ls -lh "$file" | awk '{print $5}')
            echo "  - $filename ($filesize)" >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt"
        fi
    done
fi

cat >> "$EXPORT_DIR/IMPORT_MANIFEST_${TIMESTAMP}.txt" << EOF

Import Order (Recommended):
--------------------------
1.  chirpstack_servers_*.csv           → ChirpStack Servers list
2.  tenants_*.csv                      → Tenants list
3.  device_classes_*.csv               → Device Classes (reference)
4.  applications_*.csv                 → Applications list
5.  device_profiles_*.csv              → Device Profiles list
6.  payload_codecs_metadata_*.csv      → Payload Codecs Metadata
    + Upload codec_scripts_*/*.js      → To SharePoint Document Library
7.  gateways_*.csv                     → Gateways list
8.  devices_*.csv                      → Devices list (CRITICAL - contains keys)
9.  users_*.csv                        → User Accounts
10. tenant_user_roles_*.csv            → User Tenant Permissions
11. api_keys_*.csv                     → API Keys
12. integrations_*.csv                 → Integration Configurations
13. device_summary_*.csv               → Device Statistics Dashboard
14. gateway_summary_*.csv              → Gateway Statistics Dashboard

Optional (if you use these features):
15. relay_gateways_*.csv               → Relay Gateways
Optional (if you use these features):
15. relay_gateways_*.csv               → Relay Gateways
16. relay_devices_*.csv                → Relay Device Relationships
17. multicast_groups_*.csv             → Multicast Groups
18. multicast_group_devices_*.csv      → Multicast Group Memberships
19. device_queue_*.csv                 → Device Queue Status
20. fuota_deployments_*.csv            → FUOTA Deployments

Skipped Exports:
---------------
❌ device_profile_templates (14,085 records - too large, use ChirpStack UI)

Notes:
------
- Files with relationships should be imported in order
- Ensure lookup columns are created before importing related data
- Device keys are exported in hexadecimal format
- Timestamps are in ISO 8601 format
- All IDs are UUIDs converted to text
- Sensitive data (keys, passwords) should be handled securely

Security Notes:
--------------
⚠️  CRITICAL: The following files contain sensitive information:
    • devices_*.csv - Contains App Keys and Network Keys
    • multicast_groups_*.csv - Contains session keys
    • integrations_*.csv - May contain API credentials

    Handle these files with appropriate security measures!

Next Steps:
----------
1. Review all CSV files for accuracy
2. Create SharePoint lists as per site structure document
3. Import files in the recommended order
4. Configure lookup columns after import
5. Set up views and permissions
6. Schedule this script to run periodically (e.g., daily)
7. Archive old exports securely

========================================
EOF

echo "=========================================="
echo -e "${GREEN}Export Complete!${NC}"
echo "=========================================="
echo ""
echo "Server: $SERVER_NAME"
echo "Export directory: $EXPORT_DIR"
echo ""
echo "Files created:"
ls -lh "$EXPORT_DIR"/*${TIMESTAMP}.*
echo ""
echo -e "${YELLOW}⚠️  SECURITY WARNING:${NC}"
echo "  • Devices CSV contains sensitive encryption keys"
echo "  • Multicast groups CSV contains session keys"
echo "  • Integration CSV may contain API credentials"
echo "  • Handle these files securely and delete after import"
echo ""
echo -e "${BLUE}Summary:${NC}"
# Count total records
TOTAL_RECORDS=0
for file in "$EXPORT_DIR"/*${TIMESTAMP}.csv; do
    RECORDS=$(tail -n +2 "$file" | wc -l)
    TOTAL_RECORDS=$((TOTAL_RECORDS + RECORDS))
done
echo "  • Total CSV files: $(ls "$EXPORT_DIR"/*${TIMESTAMP}.csv 2>/dev/null | wc -l)"
echo "  • Total records exported: $TOTAL_RECORDS"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  • Review IMPORT_MANIFEST_${TIMESTAMP}.txt for detailed instructions"
echo "  • Import files in the recommended order to maintain relationships"
echo "  • Set up item-level security in SharePoint for sensitive columns"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review CSV files for accuracy"
echo "  2. Follow SharePoint site structure guide"
echo "  3. Import into SharePoint following the manifest order"
echo "  4. Configure security permissions for sensitive data"
echo "  5. Set up automated sync schedule"
echo ""
log_message "Export completed successfully - Total records: $TOTAL_RECORDS"
echo -e "${GREEN}✓ All done!${NC}"
echo ""