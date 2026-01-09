# tempo-rpc-deploy

Tempo RPC node deployment script with snapshot support (Tempo **testnet**, chainId **42429**).

## What this repo is

This repo provides a one-command script to build and run a Tempo **RPC node** on Linux with `systemd`, including:

- Correct RPC node flags (`--follow`)
- P2P port configuration (30303 TCP/UDP)
- Snapshot import for faster sync
- More reliable snapshot download mode (download-to-file + resume via `aria2c`)
- Basic firewall rules (ufw) for required ports

## Important notes

- **Running an RPC node does not equal validator rewards.** RPC nodes do not participate in consensus / block production.
- **P2P must be reachable** or you will see `connected_peers=0` and sync may stall.
- **Do NOT expose port 8545 to the public internet** unless you restrict access (IP allowlist / reverse proxy auth).

## Ports

- **30303/TCP + 30303/UDP**: Execution P2P (required for syncing)
- **8545/TCP**: HTTP JSON-RPC (optional; expose only if needed)
- **9000/TCP**: Metrics (recommended internal-only)

## Quick start (recommended: snapshot)

SSH into your server:

sudo apt-get update -y
sudo apt-get install -y git curl

git clone https://github.com/happylanding9/tempo-rpc-deploy.git
cd tempo-rpc-deploy
chmod +x tempo-rpc.sh### Snapshot deploy (recommended)

sudo bash ./tempo-rpc.sh --snapshot --snapshot-force --snapshot-download-to-file \
  --snapshot-url "https://tempo-node-snapshots.tempoxyz.dev/tempo-42429-9007530-1767762022.tar.lz4"Notes:
- `--snapshot-download-to-file` is more stable (resume supported) but needs extra disk space.
- Snapshots are huge (200GB+). **Do not host snapshots on GitHub**. Use object storage.

### Deploy without snapshot

sudo bash ./tempo-rpc.sh## Verify (JSON-RPC uses POST)

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545Logs:

sudo journalctl -u tempo.service -f## Common troubleshooting

### 1) `net_peerCount = 0x0` / `connected_peers=0`
- Ensure **30303/TCP** and **30303/UDP** are open in:
  - `ufw` (if enabled)
  - cloud security group / firewall

### 2) Snapshot import errors
- `gzip: stdin: not in gzip format`
  - You used `tar -xzf`, but the snapshot is `.tar.lz4`. Use:
   
    lz4 -dc snapshot.tar.lz4 | tar -xf -
    - `curl: (92) HTTP/2 ... INTERNAL_ERROR`
  - Use `curl --http1.1` or (recommended) `aria2c` download-to-file mode.

### 3) Version / snapshot incompatibility (panic)
Symptoms may include:
- `Unsupported TxType identifier: ...`
- `Block deserialization cannot fail ...`

Fix:
- Upgrade Tempo to **>= 0.8.1** (0.8.2 recommended), and/or
- Re-import a compatible / latest snapshot into a clean datadir.

### 4) Running multiple instances on the same host
You must avoid port conflicts. The default Engine/AuthRPC port **8551** can conflict.
Use:
- `--authrpc.port <PORT>`
and also change:
- `--http.port <PORT>`
- `--port <P2P_PORT>` and `--discovery.port <P2P_PORT>`

## License

MIT
