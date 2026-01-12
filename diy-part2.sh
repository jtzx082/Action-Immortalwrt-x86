#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 1. 修改默认 IP 为 10.0.0.1
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 2. 修改 root 默认密码为 "password"
# 下面的加密字符串对应明文 "password"
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 3. 添加 eth2 和 eth3 到网桥 (通过 uci-defaults 实现)
# 创建一个在首次启动时运行的脚本
mkdir -p package/base-files/files/etc/uci-defaults

cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-network
#!/bin/sh

# 使用 uci 命令将 eth2 和 eth3 添加到 br-lan (通常是 @device[0])
# 这种方式比直接修改文本更安全，因为它会自动处理配置文件格式

uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'

# 提交更改
uci commit network

# 脚本执行完毕后退出（OpenWrt 会自动删除执行成功的 uci-defaults 脚本）
exit 0
EOF

# 赋予脚本执行权限（虽然 uci-defaults 通常不需要，但为了保险）
chmod +x package/base-files/files/etc/uci-defaults/99-custom-network

# 4. (可选) 修改主机名
# sed -i 's/OpenWrt/MyRouter/g' package/base-files/files/bin/config_generate
