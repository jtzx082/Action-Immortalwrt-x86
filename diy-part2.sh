#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 1. 修改默认 IP 为 10.0.0.1 (这个依然用 sed，因为最简单且已验证成功)
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 2. 创建一个 "首次启动脚本"
# 这个脚本会在刷机后第一次开机时自动运行，负责：修改密码、添加网口
mkdir -p package/base-files/files/etc/uci-defaults

cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# --- A. 修改 Root 密码 ---
# 直接调用 passwd 命令修改，比修改 shadow 文件更稳
# -e 允许 echo 输出换行符，模拟用户输入两次密码
echo -e "password\npassword" | passwd root

# --- B. 添加 eth2 和 eth3 到网桥 ---
# 使用 uci 命令配置，自动适配 formatting
uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'
uci commit network

# --- 脚本结束清理 ---
exit 0
EOF

# 赋予脚本执行权限
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings

# 3. (可选) 修复默认主题或其他杂项
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
