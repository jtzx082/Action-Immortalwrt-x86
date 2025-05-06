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

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 创建目标文件夹
mkdir -p ./files/etc/config

# 写入 network 配置文件
cat <<'EOF' > ./files/etc/config/network
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option packet_steering '1'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'
        option ipv6 '0'

config interface 'lan'
	option device 'eth0'
	option proto 'static'
	option ipaddr '10.10.10.66'
	option netmask '255.255.255.0'
	option gateway '10.10.10.1'
	list dns '10.10.10.1'
	option delegate '0'

config interface 'vpn0'
	option proto 'none'
	option device 'tun0'
EOF

# 写入 dhcp 配置文件
cat <<'EOF' > ./files/etc/config/dhcp
config dnsmasq
	option domainneeded '1'
	option localise_queries '1'
	option rebind_protection '1'
	option rebind_localhost '1'
	option local '/lan/'
	option domain 'lan'
	option expandhosts '1'
	option min_cache_ttl '3600'
	option use_stale_cache '3600'
	option cachesize '8000'
	option nonegcache '1'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'
	option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
	option localservice '1'
	option ednspacket_max '1232'
	option filter_aaaa '1'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '150'
	option leasetime '12h'
	option dhcpv4 'server'
	option ignore '1'

config dhcp 'wan'
	option interface 'wan'
	option ignore '1'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'
EOF

 # 写入 firewall 配置文件
cat <<'EOF' > ./files/etc/config/firewall
config defaults                                                                                                                                                                                                                      
        option input 'ACCEPT'                                                                                                                                                                                                        
        option output 'ACCEPT'                                                                                                                                                                                                       
        option forward 'ACCEPT'
	option flow_offloading '1'
                                                                                                                                                                                                                                     
config zone                                                                                                                                                                                                                          
        option name 'lan'                                                                                                                                                                                                            
        list network 'lan'                                                                                                                                                                                                           
        option input 'ACCEPT'                                                                                                                                                                                                        
        option output 'ACCEPT'                                                                                                                                                                                                       
        option forward 'ACCEPT'                                                                                                                                                                                                      
        option masq '1'                                                                                                                                                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                     
config zone 'vpn'                                                                                                                                                                                                                    
        option name 'vpn'                                                                                                                                                                                                            
        option input 'ACCEPT'                                                                                                                                                                                                        
        option forward 'ACCEPT'                                                                                                                                                                                                      
        option output 'ACCEPT'                                                                                                                                                                                                       
        option masq '1'
	option network 'vpn0'
                                                            
config forwarding 'vpntowan'     
        option src 'vpn'                        
        option dest 'wan' 
                             
config forwarding 'vpntolan'                    
        option src 'vpn'     
        option dest 'lan'      
                              
config forwarding 'lantovpn' 
        option src 'lan'       
        option dest 'vpn'
EOF
