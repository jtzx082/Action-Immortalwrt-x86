#!/bin/bash
#
# DIY Part 2: 通过 uci-defaults 实现自定义设置
#

# 创建 uci-defaults 目录
mkdir -p package/base-files/files/etc/uci-defaults

# 生成 99-custom-settings 脚本
# 注意：使用 'EOF' (带单引号) 是为了防止 $ 符号在编译机被错误解析
# 这样你的原始脚本内容会被原封不动地写入到固件中

cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

# === 1. 网络配置 (你的原始代码) ===
uci set network.lan.ipaddr='10.0.0.1'
uci set network.lan.netmask='255.255.255.0'

# 绑定 LAN 口 (eth0 + eth2 + eth3)
uci set network.@device[0].ports='eth0'
uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'

# 自动配置 WAN 口 (eth1)
# 检测 eth1 是否存在，存在则配置为 WAN
if [ -d "/sys/class/net/eth1" ]; then
    uci delete network.wan 2>/dev/null
    uci delete network.wan6 2>/dev/null
    
    uci set network.wan=interface
    uci set network.wan.device='eth1'
    uci set network.wan.proto='dhcp'
    
    # 修复防火墙区域 (确保 WAN 口在 wan 区域)
    # 先尝试删除旧的关联(防止报错)，再添加新的
    uci delete firewall.@zone[1].network 2>/dev/null
    uci add_list firewall.@zone[1].network='wan'
    uci add_list firewall.@zone[1].network='wan6'
fi

# === 2. 系统设置 (已移入此处) ===
# 设置 root 密码为 password
# 在路由器内部运行时，passwd 命令是有效的
echo -e "password\npassword" | passwd root

# 允许 Root 登录 SSH
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'

# === 3. 应用并保存更改 ===
uci commit network
uci commit firewall
uci commit dropbear

exit 0
EOF

# 赋予脚本执行权限
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings

echo "DIY Part 2: Custom uci-defaults script created successfully."
