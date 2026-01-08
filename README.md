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
  --snapshot-url ""https://tempo-node-snapshots.tempoxyz.dev/tempo-42429-9007530-1767762022.tar.lz4""Notes:
- `--snapshot-download-to-file` downloads the snapshot to a local file first (supports resume). This needs extra disk space.
- SNAPSHOT_URL="https://tempo-node-snapshots.tempoxyz.dev/tempo-42429-9007530-1767762022.tar.lz4"
  aria2c -c -x 16 -s 16 -k 1M -o snapshot.tar.lz4 "$SNAPSHOT_URL"
  lz4 -dc /root/tempo-node/snapshot.tar.lz4 | tar -xf -
- Snapshots are large (200GB+). 

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
1.sudo stop tempo.service
2.sudo start tempo.service
3.sudo journalctl -u tempo.service

## Expected vs actual
- Expected:
- Actual:

## Logs (most relevant)
Jan 08 13:54:44 strn tempo[750976]: 2026-01-08T13:54:44.864162Z  INFO Executed block range start=9108374 end=9108492 throughput="89.83Mgas/second"
Jan 08 13:54:54 strn tempo[750976]: 2026-01-08T13:54:54.879415Z  INFO Executed block range start=9108493 end=9108661 throughput="122.90Mgas/second"
Jan 08 13:55:01 strn tempo[750976]: 2026-01-08T13:55:01.979200Z  INFO Status connected_peers=2 stage=Execution checkpoint=9107459 target=9361407 stage_progress=92.63%
Jan 08 13:55:04 strn tempo[750976]: 2026-01-08T13:55:04.917979Z  INFO Executed block range start=9108662 end=9108836 throughput="132.70Mgas/second"
Jan 08 13:55:14 strn tempo[750976]: 2026-01-08T13:55:14.943017Z  INFO Executed block range start=9108837 end=9109015 throughput="131.74Mgas/second"
Jan 08 13:55:25 strn tempo[750976]: 2026-01-08T13:55:25.008116Z  INFO Executed block range start=9109016 end=9109200 throughput="134.91Mgas/second"
Jan 08 13:55:26 strn tempo[750976]: 2026-01-08T13:55:26.978638Z  INFO Status connected_peers=2 stage=Execution checkpoint=9107459 target=9361407 stage_progress=92.63%
Jan 08 13:55:35 strn tempo[750976]: 2026-01-08T13:55:35.025139Z  INFO Executed block range start=9109201 end=9109394 throughput="140.61Mgas/second"
Jan 08 13:55:45 strn tempo[750976]: 2026-01-08T13:55:45.037153Z  INFO Executed block range start=9109395 end=9109582 throughput="139.42Mgas/second"
Jan 08 13:55:51 strn tempo[750976]: 2026-01-08T13:55:51.978982Z  INFO Status connected_peers=2 stage=Execution checkpoint=9107459 target=9361407 stage_progress=92.63%
Jan 08 13:55:55 strn tempo[750976]: 2026-01-08T13:55:55.041863Z  INFO Executed block range start=9109583 end=9109778 throughput="137.54Mgas/second"

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
