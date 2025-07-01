#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
# echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' >>feeds.conf.default
echo 'src-git partexp https://github.com/sirpdboy/luci-app-partexp.git;main' >>feeds.conf.default
echo 'src-git netspeedtest https://github.com/sirpdboy/luci-app-netspeedtest.git' >>feeds.conf.default
echo 'src-git netwizard https://github.com/sirpdboy/luci-app-netwizard.git' >>feeds.conf.default
echo 'src-git watchdog https://github.com/sirpdboy/luci-app-watchdog.git' >>feeds.conf.default
echo 'src-git advancedplus https://github.com/sirpdboy/luci-app-advancedplus.git' >>feeds.conf.default
echo 'src-git taskplan https://github.com/sirpdboy/luci-app-taskplan.git' >>feeds.conf.default
echo 'src-git timecontrol https://github.com/sirpdboy/luci-app-timecontrol.git' >>feeds.conf.default
echo 'src-git parentcontrol https://github.com/sirpdboy/luci-app-parentcontrol.git' >>feeds.conf.default
echo 'src-git eqosplus https://github.com/sirpdboy/luci-app-eqosplus.git' >>feeds.conf.default
echo 'src-git poweroffdevice https://github.com/sirpdboy/luci-app-poweroffdevice.git' >>feeds.conf.default
