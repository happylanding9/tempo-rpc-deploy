# tempo-rpc-deploy（中文说明）

Tempo RPC 节点部署脚本（支持快照快速同步，Tempo **testnet**，chainId **42429**）。

## 这是什么

本仓库提供一个脚本，用于在 Linux 服务器上编译并以 `systemd` 方式运行 Tempo **RPC 节点**，支持：

- RPC 节点正确参数（`--follow`）
- P2P 端口配置（30303 TCP/UDP）
- 快照导入加速同步
- 更稳定的快照下载模式（先下载到文件 + `aria2c` 断点续传）
- 基础防火墙规则（ufw）

## 重要说明

- **RPC 节点一般没有验证者收益**：不参与共识、不出块。
- **P2P 必须对外可达**：否则常见现象 `connected_peers=0`、同步卡住。
- **不要把 8545 裸露公网**：如必须开放，请用防火墙限制来源 IP 或加反代鉴权。

## 端口说明

- **30303/TCP + 30303/UDP**：Execution P2P（同步必须）
- **8545/TCP**：HTTP JSON-RPC（按需开放）
- **9000/TCP**：Metrics（建议仅内网）

## 一键部署（推荐：快照）

先 SSH 登录服务器：

sudo apt-get update -y
sudo apt-get install -y git curl

git clone https://github.com/happylanding9/tempo-rpc-deploy.git
cd tempo-rpc-deploy
chmod +x tempo-rpc.sh### 使用快照（推荐）

sudo bash ./tempo-rpc.sh --snapshot --snapshot-force --snapshot-download-to-file \
  --snapshot-url "https://tempo-node-snapshots.tempoxyz.dev/tempo-42429-9007530-1767762022.tar.lz4"说明：
- `--snapshot-download-to-file` 更稳定（支持断点续传），但需要额外磁盘空间。
- 快照很大（200GB+），**不要放 GitHub**，建议放对象存储。

### 不使用快照

sudo bash ./tempo-rpc.sh## 验证（JSON-RPC 必须用 POST）

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545查看日志：

sudo journalctl -u tempo.service -f## 常见问题

### 1) `net_peerCount = 0x0` / `connected_peers=0`
- 确认云厂商安全组/防火墙开放：
  - 30303/TCP
  - 30303/UDP
- 若启用 ufw，确认规则存在。

### 2) 快照导入相关
- `gzip: stdin: not in gzip format`
  - 你用了 `tar -xzf`，但快照是 `.tar.lz4`，正确是：
   
    lz4 -dc snapshot.tar.lz4 | tar -xf -
    - `curl: (92) HTTP/2 ... INTERNAL_ERROR`
  - 用 `curl --http1.1` 或（推荐）用 `aria2c` 先下载再解压。

### 3) 版本/快照不兼容导致 panic
可能出现：
- `Unsupported TxType identifier: ...`
- `Block deserialization cannot fail ...`

解决建议：
- 升级 Tempo 到 **>= 0.8.1**（推荐 0.8.2）
- 并重新导入最新/兼容快照到干净 datadir

### 4) 同机多实例
默认 Engine/AuthRPC 端口 **8551** 可能冲突。
需要指定不同端口：
- `--authrpc.port <PORT>`
同时调整：
- `--http.port <PORT>`
- `--port <P2P_PORT>` 与 `--discovery.port <P2P_PORT>`

## License

MIT
