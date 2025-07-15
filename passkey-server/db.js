const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        user_id BYTEA NOT NULL,
        email VARCHAR(255),
        encrypted_data JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS authenticators (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        credential_id BYTEA NOT NULL,
        credential_public_key BYTEA NOT NULL,
        counter INTEGER NOT NULL,
        credential_device_type VARCHAR(50),
        credential_backed_up BOOLEAN,
        transports TEXT[],
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(credential_id)
      )
    `);

    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
    throw error;
  }
}

async function createUser(username, userId) {
  const result = await pool.query(
    'INSERT INTO users (username, user_id) VALUES ($1, $2) RETURNING *',
    [username, userId]
  );
  return result.rows[0];
}

async function createAnonymousUser(credentialId) {
  // Use credential ID as the username for anonymous users
  const username = `anon_${Buffer.from(credentialId).toString('base64url').substring(0, 16)}`;
  const result = await pool.query(
    'INSERT INTO users (username, user_id) VALUES ($1, $2) RETURNING *',
    [username, credentialId]
  );
  return result.rows[0];
}

async function getUserByUsername(username) {
  const result = await pool.query(
    'SELECT * FROM users WHERE username = $1',
    [username]
  );
  return result.rows[0];
}

async function getUserById(userId) {
  const result = await pool.query(
    'SELECT * FROM users WHERE id = $1',
    [userId]
  );
  return result.rows[0];
}

async function saveAuthenticator(userId, authenticator) {
  const result = await pool.query(
    `INSERT INTO authenticators 
     (user_id, credential_id, credential_public_key, counter, 
      credential_device_type, credential_backed_up, transports)
     VALUES ($1, $2, $3, $4, $5, $6, $7) 
     RETURNING *`,
    [
      userId,
      authenticator.credentialID,
      authenticator.credentialPublicKey,
      authenticator.counter,
      authenticator.credentialDeviceType,
      authenticator.credentialBackedUp,
      authenticator.transports || []
    ]
  );
  return result.rows[0];
}

async function getAuthenticatorsByUserId(userId) {
  const result = await pool.query(
    'SELECT * FROM authenticators WHERE user_id = $1',
    [userId]
  );
  return result.rows.map(row => ({
    credentialID: row.credential_id,
    credentialPublicKey: row.credential_public_key,
    counter: row.counter,
    credentialDeviceType: row.credential_device_type,
    credentialBackedUp: row.credential_backed_up,
    transports: row.transports
  }));
}

async function getAuthenticatorById(credentialId) {
  const result = await pool.query(
    'SELECT * FROM authenticators WHERE credential_id = $1',
    [credentialId]
  );
  
  if (result.rows.length === 0) return null;
  
  const row = result.rows[0];
  return {
    credentialID: row.credential_id,
    credentialPublicKey: row.credential_public_key,
    counter: row.counter || 0,
    credentialDeviceType: row.credential_device_type,
    credentialBackedUp: row.credential_backed_up,
    transports: row.transports || [],
    userId: row.user_id
  };
}

async function updateAuthenticatorCounter(credentialId, counter) {
  await pool.query(
    'UPDATE authenticators SET counter = $1 WHERE credential_id = $2',
    [counter, credentialId]
  );
}

async function updateUserData(userId, data) {
  const { email, encryptedData } = data;
  const result = await pool.query(
    `UPDATE users 
     SET email = COALESCE($2, email), 
         encrypted_data = COALESCE($3, encrypted_data),
         updated_at = CURRENT_TIMESTAMP
     WHERE id = $1 
     RETURNING *`,
    [userId, email, encryptedData]
  );
  return result.rows[0];
}

async function getUserDataByUsername(username) {
  const result = await pool.query(
    `SELECT id, username, email, encrypted_data, created_at, updated_at 
     FROM users 
     WHERE username = $1`,
    [username]
  );
  return result.rows[0];
}

async function getUserByCredentialId(credentialId) {
  const result = await pool.query(
    `SELECT u.* FROM users u 
     JOIN authenticators a ON u.id = a.user_id 
     WHERE a.credential_id = $1`,
    [credentialId]
  );
  return result.rows[0];
}

module.exports = {
  pool,
  initDatabase,
  createUser,
  createAnonymousUser,
  getUserByUsername,
  getUserById,
  getUserByCredentialId,
  saveAuthenticator,
  getAuthenticatorsByUserId,
  getAuthenticatorById,
  updateAuthenticatorCounter,
  updateUserData,
  getUserDataByUsername
};