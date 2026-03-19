const express = require('express');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const { RateLimiterMemory } = require('rate-limiter-flexible');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Config ───────────────────────────────────────────────────────
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || 'CHANGE-THIS-TO-A-SECURE-KEY';
const KEY_PREFIX = 'ES'; // Keys will look like: ES-XXXX-XXXX-XXXX-XXXX

// Tier durations in milliseconds
const TIER_DURATIONS = {
  '1day': 1 * 24 * 60 * 60 * 1000,
  '3day': 3 * 24 * 60 * 60 * 1000,
  '1month': 30 * 24 * 60 * 60 * 1000,
  'lifetime': null // null = never expires
};

// ─── Middleware ────────────────────────────────────────────────────
app.use(cors());
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Rate limiter: 30 requests per minute per IP (for validation endpoint)
const rateLimiter = new RateLimiterMemory({
  points: 30,
  duration: 60,
});

// Rate limit middleware for public endpoints
async function rateLimit(req, res, next) {
  try {
    const ip = req.headers['x-forwarded-for'] || req.ip;
    await rateLimiter.consume(ip);
    next();
  } catch {
    res.status(429).json({ success: false, error: 'Too many requests. Try again later.' });
  }
}

// Admin auth middleware
function adminAuth(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== ADMIN_API_KEY) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }
  next();
}

// ─── Database Setup ───────────────────────────────────────────────
const db = new Database(process.env.DB_PATH || './keys.db');
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    tier TEXT NOT NULL,
    status TEXT DEFAULT 'unused',
    hwid TEXT DEFAULT NULL,
    activated_at TEXT DEFAULT NULL,
    expires_at TEXT DEFAULT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    note TEXT DEFAULT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_keys_key ON keys(key);
  CREATE INDEX IF NOT EXISTS idx_keys_status ON keys(status);
  CREATE INDEX IF NOT EXISTS idx_keys_hwid ON keys(hwid);
`);

// ─── Helper Functions ─────────────────────────────────────────────
function generateKey() {
  const segments = [];
  for (let i = 0; i < 4; i++) {
    segments.push(crypto.randomBytes(2).toString('hex').toUpperCase());
  }
  return `${KEY_PREFIX}-${segments.join('-')}`;
}

function isKeyExpired(expiresAt) {
  if (!expiresAt) return false; // Lifetime keys never expire
  return new Date(expiresAt) < new Date();
}

// ─── PUBLIC ENDPOINTS (called by your script hub) ─────────────────

/**
 * POST /api/validate
 * Called by your Roblox script to check if a key is valid.
 * Body: { "key": "ES-XXXX-XXXX-XXXX-XXXX", "hwid": "optional-hardware-id" }
 */
app.post('/api/validate', rateLimit, (req, res) => {
  try {
    const { key, hwid } = req.body;

    if (!key) {
      return res.json({ success: false, error: 'No key provided.' });
    }

    const row = db.prepare('SELECT * FROM keys WHERE key = ?').get(key.trim().toUpperCase());

    if (!row) {
      return res.json({ success: false, error: 'Invalid key.' });
    }

    // Key exists but hasn't been activated yet → activate it now
    if (row.status === 'unused') {
      const now = new Date();
      const duration = TIER_DURATIONS[row.tier];
      const expiresAt = duration ? new Date(now.getTime() + duration).toISOString() : null;

      db.prepare(`
        UPDATE keys SET status = 'active', hwid = ?, activated_at = ?, expires_at = ? WHERE id = ?
      `).run(hwid || null, now.toISOString(), expiresAt, row.id);

      return res.json({
        success: true,
        message: 'Key activated!',
        tier: row.tier,
        expires_at: expiresAt,
        hwid_locked: !!hwid
      });
    }

    // Key is active → check expiration
    if (row.status === 'active') {
      if (isKeyExpired(row.expires_at)) {
        db.prepare('UPDATE keys SET status = ? WHERE id = ?').run('expired', row.id);
        return res.json({ success: false, error: 'Key has expired.' });
      }

      // HWID check: if HWID was set on activation, enforce it
      if (row.hwid && hwid && row.hwid !== hwid) {
        return res.json({ success: false, error: 'Key is locked to another device.' });
      }

      return res.json({
        success: true,
        message: 'Key is valid.',
        tier: row.tier,
        expires_at: row.expires_at,
        hwid_locked: !!row.hwid
      });
    }

    // Key is expired, revoked, or other
    if (row.status === 'expired') {
      return res.json({ success: false, error: 'Key has expired.' });
    }

    if (row.status === 'revoked') {
      return res.json({ success: false, error: 'Key has been revoked.' });
    }

    return res.json({ success: false, error: 'Key is not valid.' });

  } catch (err) {
    console.error('Validate error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

/**
 * POST /api/reset-hwid
 * Allow a user to reset their HWID (optional, if you want to offer this)
 * Body: { "key": "ES-XXXX-XXXX-XXXX-XXXX" }
 */
app.post('/api/reset-hwid', rateLimit, (req, res) => {
  try {
    const { key } = req.body;
    if (!key) return res.json({ success: false, error: 'No key provided.' });

    const row = db.prepare('SELECT * FROM keys WHERE key = ?').get(key.trim().toUpperCase());
    if (!row) return res.json({ success: false, error: 'Invalid key.' });
    if (row.status !== 'active') return res.json({ success: false, error: 'Key is not active.' });

    db.prepare('UPDATE keys SET hwid = NULL WHERE id = ?').run(row.id);
    return res.json({ success: true, message: 'HWID reset. Key can be used on a new device.' });

  } catch (err) {
    console.error('HWID reset error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

// ─── ADMIN ENDPOINTS (for you to manage keys) ────────────────────

/**
 * POST /api/admin/generate
 * Generate keys in bulk.
 * Body: { "tier": "1day", "count": 50, "note": "Batch for March sale" }
 */
app.post('/api/admin/generate', adminAuth, (req, res) => {
  try {
    const { tier, count = 10, note } = req.body;

    if (!TIER_DURATIONS.hasOwnProperty(tier)) {
      return res.json({ success: false, error: `Invalid tier. Use: ${Object.keys(TIER_DURATIONS).join(', ')}` });
    }

    if (count < 1 || count > 500) {
      return res.json({ success: false, error: 'Count must be between 1 and 500.' });
    }

    const insert = db.prepare('INSERT INTO keys (key, tier, note) VALUES (?, ?, ?)');
    const keys = [];

    const transaction = db.transaction(() => {
      for (let i = 0; i < count; i++) {
        let newKey;
        let attempts = 0;
        do {
          newKey = generateKey();
          attempts++;
        } while (attempts < 10 && db.prepare('SELECT 1 FROM keys WHERE key = ?').get(newKey));

        insert.run(newKey, tier, note || null);
        keys.push(newKey);
      }
    });

    transaction();

    return res.json({
      success: true,
      message: `Generated ${keys.length} ${tier} keys.`,
      keys,
      tier,
      count: keys.length
    });

  } catch (err) {
    console.error('Generate error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

/**
 * GET /api/admin/keys
 * List all keys with optional filters.
 * Query: ?status=active&tier=1month&page=1&limit=50
 */
app.get('/api/admin/keys', adminAuth, (req, res) => {
  try {
    const { status, tier, page = 1, limit = 50, search } = req.query;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    let where = [];
    let params = [];

    if (status) { where.push('status = ?'); params.push(status); }
    if (tier) { where.push('tier = ?'); params.push(tier); }
    if (search) { where.push('key LIKE ?'); params.push(`%${search}%`); }

    const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const total = db.prepare(`SELECT COUNT(*) as count FROM keys ${whereClause}`).get(...params).count;
    const keys = db.prepare(`SELECT * FROM keys ${whereClause} ORDER BY created_at DESC LIMIT ? OFFSET ?`).all(...params, limitNum, offset);

    return res.json({
      success: true,
      keys,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });

  } catch (err) {
    console.error('List keys error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

/**
 * GET /api/admin/stats
 * Get key statistics.
 */
app.get('/api/admin/stats', adminAuth, (req, res) => {
  try {
    const stats = {
      total: db.prepare('SELECT COUNT(*) as c FROM keys').get().c,
      unused: db.prepare("SELECT COUNT(*) as c FROM keys WHERE status = 'unused'").get().c,
      active: db.prepare("SELECT COUNT(*) as c FROM keys WHERE status = 'active'").get().c,
      expired: db.prepare("SELECT COUNT(*) as c FROM keys WHERE status = 'expired'").get().c,
      revoked: db.prepare("SELECT COUNT(*) as c FROM keys WHERE status = 'revoked'").get().c,
      by_tier: {}
    };

    for (const tier of Object.keys(TIER_DURATIONS)) {
      stats.by_tier[tier] = {
        total: db.prepare('SELECT COUNT(*) as c FROM keys WHERE tier = ?').get(tier).c,
        unused: db.prepare("SELECT COUNT(*) as c FROM keys WHERE tier = ? AND status = 'unused'").get(tier).c,
        active: db.prepare("SELECT COUNT(*) as c FROM keys WHERE tier = ? AND status = 'active'").get(tier).c,
      };
    }

    return res.json({ success: true, stats });

  } catch (err) {
    console.error('Stats error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

/**
 * POST /api/admin/revoke
 * Revoke a specific key.
 * Body: { "key": "ES-XXXX-XXXX-XXXX-XXXX" }
 */
app.post('/api/admin/revoke', adminAuth, (req, res) => {
  try {
    const { key } = req.body;
    if (!key) return res.json({ success: false, error: 'No key provided.' });

    const result = db.prepare("UPDATE keys SET status = 'revoked' WHERE key = ?").run(key.trim().toUpperCase());
    if (result.changes === 0) return res.json({ success: false, error: 'Key not found.' });

    return res.json({ success: true, message: 'Key revoked.' });

  } catch (err) {
    console.error('Revoke error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

/**
 * POST /api/admin/delete
 * Delete keys (bulk or single).
 * Body: { "keys": ["ES-XXXX-XXXX-XXXX-XXXX"] } or { "status": "expired" }
 */
app.post('/api/admin/delete', adminAuth, (req, res) => {
  try {
    const { keys, status } = req.body;

    if (keys && Array.isArray(keys)) {
      const placeholders = keys.map(() => '?').join(',');
      const result = db.prepare(`DELETE FROM keys WHERE key IN (${placeholders})`).run(...keys);
      return res.json({ success: true, message: `Deleted ${result.changes} keys.` });
    }

    if (status) {
      const result = db.prepare('DELETE FROM keys WHERE status = ?').run(status);
      return res.json({ success: true, message: `Deleted ${result.changes} ${status} keys.` });
    }

    return res.json({ success: false, error: 'Provide keys array or status to delete.' });

  } catch (err) {
    console.error('Delete error:', err);
    return res.status(500).json({ success: false, error: 'Server error.' });
  }
});

// ─── Admin Dashboard Route ────────────────────────────────────────
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// ─── Start Server ─────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n  ⚡ Extreme Solutions Key System`);
  console.log(`  ├─ API running on port ${PORT}`);
  console.log(`  ├─ Admin dashboard: http://localhost:${PORT}/admin`);
  console.log(`  └─ Validation endpoint: POST /api/validate\n`);
});
