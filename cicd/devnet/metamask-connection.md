# Connecting to BRDPoS Chain with MetaMask

## Network Information

Use these details to add BRDPoS Chain (ID: 3669) to your MetaMask:

- **Network Name**: BRDPoS Chain
- **Chain ID**: 3669
- **Currency Symbol**: BRC
- **RPC URL**: http://localhost:8651
- **Block Explorer URL**: (leave empty)

## Step-by-Step Instructions

1. Open MetaMask and click on the network dropdown at the top
2. Click "Add Network"
3. Click "Add a network manually" (at the bottom)
4. Fill in the fields using the information above
5. Click "Save"

## Import Your Account

To import an existing account:

1. In MetaMask, click on your account icon
2. Click "Import Account"
3. Select "Private Key" as the type
4. Extract your private key using the backup-keys.sh script:
   ```
   ./backup-keys.sh
   ```
   Choose option 3 to export all private keys
5. Copy the private key (starts with 0x) and paste it into MetaMask
6. Click "Import"

## Troubleshooting

- Make sure your BRDPoS node is running before connecting
- If you're accessing from another device, replace "localhost" with your computer's IP address
- For remote access, you may need to adjust firewall settings to allow access to port 8651

## Security Warning

⚠️ This is a development chain with chain ID 3669. Never use your real Ethereum/mainnet private keys or send real assets to addresses on this chain. 