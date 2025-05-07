#!/bin/bash

# 定义颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 定义安装目录
install_dir="/usr/local/XrayR"

# 检查是否是root用户
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}请使用root用户运行此脚本！\n" && exit 1

# 检查系统 (保持不变)
checkSystem() {
    release=""
    installType=""
    removeType=""
    upgrade=""
    if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
        mkdir -p /etc/yum.repos.d

        if [[ -f "/etc/centos-release" ]]; then
            centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')
            if [[ -z "${centosVersion}" ]] && grep </etc/centos-release -q -i "release 8"; then
                centosVersion=8
            fi
        fi
        release="centos"
        installType='yum -y install'
        removeType='yum -y remove'
        upgrade="yum update -y --skip-broken"
    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "debian" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "debian" || [[ -f "/etc/os-release" ]] && grep </etc/os-release -q -i "ID=debian"; then
        release="debian"
        installType='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        removeType='apt -y autoremove'
    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "ubuntu" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "ubuntu"; then
        release="ubuntu"
        installType='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        removeType='apt -y autoremove'
        if grep </etc/issue -q -i "16."; then
            release=
        fi
    fi
    if [[ -z ${release} ]]; then
        echo -e "${red}无法检测系统版本，请确保使用主流的Linux系统，如CentOS、Debian、Ubuntu！${plain}\n" && exit 1
    fi
}

# 检查架构 (保持不变，但在此脚本中不再用于构建下载链接)
check_arch() {
    case "$(uname -m)" in
    "amd64" | "x86_64")
        arch="64"
        ;;
    "i386" | "i686")
        arch="32"
        ;;
    "armv7l")
        arch="arm32-v7a"
        ;;
    "arm64" | "aarch64")
        arch="arm64-v8a"
        ;;
    *)
        echo -e "${red}Unsupported architecture: $(uname -m)${plain}"
        return 1
        ;;
    esac
    return 0
}

# 安装依赖 (保持不变)
install_depend() {
    if [[ "${release}" == "centos" ]]; then
        ${installType} epel-release
        ${installType} curl unzip tar crontabs
    else
        ${installType} curl unzip tar cron
    fi
    if [[ $? -ne 0 ]]; then
        echo -e "${red}安装依赖失败！${plain}\n" && exit 1
    fi
}

# 检查状态 (保持不变)
check_status() {
    if [[ -f "/etc/systemd/system/XrayR.service" ]]; then
        temp=$(systemctl status XrayR | grep Active | awk '{print $3}')
        if [[ "${temp}" == "running" ]]; then
            echo -e "XrayR 状态：${green}运行中${plain}"
        else
            echo -e "XrayR 状态：${yellow}未运行${plain}"
        fi
    else
        echo -e "XrayR 状态：${plain}未安装${plain}"
    fi
}

# 安装 XrayR (修改核心部分)
install_xrayr() {
    if [[ -d "${install_dir}" ]]; then
        echo -e "${red}检测到您已安装XrayR，请先卸载！${plain}\n" && exit 1
    fi
    checkSystem
    # check_arch # 在指定版本安装时，不再强制检查架构并用于下载链接
    install_depend

    # >>> 修改开始：指定要安装的版本和下载URL <<<
    local version="v0.9.0"
    local download_url="https://github.com/XrayR-project/XrayR/releases/download/v0.9.0/XrayR-linux-64.zip"
    # >>> 修改结束 <<<

    echo -e "开始安装XrayR ${version}"

    mkdir -p ${install_dir}
    cd ${install_dir}

    # 下载指定版本的压缩包
    wget -q -N --no-check-certificate -O XrayR-linux.zip ${download_url}

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载XrayR ${version} 失败，请确保此版本存在且下载链接正确！${plain}\n" && exit 1
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR

    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f

    # 下载服务文件 (保持不变)
    local service_file_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${service_file_url}

    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR

    echo -e "${green}XrayR ${version}${plain} 安装完成，已设置开机自启"

    # 复制配置文件模板 (如果不存在) (保持不变)
    if [[ ! -f /etc/XrayR/config.yml ]]; then
        local config_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/config.yml"
        wget -q -N --no-check-certificate -O /etc/XrayR/config.yml ${config_template_url}
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/XrayR-project/XrayR，配置必要的内容"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 重启成功${plain}"
        else
            echo -e "${red}XrayR 可能启动失败，请稍后使用XrayR log 查看日志信息，若无法启动，则可能更改了配置格式，请前往wiki 查看：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    # 复制其他模板文件 (如果不存在) (保持不变)
    local dns_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/dns.json"
    local route_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/route.json"
    local custom_outbound_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/custom_outbound.json"
    local custom_inbound_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/custom_inbound.json"
    local rulelist_template_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/rulelist"

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        wget -q -N --no-check-certificate -O /etc/XrayR/dns.json ${dns_template_url}
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        wget -q -N --no-check-certificate -O /etc/XrayR/route.json ${route_template_url}
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        wget -q -N --no-check-certificate -O /etc/XrayR/custom_outbound.json ${custom_outbound_template_url}
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        wget -q -N --no-check-certificate -O /etc/XrayR/custom_inbound.json ${custom_inbound_template_url}
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
         wget -q -N --no-check-certificate -O /etc/XrayR/rulelist ${rulelist_template_url}
    fi
     if [[ ! -f /etc/XrayR/geoip.dat ]]; then
         wget -q -N --no-check-certificate -O /etc/XrayR/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    fi
     if [[ ! -f /etc/XrayR/geosite.dat ]]; then
         wget -q -N --no-check-certificate -O /etc/XrayR/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    fi


    # 下载管理脚本 (保持不变)
    local management_script_url="https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.sh"
    curl -o /usr/bin/XrayR -Ls ${management_script_url}
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # 小写兼容
    chmod +x /usr/bin/xrayr

    cd ..
    rm -f install.sh

    echo -e ""
    echo "XrayR 管理脚本使用方法(兼容使用xrayr 命令)："
    echo "启动：XrayR start"
    echo "停止：XrayR stop"
    echo "重启：XrayR restart"
    echo "查看状态：XrayR status"
    echo "查看日志：XrayR log"
    echo "更新：XrayR update" # 注意：此脚本的update功能将失效
    echo "卸载：XrayR uninstall"
    echo ""
    echo "请编辑 /etc/XrayR/config.yml 文件配置您的对接信息。"
}

# 卸载 XrayR (保持不变)
uninstall_xrayr() {
    echo -e "${red}您确定要卸载XrayR吗？[y/N]${plain}"
    read -r uninstall_confirm
    if [[ x"${uninstall_confirm}" = x"y" || x"${uninstall_confirm}" = x"Y" ]]; then
        systemctl stop XrayR
        systemctl disable XrayR
        rm /etc/systemd/system/XrayR.service -f
        systemctl daemon-reload
        systemctl reset-failed
        rm ${install_dir} -rf
        rm /etc/XrayR/ -rf
        rm /usr/bin/XrayR -f
        rm /usr/bin/xrayr -f
        echo -e "${green}XrayR 已成功卸载${plain}\n"
    else
        echo -e "${yellow}已取消卸载${plain}"
    fi
}

# 更新 XrayR (修改提示信息)
update_xrayr() {
    echo -e "${red}此脚本为指定版本安装脚本（v0.9.0），无法用于更新。如需更新到其他版本，请使用对应版本的安装脚本或官方最新脚本。${plain}\n"
}

# 主菜单 (修改菜单选项和提示)
main() {
    clear
    echo "-------------------------------------------"
    echo " XrayR 一键安装脚本 (指定版本 v0.9.0) "
    echo " 脚本版本：自定义 v0.9.0 " # 修改版本信息
    echo " 作者：Coding Assistant (Based on XrayR-project script) " # 添加基于信息
    echo "-------------------------------------------"
    echo -e "当前XrayR状态：$(check_status)"
    echo "-------------------------------------------"
    echo "1. 安装 XrayR (指定版本 v0.9.0)" # 修改选项描述
    echo "2. 卸载 XrayR"
    echo "3. 退出"
    echo "-------------------------------------------"
    read -r num
    case "${num}" in
    1)
        install_xrayr
        ;;
    2)
        uninstall_xrayr
        ;;
    3)
        exit 0
        ;;
    *)
        echo -e "${red}请输入正确的数字${plain}"
        ;;
    esac
}

main
