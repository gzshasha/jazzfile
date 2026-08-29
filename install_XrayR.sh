#!/bin/bash

echo "=========================================="
echo "       XrayR v0.9.0 一键安装脚本 (修复版)    "
echo "=========================================="

# 1. 安装必要的依赖环境
echo -e "\n[1/7] 安装依赖环境 (wget, unzip)..."
if [ -x "$(command -v apt-get)" ]; then
    apt-get update -y && apt-get install -y wget unzip
elif [ -x "$(command -v yum)" ]; then
    yum install -y wget unzip
fi

# 2. 创建目录
echo -e "\n[2/7] 创建目录..."
mkdir -p /usr/local/XrayR/
mkdir -p /etc/XrayR/

# 3. 下载并解压 XrayR
echo -e "\n[3/7] 下载并解压 XrayR v0.9.0..."
wget -qO /tmp/XrayR.zip https://github.com/XrayR-project/XrayR/releases/download/v0.9.0/XrayR-linux-64.zip
unzip -qo /tmp/XrayR.zip -d /usr/local/XrayR/
rm -f /tmp/XrayR.zip
chmod +x /usr/local/XrayR/XrayR

# 4. 复制默认配置文件到 /etc/XrayR/ (解决配置为空的问题)
echo -e "\n[4/7] 初始化配置文件..."
\cp -f /usr/local/XrayR/config.yml /etc/XrayR/config.yml
\cp -f /usr/local/XrayR/*.json /etc/XrayR/ 2>/dev/null
\cp -f /usr/local/XrayR/*.dat /etc/XrayR/ 2>/dev/null
echo "默认配置文件已成功复制到 /etc/XrayR/ 目录下。"

# 5. 写入快捷管理命令 (解决 xrayr 404 报错)
echo -e "\n[5/7] 创建快捷管理命令 (xrayr)..."
rm -f /usr/bin/xrayr /usr/bin/XrayR
cat > /usr/bin/xrayr << 'EOF'
#!/bin/bash
case "$1" in
    start) systemctl start XrayR ;;
    stop) systemctl stop XrayR ;;
    restart) systemctl restart XrayR ;;
    status) systemctl status XrayR ;;
    log) journalctl -u XrayR -f ;;
    *) echo "用法: xrayr {start|stop|restart|status|log}" ;;
esac
EOF
chmod +x /usr/bin/xrayr

# 6. 写入 systemd 服务文件
echo -e "\n[6/7] 配置 systemd 服务..."
cat > /etc/systemd/system/XrayR.service << "EOF"
[Unit]
Description=XrayR Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
WorkingDirectory=/usr/local/XrayR/
Environment="XRAY_VMESS_AEAD_FORCED=false"
ExecStart=/usr/local/XrayR/XrayR --config /etc/XrayR/config.yml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务 (同时处理可能存在的 masked 状态)
echo -e "\n[7/7] 启动服务并设置开机自启..."
systemctl unmask XrayR 2>/dev/null
systemctl daemon-reload
systemctl enable XrayR
systemctl restart XrayR

echo -e "\n=========================================="
echo "安装完成！"
echo "配置文件路径: /etc/XrayR/config.yml"
echo "快捷命令已生效，请使用 xrayr {start|stop|restart|status|log} 管理服务。"
echo "请尽快修改 config.yml 填入你的面板对接信息，然后运行 xrayr restart 重启生效。"
echo "=========================================="
