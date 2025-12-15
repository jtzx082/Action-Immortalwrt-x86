#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 路径定义
AGH_DIR="/opt/AdGuardHome"
DDNS_GO_DIR="/opt/ddns-go"
MIHOMO_DIR="/etc/mihomo"
MIHOMO_RUN_DIR="$MIHOMO_DIR/run"
MIHOMO_BIN="/usr/bin/mihomo"
ZASHBOARD_DIR="$MIHOMO_DIR/ui/zashboard"
RESOLVED_CONF="/etc/systemd/resolved.conf.d/adguardhome.conf"

# 依赖检查标志
DEPENDENCIES_CHECKED=false

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 必须使用 root 权限运行此脚本。${PLAIN}"
    echo -e "请使用: sudo $0"
    exit 1
fi

# 检查架构
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}错误: 此脚本仅支持 x86_64 (amd64) 架构。当前架构: $ARCH${PLAIN}"
    exit 1
fi

# CPU 微架构检测函数
check_cpu_arch() {
    local flags=$(grep -m1 "^flags" /proc/cpuinfo)
    if echo "$flags" | grep -q "avx512f" && echo "$flags" | grep -q "avx512bw" && echo "$flags" | grep -q "avx512cd" && echo "$flags" | grep -q "avx512dq" && echo "$flags" | grep -q "avx512vl"; then
        echo "v4"
    elif echo "$flags" | grep -q "avx2" && echo "$flags" | grep -q "bmi2"; then
        echo "v3"
    elif echo "$flags" | grep -q "sse4_2"; then
        echo "v2"
    else
        echo "v1"
    fi
}

# 安装必要依赖
install_dependencies() {
    if [ "$DEPENDENCIES_CHECKED" = true ]; then return; fi
    echo -e "${BLUE}正在检查并安装必要依赖 (curl, wget, tar, unzip, jq)...${PLAIN}"
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update -y > /dev/null 2>&1
        apt-get install -y curl wget tar unzip jq > /dev/null 2>&1
    elif [ -x "$(command -v yum)" ]; then
        yum install -y curl wget tar unzip jq > /dev/null 2>&1
    else
        echo -e "${YELLOW}警告: 未检测到 apt 或 yum，请手动确保安装了 curl, wget, tar, unzip, jq。${PLAIN}"
    fi
    DEPENDENCIES_CHECKED=true
}

# 状态检查函数
check_status() {
    # Check AGH
    if systemctl is-active --quiet AdGuardHome; then
        AGH_STATUS="${GREEN}已运行${PLAIN}"
    elif [ -f "$AGH_DIR/AdGuardHome" ]; then
        AGH_STATUS="${YELLOW}已安装未运行${PLAIN}"
    else
        AGH_STATUS="${RED}未安装${PLAIN}"
    fi

    # Check Mihomo
    if systemctl is-active --quiet mihomo; then
        MIHOMO_STATUS="${GREEN}已运行${PLAIN}"
    elif [ -f "$MIHOMO_BIN" ]; then
        MIHOMO_STATUS="${YELLOW}已安装未运行${PLAIN}"
    else
        MIHOMO_STATUS="${RED}未安装${PLAIN}"
    fi

    # Check ddns-go
    if systemctl is-active --quiet ddns-go; then
        DDNS_STATUS="${GREEN}已运行${PLAIN}"
    elif [ -f "$DDNS_GO_DIR/ddns-go" ]; then
        DDNS_STATUS="${YELLOW}已安装未运行${PLAIN}"
    else
        DDNS_STATUS="${RED}未安装${PLAIN}"
    fi
}

# ================= 安装/更新 核心逻辑 =================

# 1. 安装 AdGuardHome
install_agh() {
    echo -e "${BLUE}>>> 开始安装/更新 AdGuardHome...${PLAIN}"
    if lsof -i :53 | grep -q "systemd-resolved"; then
        echo -e "${YELLOW}检测到 systemd-resolved 正在占用 53 端口。${PLAIN}"
        echo -e "建议稍后在主菜单使用 '修复 53 端口占用' 功能，否则 AGH 无法正常工作。"
        sleep 2
    fi
    cd /tmp
    wget -O AdGuardHome_linux_amd64.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接。${PLAIN}"
        return
    fi
    
    # 停止服务以进行覆盖
    systemctl stop AdGuardHome > /dev/null 2>&1
    
    tar -zxvf AdGuardHome_linux_amd64.tar.gz -C /opt/ > /dev/null
    rm AdGuardHome_linux_amd64.tar.gz
    
    cd $AGH_DIR
    ./AdGuardHome -s install > /dev/null 2>&1
    # 如果已经是 install 状态，上面的命令可能报错，忽略即可，确保服务启动
    systemctl restart AdGuardHome

    echo -e "${GREEN}AdGuardHome 安装/更新完成！${PLAIN}"
    echo -e "管理面板地址: http://YOUR_IP:3000"
}

# 2. 安装 Mihomo + Zdashboard
install_mihomo() {
    echo -e "${BLUE}>>> 准备安装/更新 Mihomo Core...${PLAIN}"
    CPU_ARCH_LEVEL=$(check_cpu_arch)
    echo -e "检测到 CPU 微架构级别: ${GREEN}amd64-${CPU_ARCH_LEVEL}${PLAIN}"
    
    echo -e "请选择 Mihomo 核心版本:"
    echo -e "  1. ${GREEN}官方版${PLAIN} (MetaCubeX/mihomo) - 稳定，通用"
    echo -e "  2. ${YELLOW}Smart版${PLAIN} (vernesong/mihomo)  - 支持 LightGBM 智能分组"
    read -p "请输入选项 [1-2] (默认1): " core_version
    [[ -z "$core_version" ]] && core_version=1

    local download_url=""
    local jq_filter=""
    local model_downloaded=false
    mkdir -p $MIHOMO_DIR

    if [[ "$core_version" == "2" ]]; then
        # Smart 版
        echo -e "${BLUE}正在获取 Smart 版最新链接...${PLAIN}"
        if [[ "$CPU_ARCH_LEVEL" == "v1" ]]; then
            jq_filter='select(.name | contains("linux-amd64") and contains("smart") and contains(".gz") and (contains("v2")|not) and (contains("v3")|not) and (contains("v4")|not))'
        else
            jq_filter="select(.name | contains(\"linux-amd64-${CPU_ARCH_LEVEL}\") and contains(\"smart\") and contains(\".gz\"))"
        fi
        download_url=$(curl -s https://api.github.com/repos/vernesong/mihomo/releases | jq -r ".[0].assets[] | $jq_filter | .browser_download_url" | head -n 1)

        # 降级处理
        if [ -z "$download_url" ] && [ "$CPU_ARCH_LEVEL" != "v1" ]; then
            echo -e "${YELLOW}未找到对应架构专版，尝试下载通用版...${PLAIN}"
            jq_filter='select(.name | contains("linux-amd64") and contains("smart") and contains(".gz") and (contains("v2")|not) and (contains("v3")|not))'
            download_url=$(curl -s https://api.github.com/repos/vernesong/mihomo/releases | jq -r ".[0].assets[] | $jq_filter | .browser_download_url" | head -n 1)
        fi
        
        # LightGBM Model 更新逻辑
        if [ -n "$download_url" ]; then
            echo -e ""
            echo -e "${YELLOW}是否下载/更新 LightGBM Model?${PLAIN}"
            echo -e "  1. Model-large.bin (30MB)"
            echo -e "  2. Model-middle.bin (14MB)"
            echo -e "  3. Model.bin (5MB)"
            echo -e "  4. 不下载/不更新"
            read -p "请选择 [1-4] (默认4): " model_choice
            local model_src_name=""
            case $model_choice in
                1) model_src_name="Model-large.bin" ;;
                2) model_src_name="Model-middle.bin" ;;
                3) model_src_name="Model.bin" ;;
                *) echo "跳过模型处理。" ;;
            esac
            if [ -n "$model_src_name" ]; then
                mkdir -p "$MIHOMO_RUN_DIR"
                echo -e "${BLUE}正在下载 $model_src_name 并重命名为 Model.bin ...${PLAIN}"
                wget -O "$MIHOMO_RUN_DIR/Model.bin" "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/$model_src_name"
                [[ $? -eq 0 ]] && model_downloaded=true || echo -e "${RED}模型下载失败。${PLAIN}"
            fi
        fi
    else
        # 官方版
        echo -e "${BLUE}正在获取 官方版最新链接...${PLAIN}"
        if [[ "$CPU_ARCH_LEVEL" == "v1" ]]; then
            jq_filter='select(.name | contains("linux-amd64") and contains(".gz") and (contains("v2")|not) and (contains("v3")|not) and (contains("compatible")|not))'
        else
            jq_filter="select(.name | contains(\"linux-amd64-${CPU_ARCH_LEVEL}\") and contains(\".gz\") and (contains(\"compatible\")|not))"
        fi
        download_url=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | jq -r ".assets[] | $jq_filter | .browser_download_url" | head -n 1)
        # 降级
        if [ -z "$download_url" ] && [ "$CPU_ARCH_LEVEL" != "v1" ]; then
             jq_filter='select(.name | contains("linux-amd64") and contains(".gz") and (contains("v2")|not) and (contains("v3")|not) and (contains("compatible")|not))'
             download_url=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | jq -r ".assets[] | $jq_filter | .browser_download_url" | head -n 1)
        fi
    fi
    
    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        echo -e "${RED}下载链接获取失败。${PLAIN}"
        return
    fi

    echo -e "下载链接: $download_url"
    
    # 停止服务以覆盖文件
    systemctl stop mihomo > /dev/null 2>&1
    
    wget -O /tmp/mihomo.gz "$download_url"
    gzip -d /tmp/mihomo.gz
    mv /tmp/mihomo $MIHOMO_BIN
    chmod +x $MIHOMO_BIN

    # 只有配置文件不存在时才生成，更新时不覆盖
    if [ ! -f "$MIHOMO_DIR/config.yaml" ]; then
        echo -e "${YELLOW}生成默认 config.yaml...${PLAIN}"
        cat > $MIHOMO_DIR/config.yaml <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
external-ui: ui/zashboard
secret: ""
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
EOF
    fi

    install_zdashboard_only "no_restart"

    cat > /etc/systemd/system/mihomo.service <<EOF
[Unit]
Description=Mihomo Daemon
After=network.target
[Service]
Type=simple
Restart=always
ExecStart=$MIHOMO_BIN -d $MIHOMO_DIR
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable mihomo
    systemctl restart mihomo
    echo -e "${GREEN}Mihomo + Zdashboard 安装/更新完成！${PLAIN}"
    echo -e "Mihomo 面板地址: http://YOUR_IP:9090/ui/"
    if [ "$model_downloaded" = true ]; then
        echo -e "${YELLOW}提示: 模型已更新。在 config.yaml 中请配置: model: \"run/Model.bin\"${PLAIN}"
    fi
}

# 3. 安装 ddns-go
install_ddns_go() {
    echo -e "${BLUE}>>> 开始安装/更新 ddns-go...${PLAIN}"
    
    local download_url=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | jq -r '.assets[] | select(.name | contains("linux_x86_64") and contains(".tar.gz")) | .browser_download_url')
    
    if [ -z "$download_url" ]; then
        echo -e "${RED}无法获取 ddns-go 下载链接。${PLAIN}"
        return
    fi

    echo -e "下载链接: $download_url"
    
    systemctl stop ddns-go > /dev/null 2>&1
    
    mkdir -p $DDNS_GO_DIR
    wget -O /tmp/ddns-go.tar.gz "$download_url"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败。${PLAIN}"
        return
    fi

    tar -zxvf /tmp/ddns-go.tar.gz -C $DDNS_GO_DIR > /dev/null
    rm /tmp/ddns-go.tar.gz
    
    cd $DDNS_GO_DIR
    ./ddns-go -s install > /dev/null 2>&1
    systemctl restart ddns-go

    echo -e "${GREEN}ddns-go 安装/更新完成！${PLAIN}"
    echo -e "管理面板地址: http://YOUR_IP:9876"
}

# ================= 辅助 & 卸载 =================

# 辅助: 单独安装 Zdashboard
install_zdashboard_only() {
    mkdir -p $MIHOMO_DIR/ui
    cd /tmp
    wget -O zdashboard.zip https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip
    if [ $? -eq 0 ]; then
        unzip -o zdashboard.zip > /dev/null
        rm -rf $ZASHBOARD_DIR
        mv zashboard-gh-pages $ZASHBOARD_DIR
        rm zdashboard.zip
        [ -f "$MIHOMO_DIR/config.yaml" ] && sed -i 's|external-ui:.*|external-ui: ui/zashboard|g' $MIHOMO_DIR/config.yaml
        if [ "$1" != "no_restart" ]; then
            systemctl restart mihomo
            echo -e "${GREEN}Zdashboard 已重新部署。${PLAIN}"
        fi
    else
        echo -e "${RED}Zdashboard 下载失败。${PLAIN}"
    fi
}

# 辅助: 还原 Port 53
revert_port53_fix() {
    if [ -f "$RESOLVED_CONF" ]; then
        rm "$RESOLVED_CONF"
        if [ -f "/etc/resolv.conf.backup" ]; then
            rm /etc/resolv.conf
            mv /etc/resolv.conf.backup /etc/resolv.conf
        fi
        systemctl reload-or-restart systemd-resolved
        echo -e "${GREEN}Systemd-resolved 配置已还原。${PLAIN}"
    fi
}

# 4. 卸载 AdGuardHome
uninstall_agh() {
    echo -e "${YELLOW}正在卸载 AdGuardHome...${PLAIN}"
    if [ -d "$AGH_DIR" ]; then
        cd $AGH_DIR
        ./AdGuardHome -s uninstall > /dev/null 2>&1
        cd ..
    else
        systemctl stop AdGuardHome > /dev/null 2>&1
        systemctl disable AdGuardHome > /dev/null 2>&1
        rm /etc/systemd/system/AdGuardHome.service > /dev/null 2>&1
    fi
    echo -e "${RED}是否删除 AdGuardHome 数据文件 (/opt/AdGuardHome)? [y/N]${PLAIN}"
    read -p "请输入: " clean_conf
    [[ "$clean_conf" =~ ^[yY]$ ]] && rm -rf "$AGH_DIR" && echo -e "文件已删除。"

    if [ -f "$RESOLVED_CONF" ]; then
        echo -e "${RED}是否还原 Systemd-resolved (53端口)? [y/N]${PLAIN}"
        read -p "请输入: " revert_conf
        [[ "$revert_conf" =~ ^[yY]$ ]] && revert_port53_fix
    fi
    systemctl daemon-reload
    echo -e "${GREEN}AdGuardHome 卸载完成。${PLAIN}"
}

# 5. 卸载 Mihomo
uninstall_mihomo() {
    echo -e "${YELLOW}正在卸载 Mihomo...${PLAIN}"
    systemctl stop mihomo
    systemctl disable mihomo
    rm /etc/systemd/system/mihomo.service > /dev/null 2>&1
    rm $MIHOMO_BIN > /dev/null 2>&1
    systemctl daemon-reload
    echo -e "${RED}是否删除 Mihomo 配置文件 (/etc/mihomo)? [y/N]${PLAIN}"
    read -p "请输入: " clean_conf
    [[ "$clean_conf" =~ ^[yY]$ ]] && rm -rf "$MIHOMO_DIR" && echo -e "配置已删除。"
    rm -f /tmp/mihomo.gz
    echo -e "${GREEN}Mihomo 卸载完成。${PLAIN}"
}

# 6. 卸载 ddns-go
uninstall_ddns_go() {
    echo -e "${YELLOW}正在卸载 ddns-go...${PLAIN}"
    if [ -d "$DDNS_GO_DIR" ]; then
        cd $DDNS_GO_DIR
        ./ddns-go -s uninstall > /dev/null 2>&1
        cd ..
    else
        systemctl stop ddns-go > /dev/null 2>&1
        systemctl disable ddns-go > /dev/null 2>&1
    fi
    
    echo -e "${RED}是否删除 ddns-go 配置文件和目录 (/opt/ddns-go)? [y/N]${PLAIN}"
    read -p "请输入: " clean_conf
    if [[ "$clean_conf" =~ ^[yY]$ ]]; then
        rm -rf "$DDNS_GO_DIR"
        echo -e "${GREEN}文件已清理。${PLAIN}"
    fi
    
    systemctl daemon-reload
    echo -e "${GREEN}ddns-go 卸载完成。${PLAIN}"
}

# 单独卸载 Zdashboard
uninstall_zdashboard() {
    rm -rf "$ZASHBOARD_DIR"
    echo -e "${GREEN}Zdashboard 已删除。${PLAIN}"
    read -p "重启 Mihomo? (y/n): " rst
    [[ "$rst" == "y" ]] && systemctl restart mihomo
}

# 修复 53 端口
fix_port53() {
    mkdir -p /etc/systemd/resolved.conf.d/
    cat > "$RESOLVED_CONF" <<EOF
[Resolve]
DNS=127.0.0.1
DNSStubListener=no
EOF
    if [ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ] && [ ! -f /etc/resolv.conf.backup ]; then
        mv /etc/resolv.conf /etc/resolv.conf.backup
    fi
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl reload-or-restart systemd-resolved
    echo -e "${GREEN}修复完成！${PLAIN}"
}

# ================= 检查更新菜单 =================

check_updates_menu() {
    echo -e "${BLUE}>>> 正在获取 GitHub 最新版本信息，请稍候...${PLAIN}"
    
    # 获取 AdGuardHome 版本
    local agh_local="未安装"
    [ -f "$AGH_DIR/AdGuardHome" ] && agh_local=$($AGH_DIR/AdGuardHome --version 2>/dev/null | head -n 1)
    local agh_remote=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | jq -r .tag_name)

    # 获取 ddns-go 版本
    local ddns_local="未安装"
    [ -f "$DDNS_GO_DIR/ddns-go" ] && ddns_local=$($DDNS_GO_DIR/ddns-go -v 2>/dev/null | head -n 1)
    local ddns_remote=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | jq -r .tag_name)

    # 获取 Mihomo 版本 (本地)
    local mihomo_local="未安装"
    [ -f "$MIHOMO_BIN" ] && mihomo_local=$($MIHOMO_BIN -v 2>/dev/null | head -n 1 | cut -d ' ' -f 3)
    # Mihomo Remote 比较复杂，只显示官方 Latest Tag 供参考
    local mihomo_remote=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | jq -r .tag_name)

    clear
    echo -e "#############################################################"
    echo -e "#                  组件版本检查与更新                       #"
    echo -e "#############################################################"
    echo -e ""
    echo -e " 1. AdGuardHome"
    echo -e "    本地: ${YELLOW}$agh_local${PLAIN}"
    echo -e "    远程: ${GREEN}$agh_remote${PLAIN}"
    echo -e ""
    echo -e " 2. Mihomo (Core)"
    echo -e "    本地: ${YELLOW}$mihomo_local${PLAIN}"
    echo -e "    远程: ${GREEN}$mihomo_remote${PLAIN} (官方Latest)"
    echo -e "    * Smart版请直接选择更新，脚本会自动抓取最新Smart构建"
    echo -e ""
    echo -e " 3. ddns-go"
    echo -e "    本地: ${YELLOW}$ddns_local${PLAIN}"
    echo -e "    远程: ${GREEN}$ddns_remote${PLAIN}"
    echo -e ""
    echo -e " ------------------------------------------------------------"
    echo -e " Please choose update action:"
    echo -e " a. 更新 AdGuardHome"
    echo -e " b. 更新 Mihomo + Model.bin (可重选版本)"
    echo -e " c. 更新 ddns-go"
    echo -e " 0. 返回主菜单"
    echo -e ""
    
    read -p " 请输入选项: " up_choice
    case $up_choice in
        a) install_agh; read -p "按回车继续..." ;;
        b) install_mihomo; read -p "按回车继续..." ;;
        c) install_ddns_go; read -p "按回车继续..." ;;
        0) return ;;
        *) echo -e "${RED}无效选项${PLAIN}"; sleep 1 ;;
    esac
}


# 脚本入口
install_dependencies

# 主菜单循环
while true; do
    check_status
    echo -e "#############################################################"
    echo -e "#           全能一键安装脚本 (AGH + Mihomo + DDNS)          #"
    echo -e "#############################################################"
    echo -e ""
    echo -e " --- 安装选项 ---"
    echo -e " 1. 安装 AdGuardHome            [状态: ${AGH_STATUS}]"
    echo -e " 2. 安装 Mihomo + Zdashboard    [状态: ${MIHOMO_STATUS}]"
    echo -e " 3. 安装 ddns-go                [状态: ${DDNS_STATUS}]"
    echo -e ""
    echo -e " --- 卸载选项 ---"
    echo -e " 4. 卸载 AdGuardHome"
    echo -e " 5. 卸载 Mihomo (全套)"
    echo -e " 6. 卸载 ddns-go"
    echo -e ""
    echo -e " --- 维护选项 ---"
    echo -e " 7. 修复 53 端口占用"
    echo -e " 8. 单独卸载 Zdashboard"
    echo -e " 9. 检查并更新组件 (NEW!)"
    echo -e " 0. 退出"
    echo -e ""
    read -p " 请输入选项 [0-9]: " choice

    case $choice in
        1) install_agh ;;
        2) install_mihomo ;;
        3) install_ddns_go ;;
        4) uninstall_agh ;;
        5) uninstall_mihomo ;;
        6) uninstall_ddns_go ;;
        7) fix_port53 ;;
        8) uninstall_zdashboard ;;
        9) check_updates_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项。${PLAIN}" ;;
    esac
    read -p "按回车键继续..."
    clear
done
