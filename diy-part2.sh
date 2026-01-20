#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# -----------------------------------------------------------------------------
# 1. 预置网络配置 (Network Configuration)
# -----------------------------------------------------------------------------
# 创建自定义配置文件的存放目录（如果不存在）
mkdir -p package/base-files/files/etc/config

# 确保有默认值（防止本地测试时变量为空导致配置错误，这里设为占位符）
: "${PPPOE_USERNAME:=username_placeholder}"
: "${PPPOE_PASSWORD:=password_placeholder}"

# 将你的 network 文件内容写入目标位置
# 解释：EOF 块中的 ${变量} 会被自动替换为环境变量中的真实值
cat > package/base-files/files/etc/config/network <<EOF
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	list ipaddr '127.0.0.1/8'

config globals 'globals'
	option dhcp_default_duid '000492b84759563e4bf19f56ad33825e06d0'
	option ula_prefix 'fd26:e39d:8428::/48'
	option packet_steering '1'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'
	list ports 'eth2'
	list ports 'eth3'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	list ipaddr '10.0.0.1/24'
	option ip6assign '60'

config interface 'wan'
	option device 'eth1'
	option proto 'pppoe'
	option username '${PPPOE_USERNAME}'
	option password '${PPPOE_PASSWORD}'
	option ipv6 'auto'
	option norelease '1'

config interface 'wan6'
	option device 'eth1'
	option proto 'dhcpv6'
EOF

# -----------------------------------------------------------------------------
# 2. 其他原有修改 (Existing Modifications)
# -----------------------------------------------------------------------------

# Modify default IP (由于上面已经直接覆盖了 network 文件，这条 sed 命令实际上不再需要，可以注释掉)
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 修改 root 默认密码为 "password"
# 下面的加密字符串对应明文 "password"
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
