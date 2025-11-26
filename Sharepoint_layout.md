# IoTKinect LoRaWAN Management Portal - Complete SharePoint Site Design

Based on your API and concept, here's the complete SharePoint site structure with exact layouts, pages, and API mappings.

***

## 🏗️ Site Architecture

### **Site Structure**
```
IoTKinect Portal (Home)
├── 📊 Dashboard (Landing Page)
├── 🖥️ ChirpStack Servers
├── 👥 Tenants
├── 📡 Gateways
├── 📱 Devices
├── 📦 Applications
├── 🔧 Device Profiles
├── 💻 Payload Codecs
├── 👤 Users & Permissions
├── 🔐 API Keys
└── ⚙️ Settings
```

***

## 📊 1. DASHBOARD (Home Page)

### Layout: 3 Rows
**API Endpoint:** `/api/stats`

#### **Row 1: Key Metrics (4 Columns)**
```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│   TENANTS    │   GATEWAYS   │   DEVICES    │   SERVERS    │
│      4       │      1       │      2       │      1       │
│   Active     │   Online     │   Active     │   Synced     │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

**Web Parts:**
- 4× **Hero Web Part** (styled as KPI cards)
- Data from: `/api/stats`
  - `device_summary[].total_devices` (sum)
  - `gateway_summary[].online_gateways` (sum)
  - Tenant count from `/api/exports/tenants`
  - Server count from `/api/exports/chirpstack_servers`

#### **Row 2: Device Health Overview (2 Columns)**
```
┌─────────────────────────────┬─────────────────────────────┐
│  DEVICE STATUS              │  GATEWAY STATUS             │
│  ┌──────────────────────┐   │  ┌──────────────────────┐   │
│  │ Active (24h):   1    │   │  │ Online:         1    │   │
│  │ Recent (7d):    2    │   │  │ Recent:         0    │   │
│  │ Inactive:       0    │   │  │ Offline:        0    │   │
│  │ Disabled:       0    │   │  └──────────────────────┘   │
│  └──────────────────────┘   │  Pie Chart                  │
└─────────────────────────────┴─────────────────────────────┘
```

**Web Parts:**
- Left: **Quick Chart Web Part** (Device Status Donut)
- Right: **Quick Chart Web Part** (Gateway Status Donut)
- Data from: `/api/stats` → `device_summary` and `gateway_summary`

#### **Row 3: Recent Activity & Alerts (3 Columns)**
```
┌────────────────────┬────────────────────┬────────────────────┐
│ LOW BATTERY        │ LAST EXPORT        │ TENANT OVERVIEW    │
│ Devices            │ Status             │ Chart              │
│                    │                    │                    │
│ None               │ 2 min ago          │ [Bar Chart]        │
│                    │ ✓ Successful       │ Devices per Tenant │
└────────────────────┴────────────────────┴────────────────────┘
```

**Web Parts:**
- Left: **List Web Part** (Low battery devices from `/api/exports/devices`)
- Middle: **Text Web Part** (Last export from `/api/metadata`)
- Right: **Quick Chart Web Part** (Tenant device distribution)

***

## 🖥️ 2. CHIRPSTACK SERVERS PAGE

### Layout: 2 Rows
**API Endpoint:** `/api/exports/chirpstack_servers`

#### **Row 1: Page Header (1 Column)**
```
┌──────────────────────────────────────────────────────────┐
│ 🖥️ ChirpStack Servers                                    │
│ Manage and monitor all ChirpStack server connections     │
│ [+ Add Server] [↻ Sync All]                             │
└──────────────────────────────────────────────────────────┘
```

**Web Parts:**
- **Page Title** + **Button Web Parts**

#### **Row 2: Server List (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────┐
│ Server Name    │ Server URL                    │ Environment │ Status  │
├────────────────┼───────────────────────────────┼─────────────┼─────────┤
│ LNS-IoTKinect  │ https://lns.ca.iotkinect.io  │ Production  │ ✓ Active│
│ Last Sync: 2025-11-25 23:11:23                │ [View Details]        │
└──────────────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `ChirpStack_Servers`

**Columns:**
- Server ID (Single line - hidden)
- Server Name (Single line)
- Server URL (Hyperlink)
- Environment (Choice: Production, Staging, Development)
- Status (Choice: Active, Inactive, Error)
- Last Sync (Date/Time)
- Notes (Multiple lines)

**Web Parts:**
- **List Web Part** → Connected to `ChirpStack_Servers` list
- Filter: Show active servers
- Custom formatting: Status badges (green/red)

**Data Source:**
```javascript
// Power Automate Flow or Script
// Endpoint: /api/exports/chirpstack_servers
// Map to SharePoint list items
```

***

## 👥 3. TENANTS PAGE

### Layout: 2 Rows
**API Endpoint:** `/api/exports/tenants`

#### **Row 1: Tenant Cards Grid (1 Column)**
```
┌─────────────────────────────────────────────────────────────────┐
│ 👥 Tenants (4)                                   [+ Add Tenant] │
├─────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ │
│ │ ChirpStack       │ │ nishchayjeets    │ │ supercell3764    │ │
│ │ 0 devices        │ │ 2 devices        │ │ 0 devices        │ │
│ │ 0 gateways       │ │ 1 gateway        │ │ 0 gateways       │ │
│ │ [View Details]   │ │ [View Details]   │ │ [View Details]   │ │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `Tenants`

**Columns:**
- Tenant ID (Single line - hidden)
- Tenant Name (Single line - title)
- Description (Multiple lines)
- Max Device Count (Number)
- Max Gateway Count (Number)
- Source Server (Lookup → ChirpStack_Servers)
- Contact Email (Single line)
- Created Date (Date/Time)
- Can Have Gateways (Yes/No)

**Web Parts:**
- **Board Web Part** (Tile view)
- Grouped by Source Server
- Count badges for devices/gateways

**Data Integration:**
```javascript
// Endpoint: /api/exports/tenants
// Enrich with: /api/stats (device_summary, gateway_summary)
```

#### **Row 2: Detailed List View (1 Column)**
```
┌────────────────────────────────────────────────────────────────────────────┐
│ Search: [_____] Filter: [All Servers ▼]                                   │
├──────────────┬────────────────┬──────────┬──────────┬────────────────────┤
│ Tenant Name  │ Description    │ Devices  │ Gateways │ Server             │
├──────────────┼────────────────┼──────────┼──────────┼────────────────────┤
│ ChirpStack   │ Default tenant │    0     │    0     │ LNS-IoTKinect      │
│ nishchayjeets│ Self-service.. │    2     │    1     │ LNS-IoTKinect      │
└──────────────┴────────────────┴──────────┴──────────┴────────────────────┘
```

**Web Parts:**
- **List Web Part** with filtering
- Custom List View Formatting (JSON)

***

## 📡 4. GATEWAYS PAGE

### Layout: 2 Rows
**API Endpoint:** `/api/exports/gateways`

#### **Row 1: Gateway Status Map (1 Column)**
```
┌──────────────────────────────────────────────────────────────────┐
│ 📡 Gateway Network Status                      [+ Add Gateway]   │
│                                                                   │
│   [Interactive Map with Gateway Pins]                            │
│   🟢 Online: 1    🟡 Recent: 0    🔴 Offline: 0                 │
│                                                                   │
│   Gateway: Multitech Gateway                                     │
│   Location: 47.50414, -122.55175 (Washington)                   │
│   Status: 🟢 Online (Last seen: 2 min ago)                      │
└──────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `Gateways`

**Columns:**
- Gateway EUI (Single line - title)
- Gateway Name (Single line)
- Description (Multiple lines)
- Tenant (Lookup → Tenants)
- Latitude (Number)
- Longitude (Number)
- Altitude (Number)
- Last Seen (Date/Time)
- Connection Status (Choice: Online, Recent, Offline, Never Seen)
- Source Server (Lookup → ChirpStack_Servers)
- Stats Interval (Number)
- **Credentials Section** (secured):
  - Login Username (Single line - encrypted)
  - Login Password (Single line - encrypted)
  - Access Notes (Multiple lines)

**Web Parts:**
- **Bing Maps Web Part** (shows gateway locations)
- **List Web Part** (gateway details)

#### **Row 2: Gateway List (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Gateway Name      │ EUI            │ Tenant        │ Status │ Last Seen      │
├───────────────────┼────────────────┼───────────────┼────────┼────────────────┤
│ Multitech Gateway │ 00800000a00... │ nishchayjeets │ 🟢     │ 2 min ago     │
│ [View Details] [Edit Credentials] [View on Map]                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Data Source:**
```javascript
// Endpoint: /api/exports/gateways
// Status logic based on last_seen_at
```

***

## 📱 5. DEVICES PAGE (MOST IMPORTANT)

### Layout: 3 Rows
**API Endpoints:** `/api/exports/devices`, `/api/search/devices`

#### **Row 1: Search & Quick Stats (2 Columns)**
```
┌─────────────────────────────────────┬──────────────────────────────┐
│ 🔍 Search Devices                   │ Quick Stats                  │
│ [Search by name, EUI, or app...]    │ Total: 2                     │
│                                      │ Active (24h): 1              │
│ Filters:                             │ Recent (7d): 2               │
│ [ ] Show Active Only                │ Class A: 2                   │
│ [All Tenants ▼] [All Apps ▼]       │ Low Battery: 0               │
└─────────────────────────────────────┴──────────────────────────────┘
```

**Web Parts:**
- Left: **Search Box** + **Filter Web Parts**
- Right: **Text Web Part** with stats from `/api/stats`

#### **Row 2: Device Cards (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────┐
│ ┌────────────────────────────┐ ┌────────────────────────────┐           │
│ │ 📱 Dragino LDS02           │ │ 📱 Tektelic Comfort Sensor│           │
│ │ EUI: a840411371858822      │ │ EUI: 647fda0000022691      │           │
│ │ 🟢 Active (1h ago)         │ │ 🟡 Recent (2d ago)         │           │
│ │ 🔋 Battery: 39.37%         │ │ 🔋 Battery: N/A            │           │
│ │ Tenant: nishchayjeets      │ │ Tenant: nishchayjeets      │           │
│ │ App: IoTKinect Sensors     │ │ App: IoTKinect Sensors     │           │
│ │ Profile: Dragino Door...   │ │ Profile: TEKTELIC COMFORT  │           │
│ │ [View Details] [View Keys] │ │ [View Details] [View Keys] │           │
│ └────────────────────────────┘ └────────────────────────────┘           │
└──────────────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `Devices`

**Columns:**
- Device EUI (Single line - title, indexed)
- Device Name (Single line)
- Join EUI (Single line)
- **App Key** (Single line - encrypted, permissions required)
- **Network Key** (Single line - encrypted, permissions required)
- Description (Multiple lines)
- Application (Lookup → Applications)
- Device Profile (Lookup → Device_Profiles)
- Tenant (Lookup → Tenants)
- Enabled Class (Choice: A, B, C)
- Is Disabled (Yes/No)
- Battery Level (Number)
- Data Rate (Number)
- Frame Counter Up (Number)
- Latitude (Number)
- Longitude (Number)
- Last Seen (Date/Time)
- Activity Status (Choice: Active, Recent, Never, Inactive)
- Source Server (Lookup → ChirpStack_Servers)
- Codec (Lookup → Payload_Codecs)

**Security:**
- App Key & Network Key columns: Restricted to "Admins" group only
- Other fields: Read-only for standard users

**Web Parts:**
- **Board Web Part** (Card layout)
- Custom formatting with status badges
- Battery level progress bar

#### **Row 3: Detailed List View (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Device Name      │ EUI        │ Status │ Battery │ Tenant    │ Last Seen    │
├──────────────────┼────────────┼────────┼─────────┼───────────┼──────────────┤
│ Dragino LDS02    │ a84041...  │ 🟢     │ 39.37%  │ nishchay..│ 1h ago      │
│ Tektelic Comfort │ 647fda...  │ 🟡     │ N/A     │ nishchay..│ 2d ago      │
└──────────────────┴────────────┴────────┴─────────┴───────────┴──────────────┘
```

**Data Integration:**
```javascript
// Search endpoint: /api/search/devices?q={searchTerm}
// Full list: /api/exports/devices
// Paginated: /api/exports/devices/paginated?page=1&limit=50
```

***

## 📦 6. APPLICATIONS PAGE

### Layout: 2 Rows
**API Endpoint:** `/api/exports/applications`

#### **Row 1: Application Cards (1 Column)**
```
┌──────────────────────────────────────────────────────────────────┐
│ 📦 Applications (1)                          [+ Add Application] │
├──────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────────┐   │
│ │ IoTKinect Sensors                                          │   │
│ │ Tenant: nishchayjeets-tenant-yykw                         │   │
│ │ Devices: 2                                                 │   │
│ │ Created: 2025-11-18                                        │   │
│ │ [View Devices] [View Integrations]                        │   │
│ └────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `Applications`

**Columns:**
- Application ID (Single line - hidden)
- Application Name (Single line - title)
- Description (Multiple lines)
- Tenant (Lookup → Tenants)
- Device Count (Calculated/Number)
- Source Server (Lookup → ChirpStack_Servers)
- Created Date (Date/Time)

#### **Row 2: Integrations (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Application Integrations                                                     │
├────────────────┬─────────────────┬───────────────────────────────────────────┤
│ Application    │ Integration     │ Configuration                             │
├────────────────┼─────────────────┼───────────────────────────────────────────┤
│ IoTKinect...   │ HTTP            │ {"headers":{},"endpoint":"..."}          │
└────────────────┴─────────────────┴───────────────────────────────────────────┘
```

**SharePoint List:** `Integrations`

**Columns:**
- Application (Lookup → Applications)
- Integration Type (Choice: HTTP, MQTT, InfluxDB, Azure IoT)
- Configuration JSON (Multiple lines)
- Created Date (Date/Time)

**Data Source:**
```javascript
// Endpoint: /api/exports/integrations
```

***

## 🔧 7. DEVICE PROFILES PAGE

### Layout: 2 Rows
**API Endpoint:** `/api/exports/device_profiles`

#### **Row 1: Profile Cards (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────┐
│ 🔧 Device Profiles (4)                          [+ Add Profile]     │
├──────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐    │
│ │ Dragino LDS02    │ │ TEKTELIC COMFORT│ │ Profile 3        │    │
│ │ Region: US902    │ │ Region: US902   │ │ Region: EU868    │    │
│ │ Class: A         │ │ Class: A        │ │ Class: C         │    │
│ │ OTAA: ✓          │ │ OTAA: ✓         │ │ OTAA: ✓          │    │
│ │ Codec: JS        │ │ Codec: JS       │ │ Codec: None      │    │
│ │ Devices: 1       │ │ Devices: 1      │ │ Devices: 0       │    │
│ │ [View Codec]     │ │ [View Codec]    │ │ [Edit]           │    │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `Device_Profiles`

**Columns:**
- Profile ID (Single line - hidden)
- Profile Name (Single line - title)
- Description (Multiple lines)
- Tenant (Lookup → Tenants)
- Region (Choice: US902, EU868, AS923, AU915, etc.)
- MAC Version (Single line)
- Supports OTAA (Yes/No)
- Supports Class B (Yes/No)
- Supports Class C (Yes/No)
- Payload Codec Runtime (Choice: None, Cayenne LPP, JavaScript)
- Codec (Lookup → Payload_Codecs)
- Uplink Interval (Number - seconds)
- ADR Algorithm (Single line)
- Source Server (Lookup → ChirpStack_Servers)
- Device Count (Calculated)

#### **Row 2: Profile Details (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Profile Name         │ Region │ Class │ Codec    │ Devices │ Created        │
├──────────────────────┼────────┼───────┼──────────┼─────────┼────────────────┤
│ Dragino Door Sensor  │ US902  │ A     │ JS       │    1    │ 2025-11-18    │
│ TEKTELIC COMFORT     │ US902  │ A     │ JS       │    1    │ 2025-11-18    │
└──────────────────────┴────────┴───────┴──────────┴─────────┴────────────────┘
```

***

## 💻 8. PAYLOAD CODECS PAGE

### Layout: 3 Rows
**API Endpoints:** `/api/codecs`, `/api/codecs/{name}`

#### **Row 1: Codec Library (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────┐
│ 💻 Payload Codecs (2)                          [+ Upload Codec]     │
│ Version control for device payload decoders                          │
└──────────────────────────────────────────────────────────────────────┘
```

#### **Row 2: Codec List (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Codec Name                │ Runtime │ Size   │ Devices │ Version │ Modified │
├───────────────────────────┼─────────┼────────┼─────────┼─────────┼──────────┤
│ Dragino Door Sensor LDS02 │ JS      │ 1.6KB  │    1    │  1.0    │ Today    │
│ TEKTELIC COMFORT Base     │ JS      │ 57KB   │    1    │  1.0    │ Today    │
│ [Download] [View Code] [History]                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

**SharePoint Document Library:** `Payload_Codecs` (with versioning enabled)

**Metadata Columns:**
- Codec Name (Single line)
- Device Profile (Lookup → Device_Profiles)
- Runtime (Choice: JavaScript, Cayenne LPP)
- File Size (Number)
- Devices Using (Calculated)
- Version (Managed via SharePoint versioning)
- Tested (Yes/No)
- Notes (Multiple lines)

#### **Row 3: Code Viewer (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────┐
│ Selected: Dragino Door Sensor LDS02                   Version: 1.0  │
├──────────────────────────────────────────────────────────────────────┤
│ function decodeUplink(input) {                                       │
│     return {                                                         │
│         data: Decode(input.fPort, input.bytes, input.variables)     │
│     };                                                               │
│ }                                                                    │
│ ...                                                                  │
│                                                                      │
│ [Download .js] [Copy to Clipboard] [Compare Versions]              │
└──────────────────────────────────────────────────────────────────────┘
```

**Web Parts:**
- **Code Snippet Web Part** or **Embed Web Part**
- Shows syntax-highlighted JavaScript

**Data Integration:**
```javascript
// List codecs: /api/codecs
// Get codec content: /api/codecs/{filename}
// Store in SharePoint Doc Library with version history
```

***

## 👤 9. USERS & PERMISSIONS PAGE

### Layout: 2 Rows
**API Endpoints:** `/api/exports/users`, `/api/exports/tenant_user_roles`

#### **Row 1: User List (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 👤 Users (3)                                              [+ Add User]       │
├────────────────────────┬──────────┬──────────┬───────────────────────────────┤
│ Email                  │ Admin    │ Active   │ Tenant Access                 │
├────────────────────────┼──────────┼──────────┼───────────────────────────────┤
│ admin@chirpstack.io    │ ✓        │ ✓        │ All Tenants                   │
│ nishchayjeets@gmail... │          │ ✓        │ nishchayjeets-tenant-yykw     │
│ supercell3764@gmail... │          │ ✓        │ supercell3764-tenant-gtmu     │
└────────────────────────┴──────────┴──────────┴───────────────────────────────┘
```

**SharePoint List:** `Portal_Users`

**Columns:**
- User Email (Single line - title)
- Is Admin (Yes/No)
- Is Active (Yes/No)
- Email Verified (Yes/No)
- Tenant Access (Lookup → Tenants, allow multiple)
- Created Date (Date/Time)
- Last Login (Date/Time)
- Source Server (Lookup → ChirpStack_Servers)

#### **Row 2: Tenant Permissions Matrix (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Tenant User Roles                                                            │
├────────────────────┬──────────────────┬────────────┬─────────┬──────────────┤
│ User               │ Tenant           │ Admin      │ Devices │ Gateways     │
├────────────────────┼──────────────────┼────────────┼─────────┼──────────────┤
│ nishchayjeets...   │ nishchayjeets... │ ✓          │ ✓       │ ✓            │
│ supercell3764...   │ supercell3764... │ ✓          │ ✓       │ ✓            │
└────────────────────┴──────────────────┴────────────┴─────────┴──────────────┘
```

**SharePoint List:** `Tenant_User_Roles`

**Columns:**
- User (Lookup → Portal_Users)
- Tenant (Lookup → Tenants)
- Is Tenant Admin (Yes/No)
- Is Device Admin (Yes/No)
- Is Gateway Admin (Yes/No)
- Granted Date (Date/Time)

***

## 🔐 10. API KEYS PAGE

### Layout: 1 Row
**API Endpoint:** `/api/exports/api_keys`

#### **Row 1: API Keys List (1 Column)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🔐 API Keys (2)                                          [+ Generate Key]    │
├────────────────────┬──────────────────┬──────────┬──────────────────────────┤
│ Key Name           │ Tenant           │ Admin    │ Created                  │
├────────────────────┼──────────────────┼──────────┼──────────────────────────┤
│ API Key 1          │ ChirpStack       │ ✓        │ 2025-11-18              │
│ Nishchay API Key   │ nishchayjeets... │          │ 2025-11-18              │
│ [View Details] [Regenerate] [Revoke]                                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

**SharePoint List:** `API_Keys` (Restricted access)

**Columns:**
- Key Name (Single line - title)
- Tenant (Lookup → Tenants)
- Is Admin (Yes/No)
- Created Date (Date/Time)
- Last Used (Date/Time)
- Source Server (Lookup → ChirpStack_Servers)
- Status (Choice: Active, Revoked)

***

## ⚙️ 11. SETTINGS PAGE

### Layout: 3 Rows

#### **Row 1: Sync Settings (2 Columns)**
```
┌─────────────────────────────────┬────────────────────────────────┐
│ 🔄 Auto-Sync Configuration      │ 📊 Sync Status                 │
│                                  │                                │
│ Sync Interval: [15 minutes ▼]  │ Last Sync: 2 min ago          │
│ Auto-cleanup old data: [✓]      │ Next Sync: 13 min             │
│ Keep archives: [10      ]       │ Status: ✓ Healthy             │
│                                  │ Errors: 0                      │
│ [Save Settings]                  │ [Force Sync Now]              │
└─────────────────────────────────┴────────────────────────────────┘
```

#### **Row 2: API Configuration (1 Column)**
```
┌──────────────────────────────────────────────────────────────────┐
│ 🔌 API Connection Settings                                       │
│                                                                   │
│ API Endpoint: http://192.168.69.35:8750                         │
│ API Token: ************************************67 [Show] [Copy]  │
│ Connection Status: ✓ Connected                                   │
│ Test Connection: [Test Now]                                      │
└──────────────────────────────────────────────────────────────────┘
```

#### **Row 3: Manual Actions (1 Column)**
```
┌──────────────────────────────────────────────────────────────────┐
│ 🛠️ Manual Actions                                                │
│                                                                   │
│ [+ Manual Device Entry]  [+ Manual Gateway Entry]               │
│ [+ Manual Tenant Entry]  [Import from CSV]                      │
│ [Export All Data]        [View System Logs]                     │
└──────────────────────────────────────────────────────────────────┘
```

***

## 📋 COMPLETE API MAPPING TABLE

| SharePoint List/Page | Primary API Endpoint | Additional Endpoints | Sync Frequency |
|---------------------|---------------------|---------------------|----------------|
| **Dashboard** | `/api/stats` | `/api/metadata`, `/api/exports` | Real-time |
| **ChirpStack_Servers** | `/api/exports/chirpstack_servers` | - | Daily |
| **Tenants** | `/api/exports/tenants` | `/api/stats` (counts) | Every 15 min |
| **Gateways** | `/api/exports/gateways` | `/api/exports/gateway_summary` | Every 15 min |
| **Devices** | `/api/exports/devices` | `/api/search/devices`, `/api/exports/devices/paginated` | Every 15 min |
| **Applications** | `/api/exports/applications` | - | Every 15 min |
| **Device_Profiles** | `/api/exports/device_profiles` | `/api/exports/payload_codecs_metadata` | Every 15 min |
| **Payload_Codecs** | `/api/codecs` | `/api/codecs/{name}` | On-demand |
| **Portal_Users** | `/api/exports/users` | - | Daily |
| **Tenant_User_Roles** | `/api/exports/tenant_user_roles` | - | Daily |
| **API_Keys** | `/api/exports/api_keys` | - | Daily |
| **Integrations** | `/api/exports/integrations` | - | Every 15 min |

***

## 🔄 DATA SYNC ARCHITECTURE

### Power Automate Flow (Recommended)

**Flow 1: Scheduled Sync (Every 15 minutes)**
```
Trigger: Recurrence (Every 15 minutes)
  ↓
Action: HTTP Request to /api/metadata
  ↓
Condition: Check if new export available
  ↓ (Yes)
Action: For each entity type:
  - HTTP GET /api/exports/{entity}
  - Parse JSON
  - For each record:
    - Check if exists in SharePoint (by EUI/ID)
    - If exists: Update item
    - If not: Create new item
  ↓
Action: Log sync result
```

**Flow 2: Real-time Dashboard Update**
```
Trigger: When page loads (Power Apps)
  ↓
Action: HTTP GET /api/stats
  ↓
Action: Display metrics in dashboard
```

**Flow 3: Codec Download**
```
Trigger: Button click "Download Codec"
  ↓
Action: HTTP GET /api/codecs/{codec_name}
  ↓
Action: Create file in Payload_Codecs library
```

***

## 🎨 DESIGN GUIDELINES

### Color Scheme
- **Primary:** #0078D4 (Azure Blue)
- **Success:** #107C10 (Green)
- **Warning:** #FFB900 (Amber)
- **Error:** #D13438 (Red)
- **Neutral:** #605E5C (Gray)

### Status Badges
- 🟢 **Online/Active:** Green (#107C10)
- 🟡 **Recent/Warning:** Amber (#FFB900)
- 🔴 **Offline/Error:** Red (#D13438)
- ⚪ **Unknown/Never:** Gray (#605E5C)

### Icons (Fluent UI)
- Tenants: 👥 ContactCard
- Gateways: 📡 Radio
- Devices: 📱 CellPhone
- Applications: 📦 Package
- Codecs: 💻 Code
- Users: 👤 Contact
- Servers: 🖥️ Server

***

## 📝 IMPLEMENTATION CHECKLIST

### Phase 1: Foundation (Week 1)
- [ ] Create SharePoint site
- [ ] Create all lists with columns
- [ ] Set up permissions groups
- [ ] Create basic pages structure

### Phase 2: Data Integration (Week 2)
- [ ] Set up Power Automate flows
- [ ] Test API connections
- [ ] Import initial data
- [ ] Set up scheduled sync

### Phase 3: UI/UX (Week 3)
- [ ] Design dashboard
- [ ] Apply custom formatting
- [ ] Add web parts
- [ ] Test all pages

### Phase 4: Security & Go-Live (Week 4)
- [ ] Encrypt sensitive fields
- [ ] Test permissions
- [ ] User acceptance testing
- [ ] Deploy to production

***


https://www.perplexity.ai/search/can-we-integrate-api-in-same-s-ofA6QCMEROeazEeceXmPMg