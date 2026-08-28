#!/bin/bash

# 1. 安装必要的依赖环境
if [ -x "$(command -v apt-get)" ]; then
    apt-get update && apt-get install -y wget unzip
elif [ -x "$(command -v yum)" ]; then
    yum install -y wget unzip
fi

# 2. 创建主程序目录和配置目录
mkdir -p /usr/local/XrayR/
mkdir -p /etc/XrayR/

# 3. 下载并解压指定版本的 XrayR
echo "正在下载 XrayR v0.9.0..."
wget -qO /tmp/XrayR.zip https://github.com/XrayR-project/XrayR/releases/download/v0.9.0/XrayR-linux-64.zip
unzip -qo /tmp/XrayR.zip -d /usr/local/XrayR/
rm -f /tmp/XrayR.zip

# 4. 赋予主程序执行权限
chmod +x /usr/local/XrayR/XrayR

# 5. 确保配置文件存在 (如果不存在则创建一个空文件，防止报错)
if [ ! -f /etc/XrayR/config.yml ]; then
    touch /etc/XrayR/config.yml
    echo "注意: 已创建空的 /etc/XrayR/config.yml，请在启动后填入真实配置。"
fi

# 6. 写入 systemd 服务文件
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

# 7. 重载 systemd、设置开机自启并启动服务
systemctl daemon-reload
systemctl enable XrayR
systemctl restart XrayR

# 8. 打印当前服务运行状态
echo -e "\n--- XrayR 服务状态 ---"
systemctl status XrayR --no-pager
