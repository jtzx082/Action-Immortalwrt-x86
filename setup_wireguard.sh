#!/bin/bash

# 这是一个自动化安装和配置 WireGuard 服务器的脚本。

# --- 全局配置 ---
# 请在此处修改为您服务器的公网网卡名称。
# 您可以使用 `ip a` 或 `ifconfig` 命令来查找它。常见的名称有: eth0, ens3, enp1s0 等。
PUBLIC_INTERFACE="eth0"

# --- 脚本主体 ---

# 如果任何命令执行失败，则立即退出脚本
set -e

echo "🚀 开始 WireGuard 服务器设置..."

# 1. 更新软件包列表并安装 WireGuard
echo "📦 正在更新并安装 WireGuard..."
sudo apt-get update
sudo apt-get install wireguard -y

# 2. 生成服务器密钥
echo "🔑 正在生成服务器密钥..."
# 创建 WireGuard 配置目录
sudo mkdir -p /etc/wireguard
# 设置安全权限
sudo chmod 700 /etc/wireguard
# 生成私钥
SERVER_PRIVATE_KEY=$(wg genkey)
# 从私钥派生出公钥
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

# 3. 创建 WireGuard 配置文件 (wg0.conf)
# 使用 cat 和 heredoc 的方式创建文件，比 nano 更适合脚本化操作
echo "📝 正在创建 wg0.conf 配置文件..."
sudo bash -c "cat > /etc/wireguard/wg0.conf" <<EOF
# 请在Address处修改为您想要的虚拟网卡地址。
[Interface]
Address = 192.168.123.8/24
SaveConfig = true
PrivateKey = $SERVER_PRIVATE_KEY
ListenPort = 51820
PostUp = ufw route allow in on wg0 out on $PUBLIC_INTERFACE
PostUp = iptables -t nat -I POSTROUTING -o $PUBLIC_INTERFACE -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on $PUBLIC_INTERFACE
PreDown = iptables -t nat -D POSTROUTING -o $PUBLIC_INTERFACE -j MASQUERADE
EOF

# 4. 启用 IP 转发
echo "🌐 正在启用 IP 转发功能..."
# 检查是否已存在该配置，避免重复添加
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
fi
# 应用新的内核参数
sudo sysctl -p

# 5. 启动并设置 WireGuard 服务开机自启
echo "▶️ 正在启动并启用 WireGuard 服务..."
sudo systemctl start wg-quick@wg0
sudo systemctl enable wg-quick@wg0

# --- 完成 ---
echo ""
echo "✅ WireGuard 服务器安装配置完成！"
echo "=================================================="
echo "‼️  重要信息：请保存好客户端配置所需的信息 ‼️"
echo "=================================================="
echo "服务器公钥 (Server Public Key): $SERVER_PUBLIC_KEY"
echo "服务器公网地址 (Endpoint): $(curl -s ifconfig.me):51820"
echo "=================================================="
echo ""
echo "下一步，您需要在客户端上配置好后，使用以下命令将客户端添加到服务器："
echo "sudo wg set wg0 peer <客户端的公钥> allowed-ips <分配给客户端的IP>"
echo "例如: sudo wg set wg0 peer ClientPublicKey...= allowed-ips 10.8.0.2/32"
