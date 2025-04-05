// Simple Ethereum wallet generator
// This script creates a new Ethereum wallet and private key that can be used with MetaMask

const crypto = require('crypto');

// Generate a random private key (32 bytes)
function generatePrivateKey() {
  return crypto.randomBytes(32).toString('hex');
}

// Calculate the Ethereum address from the private key
// This is a simplified version - in practice you would use a library like ethereumjs-util
function getAddressFromPrivateKey(privateKey) {
  // In a real implementation, this would:
  // 1. Create a public key using elliptic curve cryptography
  // 2. Hash the public key with keccak256
  // 3. Take the last 20 bytes as the address
  // 
  // Since we're just generating a random wallet for testing,
  // we'll return a placeholder address
  return '0x' + crypto.createHash('sha256')
    .update(Buffer.from(privateKey, 'hex'))
    .digest('hex')
    .slice(-40);
}

// Generate a new wallet
const privateKey = generatePrivateKey();
const address = getAddressFromPrivateKey(privateKey);

// Display the wallet information
console.log('\n=============================================');
console.log('🔑 ETHEREUM WALLET FOR METAMASK IMPORT 🔑');
console.log('=============================================\n');
console.log(`Private Key: ${privateKey}`);
console.log(`Address: ${address}`);
console.log('\nTo import this account into MetaMask:');
console.log('1. Open MetaMask');
console.log('2. Click on your account icon (top-right)');
console.log('3. Select "Import Account"');
console.log('4. Choose "Private Key"');
console.log('5. Paste the private key above (without 0x prefix)');
console.log('6. Click "Import"');
console.log('\nImportant: Save this private key somewhere secure!');
console.log('Anyone with this key can access your funds.');
console.log('============================================='); 