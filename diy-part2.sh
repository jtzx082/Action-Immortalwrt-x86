#!/bin/sh

# === 1. 网络配置 (默认 IP: 10.0.0.1) ===
uci set network.lan.ipaddr='10.0.0.1'
uci set network.lan.netmask='255.255.255.0'

# 绑定 LAN 口 (eth0 + eth2 + eth3)
uci set network.@device[0].ports='eth0'
uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'

# 自动配置 WAN 口 (eth1)
# 检测 eth1 是否存在，存在则配置为 WAN
[ -d "/sys/class/net/eth1" ] && {
    uci delete network.wan 2>/dev/null
    uci delete network.wan6 2>/dev/null
    uci set network.wan=interface
    uci set network.wan.device='eth1'
    uci set network.wan.proto='dhcp'
    uci add_list firewall.@zone[1].network='wan'
}

# === 2. 系统设置 ===
# 设置 root 密码为 password
echo -e "password\npassword" | passwd root
# 允许 Root 登录 SSH
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'

# === 3. Nikki/Sing-box 兼容性处理 ===
# 赋予规则库权限
chmod 644 /usr/share/nikki/*.db
# 建立 nikki -> sing-box 的软链接
[ ! -f /usr/bin/nikki ] && ln -s /usr/bin/sing-box /usr/bin/nikki

# === 4. 应用并保存更改 ===
uci commit network
uci commit dropbear
exit 0
