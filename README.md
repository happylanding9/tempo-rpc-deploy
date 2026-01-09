# tempo-rpc-deploy

Tempo RPC deployment script with snapshot support (Tempo **testnet**, chainId **42429**).

## What this repo is

This repo provides a one-command deployment script for running a Tempo **RPC node** on Linux using `systemd`, including:

- Proper RPC flags for an RPC node (`--follow`)
- Required P2P port config (30303 TCP/UDP)
- Snapshot import support for faster sync
- Optional **download-to-file** mode with resume (aria2)

## Requirements

- Ubuntu 20.04+ (recommended)
- CPU/RAM/Disk: recommended **4 vCPU / 16GB RAM / 1TB SSD+**
- Open ports:
  - **30303/tcp + 30303/udp** (required for P2P sync)
  - **8545/tcp** (optional; only if you want public RPC)

## Quick start (snapshot mode recommended)

SSH into your server:

sudo apt-get update -y
sudo apt-get install -y git curl

git clone https://github.com/happylanding9/tempo-rpc-deploy.git
cd tempo-rpc-deploy
chmod +x tempo-rpc.sh### Deploy with snapshot (recommended)

# Recommended: resume-able download mode + force import
sudo bash ./tempo-rpc.sh --snapshot --snapshot-force --snapshot-download-to-file \
  --snapshot-url "https://tempo-node-snapshots.tempoxyz.dev/tempo-42429-9007530-1767762022.tar.lz4"Notes:
- `--snapshot-download-to-file` downloads the snapshot to a local file first (supports resume). This needs extra disk space.
- Snapshots are large (200GB+). **Do NOT host snapshots on GitHub**. Use object storage (S3/R2/OSS/B2/etc.) and provide a public HTTPS URL.
- The script creates and starts a `systemd` service: `tempo.service`.

### Deploy without snapshot

sudo bash ./tempo-rpc.sh## Verify

### Local checks

# Height
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Peers
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

# Syncing details
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545### Logs

sudo journalctl -u tempo.service -f## Security notes

If you expose 8545 publicly, consider restricting access (IP allowlist / reverse proxy auth). Many RPC methods can be abused if left open to the internet.

## Common issues

### `connected_peers=0` / stuck sync

- Ensure **30303/tcp** and **30303/udp** are open in:
  - server firewall (e.g., ufw)
  - cloud security group / security rules

### `genesis hash mismatch`

Example:
`genesis hash in the storage does not match the specified chainspec`

Fix:
- Ensure your service uses `--chain testnet` for chainId 42429.
- Ensure the snapshot matches the chain you are starting.

### `Block deserialization` / `Unsupported TxType`

This usually indicates node version vs snapshot incompatibility.
- Try using a snapshot built for your node version, or re-import a newer snapshot.
- If you switched versions/tags, re-import a compatible snapshot into a clean datadir.

### Running multiple instances on the same host

You must avoid port conflicts. In particular, the default Engine/AuthRPC port (8551) can conflict.

Use a different port with:
- `--authrpc.port <PORT>`

And also adjust:
- `--http.port <PORT>`
- `--port <P2P_PORT>` and `--discovery.port <P2P_PORT>`

## License

MIT
