#!/bin/bash

################################################################################
# Tempo RPC 节点一键部署脚本
# 功能：自动部署、启动和监控 Tempo RPC 节点
# 官方文档: https://docs.tempo.xyz | https://github.com/tempoxyz/tempo
################################################################################

# 不立即退出，允许错误处理
set +e

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置
REPO_URL="https://github.com/tempoxyz/tempo.git"
INSTALL_DIR="$HOME/tempo-node"
RPC_PORT=8545
SERVICE_NAME="tempo"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查命令
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 安装依赖
install_deps() {
    log "安装系统依赖..."
    if check_cmd apt-get; then
        # 等待 apt 解锁（最多等待2分钟）
        log "检查 apt 锁定状态..."
        WAIT_COUNT=0
        MAX_WAIT=12  # 12次 x 10秒 = 2分钟
        while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
                warn "等待超时（2分钟），apt 仍在锁定中"
                warn "请稍后手动运行: sudo apt-get install -y git curl build-essential pkg-config libssl-dev libclang-dev clang"
                warn "然后重新运行此脚本，或使用参数跳过依赖安装: ./tempo-rpc.sh --skip-deps"
                read -p "是否继续尝试安装？(y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return 1
                fi
                # 再试一次
                WAIT_COUNT=0
            fi
            warn "apt 正在被其他进程使用，等待 10 秒... ($((WAIT_COUNT+1))/$MAX_WAIT)"
            sleep 10
            WAIT_COUNT=$((WAIT_COUNT+1))
        done
        
        log "apt 已解锁，开始安装依赖..."
        sudo apt-get update -qq
        sudo apt-get install -y git curl build-essential pkg-config libssl-dev libclang-dev clang || {
            err "依赖安装失败，请手动运行: sudo apt-get install -y git curl build-essential pkg-config libssl-dev libclang-dev clang"
            return 1
        }
    else
        err "请手动安装: git curl build-essential pkg-config libssl-dev libclang-dev clang"
        return 1
    fi
    return 0
}

# 安装 Rust
install_rust() {
    # 确保加载 Rust 环境
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    if check_cmd rustc && check_cmd cargo; then
        log "Rust 已安装: $(rustc --version)"
        # rustup update 不支持 -q，使用重定向
        rustup update stable >/dev/null 2>&1 || true
        return 0
    fi
    
    log "安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
        err "Rust 安装失败"
        return 1
    }
    
    # 加载 Rust 环境
    source "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
    
    rustup default stable
    return 0
}

# 安装 just
install_just() {
    if check_cmd just; then
        log "just 已安装: $(just --version)"
        return 0
    fi
    
    log "安装 just 构建工具..."
    if check_cmd cargo; then
        cargo install just 2>/dev/null || {
            curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
            export PATH="$HOME/.local/bin:$PATH"
        }
    else
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    if check_cmd just; then
        return 0
    fi
    return 1
}

# 检查编译依赖
check_build_deps() {
    local missing=""
    
    # 检查 libclang
    if ! ldconfig -p 2>/dev/null | grep -q libclang.so; then
        if ! dpkg -l | grep -q "libclang-dev"; then
            missing="$missing libclang-dev"
        fi
    fi
    
    # 检查 clang
    if ! check_cmd clang; then
        missing="$missing clang"
    fi
    
    if [ -n "$missing" ]; then
        err "缺少编译依赖: $missing"
        err "请运行: sudo apt-get install -y$missing"
        err "如果 apt 被锁定，请等待 unattended-upgrade 完成"
        return 1
    fi
    
    return 0
}

# 构建 Tempo
build_tempo() {
    log "准备构建环境..."
    
    # 检查编译依赖
    if ! check_build_deps; then
        err "编译依赖检查失败"
        return 1
    fi
    log "编译依赖检查通过"
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || { err "无法进入目录: $INSTALL_DIR"; return 1; }
    
    # 确保 Rust 环境已加载
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # 验证 cargo 可用
    if ! check_cmd cargo; then
        err "cargo 命令不可用，请检查 Rust 安装"
        err "尝试加载 Rust 环境..."
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
        if ! check_cmd cargo; then
            err "cargo 仍然不可用，请检查 Rust 安装"
            return 1
        fi
    fi
    log "cargo 可用: $(cargo --version)"
    
    # 克隆或更新
    if [ -d "tempo" ]; then
        warn "仓库已存在，更新中..."
        cd tempo || return 1
        git pull -q || warn "更新失败，继续使用现有代码"
    else
        log "克隆 Tempo 仓库..."
        git clone -q "$REPO_URL" tempo || { err "克隆失败"; return 1; }
        cd tempo || return 1
    fi
    
    # 检查是否已经编译过 - 直接查找 tempo 二进制文件
    if [ -f "target/release/tempo" ]; then
        log "发现已编译的二进制文件: target/release/tempo"
        echo "$(pwd)/target/release/tempo"
        return 0
    fi
    log "未找到已编译文件，需要编译"
    
    # 构建
    log "开始编译（可能需要 10-30 分钟）..."
    log "如果编译失败，请检查错误信息并确保所有依赖已安装"
    
    # 检查磁盘空间
    AVAIL_SPACE=$(df -BG "$INSTALL_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAIL_SPACE" -lt 20 ]; then
        warn "警告: 可用磁盘空间 ${AVAIL_SPACE}GB，建议至少 20GB"
    fi
    
    local build_success=false
    local build_output=""
    
    if install_just && [ -f "justfile" ]; then
        log "使用 just 构建..."
        build_output=$(just build-all 2>&1)
        if [ $? -eq 0 ]; then
            build_success=true
            log "just 构建成功"
        else
            warn "just 构建失败，错误信息："
            echo "$build_output" | tail -n 20
            warn "尝试使用 cargo..."
        fi
    fi
    
    if [ "$build_success" = false ]; then
        log "使用 cargo 构建..."
        log "这可能需要较长时间，请耐心等待..."
        
        # 显示编译进度
        build_output=$(cargo build --release 2>&1)
        BUILD_EXIT_CODE=$?
        
        if [ $BUILD_EXIT_CODE -ne 0 ]; then
            err "编译失败！退出码: $BUILD_EXIT_CODE"
            err ""
            err "最后 30 行错误信息："
            echo "$build_output" | tail -n 30
            err ""
            err "常见原因："
            err "  1. 缺少编译依赖（libclang-dev, clang 等）"
            err "  2. 内存不足（需要至少 4GB 可用内存）"
            err "  3. 磁盘空间不足（需要至少 20GB 可用空间）"
            err "  4. 网络问题（需要下载依赖包）"
            err ""
            err "查看完整错误信息，请运行:"
            err "  cd $INSTALL_DIR/tempo"
            err "  cargo build --release"
            return 1
        else
            log "cargo 构建成功"
        fi
    fi
    
    # 查找二进制文件 - 直接查找 tempo
    if [ -f "target/release/tempo" ]; then
        BINARY="target/release/tempo"
        log "编译成功！二进制文件: $BINARY"
        log "文件大小: $(du -h "$BINARY" | cut -f1)"
        echo "$(pwd)/$BINARY"
        return 0
    fi
    
    err "未找到编译后的二进制文件: target/release/tempo"
    err "编译可能未完成，请运行: cd $INSTALL_DIR/tempo && cargo build --release"
    return 1
}

# 创建 systemd 服务
create_service() {
    local binary=$1
    
    # 确保 binary 变量是干净的路径，不包含任何日志输出
    binary=$(echo "$binary" | grep -o '/[^[:space:]]*target/release/tempo' | head -1)
    if [ -z "$binary" ]; then
        binary="$INSTALL_DIR/tempo/target/release/tempo"
    fi
    
    if [ ! -f "$binary" ]; then
        err "二进制文件不存在: $binary"
        return 1
    fi
    
    log "创建 systemd 服务..."
    log "二进制文件: $binary"
    
    mkdir -p "$INSTALL_DIR/data"
    
    # Tempo 需要共识签名密钥和费用接收地址
    # 创建数据目录
    mkdir -p "$INSTALL_DIR/data"
    
    # 生成签名密钥（如果不存在）
    # Tempo 需要 ed25519 私钥，格式为十六进制字符串（64个字符）
    SIGNING_KEY_FILE="$INSTALL_DIR/data/signing-key"
    if [ ! -f "$SIGNING_KEY_FILE" ]; then
        log "生成共识签名密钥..."
        # 生成 32 字节的随机数据，转换为十六进制字符串
        hex_key=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32 | tr -d '\n')
        if [ -z "$hex_key" ]; then
            # 备用方法：使用 dd + od
            hex_key=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c 64)
        fi
        echo "$hex_key" > "$SIGNING_KEY_FILE"
        chmod 600 "$SIGNING_KEY_FILE"
        log "密钥已生成: $SIGNING_KEY_FILE"
    else
        # 检查现有密钥文件格式
        if ! file "$SIGNING_KEY_FILE" | grep -q "text"; then
            warn "现有密钥文件不是文本格式，重新生成..."
            hex_key=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32 | tr -d '\n')
            if [ -z "$hex_key" ]; then
                hex_key=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c 64)
            fi
            echo "$hex_key" > "$SIGNING_KEY_FILE"
            chmod 600 "$SIGNING_KEY_FILE"
        fi
    fi
    
    # 设置费用接收地址（测试网可以使用任意地址）
    FEE_RECIPIENT="0x0000000000000000000000000000000000000000"
    
    # Tempo 使用 `node` 子命令，构建正确的命令
    exec_cmd="$binary node --chain testnet --datadir $INSTALL_DIR/data --http --http.addr 0.0.0.0 --http.port $RPC_PORT --http.corsdomain all --consensus.signing-key $SIGNING_KEY_FILE --consensus.fee-recipient $FEE_RECIPIENT"
    
    log "使用命令: $exec_cmd"
    
    # 确保 exec_cmd 是干净的，不包含任何日志输出
    exec_cmd=$(echo "$exec_cmd" | sed 's/^\[INFO\].*//' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Tempo RPC Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/tempo
ExecStart=$exec_cmd
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}.service
}

# 启动服务
start_service() {
    log "启动服务..."
    sudo systemctl start ${SERVICE_NAME}.service
    sleep 3
    
    if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
        log "服务启动成功！"
        return 0
    else
        err "服务启动失败，查看日志: sudo journalctl -u ${SERVICE_NAME}.service -n 50"
        return 1
    fi
}

# 配置防火墙
setup_firewall() {
    if check_cmd ufw && sudo ufw status | grep -q "Status: active"; then
        log "配置防火墙..."
        sudo ufw allow $RPC_PORT/tcp comment "Tempo RPC" 2>/dev/null || true
    fi
}

# 显示状态
show_status() {
    echo ""
    echo "=========================================="
    log "部署完成！"
    echo "=========================================="
    echo ""
    
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "YOUR_IP")
    
    log "RPC URL: http://${PUBLIC_IP}:${RPC_PORT}"
    echo ""
    log "常用命令:"
    echo "  查看状态: sudo systemctl status ${SERVICE_NAME}.service"
    echo "  查看日志: sudo journalctl -u ${SERVICE_NAME}.service -f"
    echo "  重启服务: sudo systemctl restart ${SERVICE_NAME}.service"
    echo ""
    
    # 检查服务状态
    if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
        log "✓ 节点正在运行"
    else
        warn "✗ 节点未运行，请检查日志"
    fi
}

# 主函数
main() {
    SKIP_DEPS=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            *)
                warn "未知参数: $1"
                shift
                ;;
        esac
    done
    
    echo "=========================================="
    echo "  Tempo RPC 节点一键部署"
    echo "=========================================="
    echo ""
    
    # 检查依赖
    [ ! -f /etc/os-release ] && { err "不支持的操作系统"; exit 1; }
    
    # 安装依赖（除非跳过）
    if [ "$SKIP_DEPS" = false ]; then
        install_deps || { err "依赖安装失败，使用 --skip-deps 跳过"; exit 1; }
    else
        log "跳过依赖安装（使用 --skip-deps）"
        # 检查必要命令是否存在
        if ! check_cmd git || ! check_cmd curl; then
            err "缺少必要命令，请先安装依赖"
            exit 1
        fi
        # 检查编译依赖
        if ! dpkg -l | grep -q "libclang-dev" || ! dpkg -l | grep -q "^ii.*clang"; then
            warn "警告: 未检测到 libclang-dev 或 clang"
            warn "如果编译失败，请运行: sudo apt-get install -y libclang-dev clang"
        fi
    fi
    
    # 安装 Rust
    install_rust || { err "Rust 安装失败"; exit 1; }
    
    # 确保 Rust 环境在 PATH 中
    export PATH="$HOME/.cargo/bin:$PATH"
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # 构建
    log "开始构建 Tempo..."
    build_tempo > /tmp/tempo-build.log 2>&1
    BUILD_EXIT=$?
    BINARY=$(grep "/target/release/tempo" /tmp/tempo-build.log | tail -1)
    
    # 如果没从日志中提取到，直接检查文件
    if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
        if [ -f "$INSTALL_DIR/tempo/target/release/tempo" ]; then
            BINARY="$INSTALL_DIR/tempo/target/release/tempo"
            log "找到二进制文件: $BINARY"
        else
            err "未找到二进制文件"
            err "请检查: ls -lh $INSTALL_DIR/tempo/target/release/tempo"
            exit 1
        fi
    fi
    
    if [ $BUILD_EXIT -ne 0 ] && [ ! -f "$BINARY" ]; then
        err "构建失败"
        exit 1
    fi
    
    log "找到二进制文件: $BINARY"
    
    # 服务化
    create_service "$BINARY" || { err "服务创建失败"; exit 1; }
    setup_firewall
    start_service || { err "服务启动失败"; exit 1; }
    
    # 显示状态
    show_status
}

# 如果直接运行
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

