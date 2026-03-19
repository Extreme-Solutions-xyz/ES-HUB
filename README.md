# Extreme Solutions — Key System

License key management API for the Extreme Solutions Script Hub. Handles key generation, validation, expiration, and HWID locking.

---

## How It Works

```
Customer buys key on MySellAuth
        ↓
Key delivered (pre-generated)
        ↓
Customer enters key in Script Hub GUI
        ↓
Script calls POST /api/validate → API checks key
        ↓
✅ Valid → Script loads    ❌ Invalid → Access denied
```

## Quick Start (Local)

```bash
# 1. Clone/download this folder
# 2. Install dependencies
npm install

# 3. Set your admin API key (pick something long and random)
# On Windows:
set ADMIN_API_KEY=your-secret-key-here

# On Mac/Linux:
export ADMIN_API_KEY=your-secret-key-here

# 4. Start the server
npm start

# Server runs at http://localhost:3000
# Admin panel at http://localhost:3000/admin
```

---

## Deploy to Railway (Recommended)

1. Push this folder to a **GitHub repo** (private recommended)
2. Go to [railway.app](https://railway.app) and sign in with GitHub
3. Click **"New Project"** → **"Deploy from GitHub repo"**
4. Select your repo
5. Go to the **Variables** tab and add:
   - `ADMIN_API_KEY` = `your-secret-admin-key` (make this long and random)
   - `PORT` = `3000`
6. Railway will auto-deploy. You'll get a URL like `https://your-app.up.railway.app`
7. Your admin panel will be at `https://your-app.up.railway.app/admin`

### Important: Persistent Storage on Railway
By default Railway doesn't persist files between deploys. To keep your database:
- Add a **Volume** in Railway settings
- Mount it at `/data`
- Add env variable: `DB_PATH=/data/keys.db`

---

## Workflow: Generating Keys for MySellAuth

1. Open your admin panel (`/admin`)
2. Enter your admin API key
3. Select tier (1 Day, 3 Day, 1 Month, Lifetime)
4. Set quantity (e.g., 50)
5. Click **Generate Keys**
6. Click **Copy All**
7. In MySellAuth, go to your product → Stock
8. Paste all keys (one per line) as stock items
9. Done! Keys are now delivered on purchase.

---

## API Reference

### Public Endpoints (called by your script)

#### `POST /api/validate`
Validate and activate a key. This is what your Roblox script calls.

**Request:**
```json
{
  "key": "ES-A1B2-C3D4-E5F6-G7H8",
  "hwid": "optional-hardware-id"
}
```

**Response (success):**
```json
{
  "success": true,
  "message": "Key is valid.",
  "tier": "1month",
  "expires_at": "2025-04-15T00:00:00.000Z",
  "hwid_locked": true
}
```

**Response (fail):**
```json
{
  "success": false,
  "error": "Invalid key."
}
```

Possible errors: `Invalid key.` | `Key has expired.` | `Key has been revoked.` | `Key is locked to another device.`

---

#### `POST /api/reset-hwid`
Reset HWID lock on a key (if you offer this to customers).

**Request:**
```json
{
  "key": "ES-A1B2-C3D4-E5F6-G7H8"
}
```

---

### Admin Endpoints (require `x-api-key` header)

All admin endpoints require the header: `x-api-key: your-admin-key`

#### `POST /api/admin/generate`
Generate keys in bulk.
```json
{
  "tier": "1month",
  "count": 50,
  "note": "March restock"
}
```
Tiers: `1day` | `3day` | `1month` | `lifetime`

#### `GET /api/admin/keys`
List keys with filters.
```
GET /api/admin/keys?status=active&tier=1month&page=1&limit=50&search=ES-A1B2
```

#### `GET /api/admin/stats`
Get key statistics (totals by status and tier).

#### `POST /api/admin/revoke`
Revoke a key.
```json
{ "key": "ES-A1B2-C3D4-E5F6-G7H8" }
```

#### `POST /api/admin/delete`
Delete keys by array or status.
```json
{ "keys": ["ES-XXXX-XXXX-XXXX-XXXX"] }
```
or
```json
{ "status": "expired" }
```

---

## Connecting Your Roblox Script

Your loader script needs to make an HTTP request to validate the key. Here's the general pattern your script should follow (Lua/Luau):

```
1. User enters key in GUI
2. Script sends HTTP POST to https://your-api-url.com/api/validate
   with body: { key = "entered-key", hwid = game:GetService("RbxAnalyticsService"):GetClientId() }
3. Parse JSON response
4. If success == true → unlock script features
5. If success == false → show error message from response
```

The HWID field is optional but recommended — it locks a key to one device so it can't be shared.

---

## Key Format

Keys look like: `ES-A1B2-C3D4-E5F6-G7H8`

- Prefix: `ES` (for Extreme Solutions)
- 4 segments of 4 hex characters
- All uppercase

You can change the prefix by editing `KEY_PREFIX` in `server.js`.

---

## Security Notes

- **Change the default ADMIN_API_KEY** before deploying
- The validation endpoint is rate-limited (30 req/min per IP)
- HWID locking prevents key sharing
- Keys auto-expire based on tier duration
- The admin panel requires your API key to function

---

## File Structure

```
extreme-solutions-keysystem/
├── server.js          # Main API server
├── package.json       # Dependencies
├── keys.db            # SQLite database (auto-created)
├── public/
│   └── admin.html     # Admin dashboard
└── README.md          # This file
```
