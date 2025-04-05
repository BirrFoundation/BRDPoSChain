#!/usr/bin/env python3
import json
import getpass
import sys
import os
import binascii
import hashlib

# Optional imports with fallbacks
try:
    from Crypto.Cipher import AES
    have_pycryptodome = True
except ImportError:
    have_pycryptodome = False
    print("⚠️ Warning: pycryptodome module not found. AES decryption will not be available.")

# We'll skip scrypt dependency since it's causing problems
have_scrypt = False

def extract_private_key(keystore_file, password):
    """Extract private key from Ethereum keystore file"""
    
    with open(keystore_file, 'r') as f:
        keystore = json.load(f)
    
    if 'crypto' not in keystore and 'Crypto' in keystore:
        # Geth uses 'Crypto', not 'crypto'
        keystore['crypto'] = keystore['Crypto']
    
    # Get the encryption parameters
    kdf = keystore['crypto']['kdf']
    
    if kdf == 'scrypt' and not have_scrypt:
        print(f"⚠️ This keystore uses scrypt KDF, but the scrypt module is not available.")
        print(f"⚠️ Keystore details for reference:")
        print(json.dumps(keystore, indent=2))
        print("\nPlease try one of these options:")
        print("1. Install scrypt module: pip install scrypt")
        print("2. Use an online Ethereum keystore decryptor with this file (be careful with security)")
        print("3. Export the account using another method in BRDPoS")
        return None
    
    if kdf == 'pbkdf2':
        # Get the key derivation parameters
        salt = binascii.unhexlify(keystore['crypto']['kdfparams']['salt'])
        iterations = keystore['crypto']['kdfparams']['c']
        dklen = keystore['crypto']['kdfparams']['dklen']
        
        # Derive the key
        derived_key = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, iterations, dklen)
    else:
        print(f"⚠️ Unsupported KDF: {kdf}")
        return None
    
    # Get the cipher parameters
    ciphertext = binascii.unhexlify(keystore['crypto']['ciphertext'])
    iv = binascii.unhexlify(keystore['crypto']['cipherparams']['iv'])
    
    # Check the derived key against the MAC
    mac = keystore['crypto']['mac']
    derived_mac = hashlib.sha3_256(derived_key[16:32] + ciphertext).hexdigest()
    
    if derived_mac != mac:
        print("❌ MAC mismatch: Incorrect password or file corruption")
        return None
    
    # Decrypt the private key
    if not have_pycryptodome:
        print("❌ Cannot decrypt without pycryptodome module")
        return None
    
    # Create the AES cipher
    cipher = AES.new(derived_key[:16], AES.MODE_CTR, nonce=b'', initial_value=int.from_bytes(iv, byteorder='big'))
    
    # Decrypt the private key
    private_key = cipher.decrypt(ciphertext)
    
    # Get the address for verification
    ethereum_address = keystore['address']
    
    if ethereum_address.startswith('0x'):
        ethereum_address = ethereum_address[2:]
    
    return {
        'private_key': private_key.hex(),
        'address': ethereum_address
    }

def main():
    # Check for keystore file argument
    if len(sys.argv) > 1:
        keystore_file = sys.argv[1]
    else:
        # Search for keystore files in the default location
        keystore_dir = "./tmp/brdpos-node-fixed/keystore"
        if not os.path.exists(keystore_dir):
            print(f"❌ Keystore directory not found: {keystore_dir}")
            return 1
        
        keystore_files = [os.path.join(keystore_dir, f) for f in os.listdir(keystore_dir) 
                          if os.path.isfile(os.path.join(keystore_dir, f)) and f.startswith('UTC--')]
        
        if not keystore_files:
            print(f"❌ No keystore files found in {keystore_dir}")
            return 1
        
        print("Found keystore files:")
        for i, kf in enumerate(keystore_files, 1):
            print(f"{i}. {os.path.basename(kf)}")
        
        selection = input("Select a keystore file (number): ")
        try:
            index = int(selection) - 1
            if 0 <= index < len(keystore_files):
                keystore_file = keystore_files[index]
            else:
                print("❌ Invalid selection")
                return 1
        except ValueError:
            print("❌ Invalid input")
            return 1
    
    if not os.path.exists(keystore_file):
        print(f"❌ Keystore file not found: {keystore_file}")
        return 1
    
    # Get the password
    password = getpass.getpass("Enter password for keystore: ")
    
    # Extract the private key
    result = extract_private_key(keystore_file, password)
    
    if result:
        print("\n🔑 Successfully extracted private key:")
        print(f"Private Key: {result['private_key']}")
        print(f"Address: 0x{result['address']}")
        print("\nImport this private key into MetaMask.")
        
        # Offer to save to file
        save = input("\nDo you want to save the private key to a file? (y/n): ").lower()
        if save == 'y':
            output_file = input("Enter filename (default: private_key.txt): ") or "private_key.txt"
            with open(output_file, 'w') as f:
                f.write(result['private_key'])
            os.chmod(output_file, 0o600)  # Set file permissions to owner-only
            print(f"Private key saved to {output_file}")
            print("⚠️ Make sure to keep this file secure and delete it when no longer needed!")
    
    return 0 if result else 1

if __name__ == "__main__":
    sys.exit(main()) 