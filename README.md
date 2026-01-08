# tempo-rpc-deploy

Tempo RPC deployment script with snapshot support (Tempo testnet, chainId 42429).

## What this repo is
This repo provides a one-command deployment script for running a Tempo **RPC node** on Linux using `systemd`, including:
- Proper RPC flags for an RPC node (`--follow`)
- Required P2P port config (30303 TCP/UDP)
- Snapshot import support for faster sync
- Optional "download to file" mode with resume (aria2)

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
chmod +x tempo-rpc.sh

# Recommended: resume-able download mode + force import
sudo bash ./tempo-rpc.sh --snapshot --snapshot-force --snapshot-download-to-file \
  --snapshot-url "<SNAPSHOT_URL>"Notes:
- `--snapshot-download-to-file` downloads the snapshot to a local file first (supports resume). This needs extra disk space.
- Snapshots are large (200GB+). **Do NOT host snapshots on GitHub**. Use object storage (S3/R2/OSS/B2/etc.) and provide a public HTTPS URL.

## Non-snapshot install
sudo bash ./tempo-rpc.sht / Version Mismatch
about: Report sync issues, snapshot incompatibility, genesis mismatch, TxType errors
title: "[RPC][SYNC] <short summary>"
labels: ["bug"]
---

## Summary
Describe the issue in 1–2 sentences.

## Environment
- Network / chain: testnet (chainId 42429)
- Server OS: 
- CPU/RAM/Disk:
- Tempo version: `tempo --version` output:
- Git ref (tag/commit): 
- Snapshot URL used (if any):

## Service command (systemd)
Paste:
sudo systemctl show tempo.service -p ExecStart --no-pager## Steps to reproduce
1.
2.
3.

## Expected vs actual
- Expected:
- Actual:

## Logs (most relevant)
Paste the last ~200 lines around the error/panic:
sudo journalctl -u tempo.service -n 200 --no-pagerIf possible, include filtered output:
sudo journalctl -u tempo.service -n 500 --no-pager | grep -i -E "panic|error|deserial|genesis|Unsupported|TxType|Status|checkpoint|target|latest_block"## RPC checks
### eth_blockNumber
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545### net_peerCount
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545### eth_syncing
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545## Firewall / ports
- 30303/tcp open? 
- 30303/udp open?
- 8545/tcp open? (if public)

# height
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# peers
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

# syncing details
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545Logs:
sudo journalctl -u tempo.service -f## Security notes
If you expose 8545 publicly, consider restricting access (IP allowlist / reverse proxy auth). Many RPC methods can be abused if left open to the internet.

## Common issues
### connected_peers=0 / stuck sync
- Ensure **30303/tcp and 30303/udp** are open in both:
  - server firewall (ufw)
  - cloud security group

### genesis hash mismatch
Example:
`genesis hash in the storage does not match the specified chainspec`

Fix:
- Ensure your service uses `--chain testnet` for chainId 42429.
- Ensure the snapshot matches the chain you are starting.

### Block deserialization / Unsupported TxType
This usually indicates node version vs snapshot incompatibility.
- Try using a snapshot built for your node version, or re-import a newer snapshot.
- If you switched versions/tags, re-import a compatible snapshot into a clean datadir.

## License
MIT
