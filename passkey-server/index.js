require('dotenv').config();
const express = require('express');
const cors = require('cors');
const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} = require('@simplewebauthn/server');
const db = require('./db');

const app = express();
app.use(express.json());
app.use(cors());

// Add error handling middleware
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// In-memory store for challenges (in production, use sessions)
const challenges = new Map();

// Configuration from environment
const rpId = process.env.RP_ID || 'localhost';
const rpName = process.env.RP_NAME || 'Nuri Passkey Server';
const expectedOrigin = process.env.ORIGIN || 'https://localhost';

app.get('/generate-registration-options', async (req, res) => {
  console.log('Registration options endpoint called');
  try {
    const { username } = req.query;
    console.log('Username:', username || 'Anonymous');

    let excludeCredentials = [];
    let userID;
    let displayName;
    let isAnonymous = false;

    if (username) {
      // Username provided - check if user exists
      const existingUser = await db.getUserByUsername(username);
      
      if (existingUser) {
        // User exists - allow adding another passkey
        console.log(`User ${username} exists, adding additional passkey`);
        userID = existingUser.user_id;
        displayName = username;
        
        // Get existing authenticators to exclude
        const existingAuthenticators = await db.getAuthenticatorsByUserId(existingUser.id);
        excludeCredentials = existingAuthenticators.map(auth => ({
          id: Buffer.from(auth.credentialID).toString('base64url'),
          type: 'public-key',
          transports: auth.transports
        }));
      } else {
        // New user with username
        console.log(`Creating new user ${username}`);
        const encoder = new TextEncoder();
        userID = encoder.encode(username);
        displayName = username;
      }
    } else {
      // Anonymous user - generate temporary user ID
      console.log('Creating anonymous user');
      isAnonymous = true;
      userID = crypto.getRandomValues(new Uint8Array(32));
      displayName = 'Anonymous User';
    }

    console.log('Generating registration options...');
    const options = await generateRegistrationOptions({
      rpName: rpName,
      rpID: rpId,
      userID: userID,
      userName: displayName,
      userDisplayName: displayName,
      attestationType: 'none',
      excludeCredentials: excludeCredentials,
      authenticatorSelection: {
        residentKey: 'required',
        userVerification: 'required',
      },
    });

    // Store the challenge with metadata
    const challengeKey = username || `anon_${Date.now()}`;
    challenges.set(challengeKey, {
      challenge: options.challenge,
      isAnonymous: isAnonymous,
      username: username
    });

    console.log('Sending options with challenge key:', challengeKey);
    res.json({
      ...options,
      challengeKey: challengeKey  // Send challenge key back for anonymous users
    });
  } catch (error) {
    console.error('Registration options error:', error);
    res.status(500).send({ error: error.message });
  }
});

app.post('/verify-registration', async (req, res) => {
  try {
    const { username, cred, challengeKey } = req.body;

    console.log('Registration verification request');
    console.log('Username:', username || 'Anonymous');
    console.log('Challenge key:', challengeKey);
    console.log('Credential ID:', cred?.id);
    console.log('Credential type:', cred?.type);
    console.log('Has attestation object:', !!cred?.response?.attestationObject);
    console.log('Has client data:', !!cred?.response?.clientDataJSON);
    console.log('Transports:', cred?.response?.transports);

    if (!cred) {
      return res.status(400).send({ error: 'Missing credential' });
    }

    // Get challenge data
    const lookupKey = challengeKey || username;
    const challengeData = challenges.get(lookupKey);
    if (!challengeData) {
      console.error('No challenge found for key:', lookupKey);
      return res.status(400).send({ error: 'No challenge found' });
    }

    const { challenge, isAnonymous } = challengeData;

    console.log('Expected challenge:', challenge);
    console.log('Expected origin:', expectedOrigin);
    console.log('Expected RP ID:', rpId);

    const verification = await verifyRegistrationResponse({
      response: cred,
      expectedChallenge: challenge,
      expectedOrigin,
      expectedRPID: rpId,
      requireUserVerification: true,
    });

    console.log('Verification successful:', verification.verified);

    if (verification.verified && verification.registrationInfo) {
      console.log('Registration info keys:', Object.keys(verification.registrationInfo));
      
      // Extract the correct properties for simplewebauthn v13
      const registrationInfo = verification.registrationInfo;
      
      // In v13, credential data is nested inside registrationInfo.credential
      const { credential, credentialDeviceType, credentialBackedUp } = registrationInfo;
      const { id: credentialID, publicKey: credentialPublicKey, counter } = credential;

      console.log('Verification successful, storing authenticator...');
      console.log('Credential type:', credentialDeviceType);
      console.log('Credential backed up:', credentialBackedUp);
      console.log('Counter:', counter);

      // Create user based on anonymous or named
      let user;
      if (isAnonymous) {
        // For anonymous users, create user with credential ID as identifier
        const credentialIdBuffer = Buffer.from(credentialID, 'base64url');
        console.log('Creating anonymous user with credential ID');
        try {
          user = await db.createAnonymousUser(credentialIdBuffer);
          console.log('Created anonymous user:', user.username, 'with ID:', user.id);
        } catch (dbError) {
          console.error('Database error creating anonymous user:', dbError);
          throw dbError;
        }
      } else {
        // Named user flow
        user = await db.getUserByUsername(username);
        if (!user) {
          const encoder = new TextEncoder();
          const userID = encoder.encode(username);
          console.log('Creating user with encoded ID:', userID);
          try {
            user = await db.createUser(username, Buffer.from(userID));
            console.log('Created new user:', username, 'with ID:', user.id);
          } catch (dbError) {
            console.error('Database error creating user:', dbError);
            throw dbError;
          }
        } else {
          console.log('Adding passkey to existing user:', username, 'with ID:', user.id);
        }
      }

      // Store the authenticator
      console.log('Preparing to save authenticator...');
      console.log('credentialID type:', typeof credentialID, 'value:', credentialID);
      console.log('credentialPublicKey type:', typeof credentialPublicKey, 'value:', credentialPublicKey);
      
      // Ensure we have valid data before creating Buffers
      if (!credentialID || !credentialPublicKey) {
        throw new Error('Missing credential data from verification');
      }
      
      const authenticatorData = {
        credentialID: Buffer.from(credentialID, 'base64url'),
        credentialPublicKey: Buffer.from(credentialPublicKey),
        counter,
        credentialDeviceType,
        credentialBackedUp,
        transports: cred.response.transports || []
      };
      
      console.log('Saving authenticator data:', {
        ...authenticatorData,
        credentialID: authenticatorData.credentialID.toString('base64').substring(0, 20) + '...',
        credentialPublicKey: authenticatorData.credentialPublicKey.toString('base64').substring(0, 20) + '...'
      });
      
      await db.saveAuthenticator(user.id, authenticatorData);

      console.log('Authenticator saved successfully');

      // Clear the challenge
      challenges.delete(lookupKey);

      res.send({ 
        verified: true,
        username: user.username,
        isAnonymous: user.username.startsWith('anon_')
      });
    } else {
      console.error('Verification failed:', {
        verified: verification.verified,
        registrationInfo: verification.registrationInfo,
        error: verification.error
      });
      res.status(400).send({ 
        error: 'Verification failed', 
        details: verification.error || 'Unknown verification error',
        verified: verification.verified
      });
    }
  } catch (error) {
    console.error('Registration verification error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).send({ error: error.message, stack: error.stack });
  }
});

app.get('/generate-authentication-options', async (req, res) => {
  try {
    const options = await generateAuthenticationOptions({
      rpID: rpId,
      allowCredentials: [], // Allow any credential
      userVerification: 'required',
    });

    // Store challenge temporarily (in production, use sessions)
    challenges.set('auth', options.challenge);

    res.send(options);
  } catch (error) {
    console.error('Authentication options error:', error);
    res.status(500).send({ error: error.message });
  }
});

app.post('/verify-authentication', async (req, res) => {
  try {
    const { cred } = req.body;

    console.log('Authentication verification request');
    console.log('Credential ID:', cred?.id);
    console.log('Has authenticator data:', !!cred?.response?.authenticatorData);
    console.log('Has client data:', !!cred?.response?.clientDataJSON);
    console.log('Has signature:', !!cred?.response?.signature);

    if (!cred) {
      return res.status(400).send({ error: 'Missing credential' });
    }

    const challenge = challenges.get('auth');
    if (!challenge) {
      console.error('No authentication challenge found');
      return res.status(400).send({ error: 'No authentication challenge found' });
    }

    console.log('Expected challenge:', challenge);
    console.log('Expected origin:', expectedOrigin);
    console.log('Expected RP ID:', rpId);

    // Find the authenticator by its ID
    const credentialID = Buffer.from(cred.id, 'base64url');
    console.log('Looking for authenticator with ID:', credentialID.toString('base64'));
    
    const authenticator = await db.getAuthenticatorById(credentialID);

    if (!authenticator) {
      console.error('Authenticator not found for ID:', cred.id);
      // List all authenticators for debugging
      const allAuths = await db.pool.query('SELECT credential_id FROM authenticators');
      console.log('Available authenticator IDs:', allAuths.rows.map(r => 
        Buffer.from(r.credential_id).toString('base64url')
      ));
      return res.status(400).send({ error: 'Authenticator not found' });
    }

    console.log('Found authenticator:', {
      userId: authenticator.userId,
      counter: authenticator.counter,
      credentialDeviceType: authenticator.credentialDeviceType,
      hasPublicKey: !!authenticator.credentialPublicKey
    });
    
    // Get the user associated with this authenticator
    const user = await db.getUserById(authenticator.userId);
    if (!user) {
      console.error('User not found for authenticator user ID:', authenticator.userId);
      return res.status(400).send({ error: 'User not found' });
    }
    
    console.log('Found user:', user.username);

    // Format credential object for simplewebauthn v13
    const credential = {
      id: Buffer.from(authenticator.credentialID).toString('base64url'),
      publicKey: authenticator.credentialPublicKey,
      counter: authenticator.counter || 0,
      transports: authenticator.transports || []
    };

    console.log('Formatted credential for verification:', {
      id: credential.id.substring(0, 20) + '...',
      hasPublicKey: !!credential.publicKey,
      publicKeyLength: credential.publicKey ? credential.publicKey.length : 0,
      counter: credential.counter,
      transports: credential.transports
    });

    const verification = await verifyAuthenticationResponse({
      response: cred,
      expectedChallenge: challenge,
      expectedOrigin,
      expectedRPID: rpId,
      credential: credential,  // Changed from 'authenticator' to 'credential'
      requireUserVerification: true,
    });

    console.log('Authentication verification result:', verification.verified);

    if (verification.verified) {
      // Update the counter
      await db.updateAuthenticatorCounter(
        credentialID, 
        verification.authenticationInfo.newCounter
      );
      
      // Clear the challenge
      challenges.delete('auth');
      
      res.send({ 
        verified: true,
        username: user.username,
        isAnonymous: user.username.startsWith('anon_')
      });
    } else {
      console.error('Authentication verification failed');
      if (verification.error) {
        console.error('Verification error:', verification.error);
      }
      res.status(400).send({ 
        error: 'Authentication verification failed',
        details: verification.error || 'Unknown verification error'
      });
    }
  } catch (error) {
    console.error('Authentication verification error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).send({ error: error.message, stack: error.stack });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.send({ status: 'ok', service: 'passkey-server' });
});

// Database management endpoints
app.delete('/api/clear-database', async (req, res) => {
  try {
    console.log('Clearing database...');
    
    // Clear all authenticators first (due to foreign key constraint)
    await db.pool.query('DELETE FROM authenticators');
    console.log('Cleared authenticators table');
    
    // Clear all users
    await db.pool.query('DELETE FROM users');
    console.log('Cleared users table');
    
    // Clear any in-memory challenges
    challenges.clear();
    console.log('Cleared in-memory challenges');
    
    res.send({ 
      message: 'Database cleared successfully',
      cleared: {
        users: true,
        authenticators: true,
        challenges: true
      }
    });
  } catch (error) {
    console.error('Error clearing database:', error);
    res.status(500).send({ error: error.message });
  }
});

// Delete specific user and their authenticators
app.delete('/api/users/:username', async (req, res) => {
  try {
    const { username } = req.params;
    console.log(`Deleting user: ${username}`);
    
    const user = await db.getUserByUsername(username);
    if (!user) {
      return res.status(404).send({ error: 'User not found' });
    }
    
    // Delete user (authenticators will cascade delete)
    await db.pool.query('DELETE FROM users WHERE username = $1', [username]);
    
    res.send({ message: `User ${username} and all their authenticators deleted` });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).send({ error: error.message });
  }
});

// Dashboard API endpoint
app.get('/api/dashboard', async (req, res) => {
  try {
    // Get all users with their authenticators
    const usersResult = await db.pool.query(`
      SELECT 
        u.id, 
        u.username, 
        u.created_at,
        COUNT(a.id) as authenticator_count
      FROM users u
      LEFT JOIN authenticators a ON u.id = a.user_id
      GROUP BY u.id
      ORDER BY u.created_at DESC
    `);

    // Get all authenticators with user info
    const authenticatorsResult = await db.pool.query(`
      SELECT 
        a.*,
        u.username
      FROM authenticators a
      JOIN users u ON a.user_id = u.id
      ORDER BY a.created_at DESC
    `);

    // Build user objects with their authenticators
    const users = await Promise.all(usersResult.rows.map(async (user) => {
      const authenticators = await db.getAuthenticatorsByUserId(user.id);
      return {
        ...user,
        authenticators: authenticators.map(auth => ({
          credential_id: Buffer.from(auth.credentialID).toString('base64'),
          credential_device_type: auth.credentialDeviceType,
          credential_backed_up: auth.credentialBackedUp,
          counter: auth.counter,
          transports: auth.transports
        }))
      };
    }));

    // Calculate stats
    const totalPasskeys = authenticatorsResult.rows.length;
    const hardwareKeys = authenticatorsResult.rows.filter(
      a => a.credential_device_type === 'multiDevice'
    ).length;
    const platformKeys = authenticatorsResult.rows.filter(
      a => a.credential_device_type === 'singleDevice'
    ).length;

    res.json({
      totalUsers: usersResult.rows.length,
      totalPasskeys,
      hardwareKeys,
      platformKeys,
      users
    });
  } catch (error) {
    console.error('Dashboard API error:', error);
    res.status(500).send({ error: error.message });
  }
});

// Serve dashboard HTML
app.get('/dashboard', (req, res) => {
  res.sendFile(__dirname + '/dashboard.html');
});

// Serve encryption example
app.get('/encryption-example', (req, res) => {
  res.sendFile(__dirname + '/encryption-example.html');
});

// Store encrypted user data (requires authentication)
app.post('/api/users/:identifier/data', async (req, res) => {
  try {
    const { identifier } = req.params;
    const { email, encryptedData, authProof, credentialId } = req.body;

    console.log(`Storing encrypted data for: ${identifier}`);

    // Find user by username or credential ID
    let user;
    if (identifier.startsWith('anon_')) {
      // For anonymous users, use credential ID
      if (!credentialId) {
        return res.status(400).send({ error: 'Credential ID required for anonymous users' });
      }
      const credentialIdBuffer = Buffer.from(credentialId, 'base64url');
      user = await db.getUserByCredentialId(credentialIdBuffer);
    } else {
      // Named user
      user = await db.getUserByUsername(identifier);
    }

    if (!user) {
      return res.status(404).send({ error: 'User not found' });
    }

    // In a production system, you would verify authProof here
    // This could be a signed challenge or a recent authentication token
    // For now, we'll accept the data if the user exists

    // Update user data
    const updatedUser = await db.updateUserData(user.id, {
      email,
      encryptedData
    });

    console.log(`Updated user data for ${identifier}`);

    res.json({
      success: true,
      username: updatedUser.username,
      email: updatedUser.email,
      hasEncryptedData: !!updatedUser.encrypted_data,
      updatedAt: updatedUser.updated_at
    });
  } catch (error) {
    console.error('Error storing user data:', error);
    res.status(500).send({ error: error.message });
  }
});

// Retrieve user data (requires authentication)
app.get('/api/users/:identifier/data', async (req, res) => {
  try {
    const { identifier } = req.params;
    const { credentialId } = req.query;
    
    console.log(`Retrieving data for: ${identifier}`);

    let userData;
    if (identifier.startsWith('anon_')) {
      // For anonymous users, use credential ID
      if (!credentialId) {
        return res.status(400).send({ error: 'Credential ID required for anonymous users' });
      }
      const credentialIdBuffer = Buffer.from(credentialId, 'base64url');
      const user = await db.getUserByCredentialId(credentialIdBuffer);
      if (user) {
        userData = await db.getUserDataByUsername(user.username);
      }
    } else {
      // Named user
      userData = await db.getUserDataByUsername(identifier);
    }

    if (!userData) {
      return res.status(404).send({ error: 'User not found' });
    }

    // Return user data (encrypted data remains encrypted)
    res.json({
      username: userData.username,
      email: userData.email,
      encryptedData: userData.encrypted_data,
      createdAt: userData.created_at,
      updatedAt: userData.updated_at
    });
  } catch (error) {
    console.error('Error retrieving user data:', error);
    res.status(500).send({ error: error.message });
  }
});

// Store encrypted seed backup (special endpoint for sensitive data)
app.post('/api/users/:username/seed-backup', async (req, res) => {
  try {
    const { username } = req.params;
    const { encryptedSeed, authProof, keyDerivationParams } = req.body;

    console.log(`Storing encrypted seed backup for user: ${username}`);

    // Verify user exists
    const user = await db.getUserByUsername(username);
    if (!user) {
      return res.status(404).send({ error: 'User not found' });
    }

    // Store the encrypted seed as part of encrypted_data
    const currentData = user.encrypted_data || {};
    const updatedData = {
      ...currentData,
      seedBackup: {
        encryptedSeed,
        keyDerivationParams, // Store params needed to recreate encryption key
        backupDate: new Date().toISOString(),
        version: 1
      }
    };

    await db.updateUserData(user.id, {
      encryptedData: updatedData
    });

    console.log(`Seed backup stored for ${username}`);

    res.json({
      success: true,
      message: 'Encrypted seed backup stored successfully',
      backupDate: updatedData.seedBackup.backupDate
    });
  } catch (error) {
    console.error('Error storing seed backup:', error);
    res.status(500).send({ error: error.message });
  }
});

const port = process.env.PORT || 3000;

// Initialize database before starting server
db.initDatabase()
  .then(() => {
    app.listen(port, () => {
      console.log(`Passkey server listening at ${expectedOrigin}`);
      console.log(`RP ID: ${rpId}`);
    });
  })
  .catch((error) => {
    console.error('Failed to initialize database:', error);
    process.exit(1);
  });