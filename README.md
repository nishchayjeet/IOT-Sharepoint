Perfect! Your API is live and accessible publicly! 🎉

Here are all the test commands for **Server 2 (15.223.148.98:8750)** based on the SharePoint structure:

***

## 🧪 **Complete API Testing Commands**

### **Set Your Token First:**
```bash
export API_TOKEN="9379d05ce3abcc4716c44b9a8901b27930bf69fcbb351a5bfeea744a020587bf"
export API_URL="http://15.223.148.98:8750"
```

***

## 📊 **1. DASHBOARD DATA**

### **Get Overall Stats (for KPI cards):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/stats" | python3 -m json.tool
```

**Expected:** Server info, device summary (7 tenants), gateway summary (33 gateways)

### **Get Metadata (last export time):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/metadata" | python3 -m json.tool
```

### **List All Available Exports:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports" | python3 -m json.tool
```

***

## 🖥️ **2. CHIRPSTACK SERVERS**

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/chirpstack_servers" | python3 -m json.tool
```

**Expected:** 1 server (LNS-IoTKinect)

***

## 👥 **3. TENANTS**

### **Get All Tenants:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/tenants" | python3 -m json.tool
```

**Expected:** 7 tenants with descriptions, device limits

### **Get Tenant Summary (for device/gateway counts):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/stats" | python3 -m json.tool | grep -A 15 "device_summary"
```

***

## 📡 **4. GATEWAYS**

### **Get All Gateways:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/gateways" | python3 -m json.tool | head -100
```

**Expected:** 32 gateways with location, status, last seen

### **Get Gateway Summary (online/offline counts):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/gateway_summary" | python3 -m json.tool
```

### **Filter Online Gateways Only:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/gateways" | python3 -m json.tool | \
     grep -B 5 -A 15 '"connection_status": "Online"'
```

***

## 📱 **5. DEVICES (MOST IMPORTANT)**

### **Get All Devices (105 devices):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/devices" | python3 -m json.tool | head -200
```

### **Get Paginated Devices (Page 1, 10 per page):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/devices/paginated?page=1&limit=10" | python3 -m json.tool
```

### **Search Devices by Keyword:**
```bash
# Search for "sensor"
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/search/devices?q=sensor" | python3 -m json.tool | head -100

# Search for "gateway"
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/search/devices?q=gateway" | python3 -m json.tool

# Search for specific device by EUI
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/search/devices?q=9150000324900288" | python3 -m json.tool
```

### **Get Device Summary (for stats):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/device_summary" | python3 -m json.tool
```

### **Count Active Devices (last 24h):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/devices" | python3 -m json.tool | \
     grep '"activity_status": "Active"' | wc -l
```

***

## 📦 **6. APPLICATIONS**

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/applications" | python3 -m json.tool
```

**Expected:** 36 applications

***

## 🔧 **7. DEVICE PROFILES**

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/device_profiles" | python3 -m json.tool | head -100
```

**Expected:** 65 device profiles

### **Get Profiles with Codecs:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/payload_codecs_metadata" | python3 -m json.tool
```

**Expected:** 51 profiles with codec metadata

***

## 💻 **8. PAYLOAD CODECS**

### **List All Codecs:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/codecs" | python3 -m json.tool
```

**Expected:** 33 codec files

### **Get Specific Codec Script:**
```bash
# Example: Get Dragino codec
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/codecs/Dragino_LHT65_9c3e0c8f-3a77-4f1b-a48b-8c97c9e8d4c7.js" | \
     python3 -m json.tool
```

### **List Codec Names Only:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/codecs" | python3 -c "import sys, json; data=json.load(sys.stdin); print('\n'.join([c['name'] for c in data['codecs']]))"
```

***

## 👤 **9. USERS & PERMISSIONS**

### **Get All Users:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/users" | python3 -m json.tool
```

**Expected:** 10 users

### **Get Tenant User Roles:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/tenant_user_roles" | python3 -m json.tool
```

***

## 🔐 **10. API KEYS**

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/api_keys" | python3 -m json.tool
```

**Expected:** 3 API keys

***

## 🔌 **11. INTEGRATIONS**

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
     "$API_URL/api/exports/integrations" | python3 -m json.tool
```

**Expected:** 22 integrations (HTTP, MQTT, etc.)

***

## 📊 **SHAREPOINT-READY DATA SAMPLES**

### **Dashboard KPI Data:**
```bash
# Total counts for dashboard cards
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/stats" | \
python3 << 'EOF'
import sys, json
data = json.load(sys.stdin)
print(f"📊 DASHBOARD KPIs:")
print(f"  Tenants: {len(data['device_summary'])}")
print(f"  Total Devices: {sum(int(t['total_devices']) for t in data['device_summary'])}")
print(f"  Online Gateways: {sum(int(t['online_gateways']) for t in data['gateway_summary'])}")
print(f"  Active Devices (24h): {sum(int(t['devices_seen_24h']) for t in data['device_summary'])}")
print(f"  Codecs Available: {data['codecs_available']}")
print(f"  Last Export: {data['last_export']}")
EOF
```

### **Device Status Breakdown (for pie chart):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/devices" | \
python3 << 'EOF'
import sys, json
data = json.load(sys.stdin)
statuses = {}
for d in data:
    status = d.get('activity_status', 'Unknown')
    statuses[status] = statuses.get(status, 0) + 1
print("📱 DEVICE STATUS:")
for status, count in sorted(statuses.items()):
    print(f"  {status}: {count}")
EOF
```

### **Gateway Status Breakdown:**
```bash
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/gateways" | \
python3 << 'EOF'
import sys, json
data = json.load(sys.stdin)
statuses = {}
for g in data:
    status = g.get('connection_status', 'Unknown')
    statuses[status] = statuses.get(status, 0) + 1
print("📡 GATEWAY STATUS:")
for status, count in sorted(statuses.items()):
    print(f"  {status}: {count}")
EOF
```

### **Devices Per Tenant (for bar chart):**
```bash
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/device_summary" | \
python3 << 'EOF'
import sys, json
data = json.load(sys.stdin)
print("👥 DEVICES PER TENANT:")
for tenant in sorted(data, key=lambda x: int(x['total_devices']), reverse=True):
    print(f"  {tenant['tenant_name']}: {tenant['total_devices']} devices")
EOF
```

***

## 🎯 **SAVE ALL DATA TO FILES (for SharePoint Import)**

```bash
# Create data directory
mkdir -p ~/chirpstack_data

# Export all key data
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/tenants" > ~/chirpstack_data/tenants.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/devices" > ~/chirpstack_data/devices.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/gateways" > ~/chirpstack_data/gateways.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/applications" > ~/chirpstack_data/applications.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/device_profiles" > ~/chirpstack_data/device_profiles.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/users" > ~/chirpstack_data/users.json
curl -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/stats" > ~/chirpstack_data/stats.json

echo "✅ All data exported to ~/chirpstack_data/"
ls -lh ~/chirpstack_data/
```

***

## 🚀 **Quick Test Script**

Save this as `test_api.sh`:

```bash
#!/bin/bash

API_TOKEN="7568eebdc876a426e1fe09180aeedeb97f0c3f59b5d759ebe70c48d895c117ff"
API_URL="http://15.223.148.98:8750"

echo "🧪 Testing ChirpStack Export API"
echo "================================="
echo ""

echo "1️⃣  Health Check:"
curl -s "$API_URL/health" | python3 -m json.tool
echo ""

echo "2️⃣  Statistics:"
curl -s -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/stats" | python3 -m json.tool | head -30
echo ""

echo "3️⃣  Tenants:"
curl -s -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/tenants" | python3 -m json.tool | head -20
echo ""

echo "4️⃣  Device Count:"
DEVICE_COUNT=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/devices" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "Total Devices: $DEVICE_COUNT"
echo ""

echo "5️⃣  Gateway Count:"
GW_COUNT=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_URL/api/exports/gateways" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "Total Gateways: $GW_COUNT"
echo ""

echo "✅ API is working!"
```

Run it:
```bash
chmod +x test_api.sh
./test_api.sh
```

***

Now you have all the commands to test every SharePoint page's data source! 🎊
