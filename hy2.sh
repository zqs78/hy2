#!/bin/bash
echo "Hello from hy2!"
# 你的其他脚本内容

#!/usr/bin/env bash
set -e
set -x

# 配置信息
HYSTERIA_VERSION="v2.6.4"
# 修改点：优先使用 Koyeb 提供的 PORT 环境变量，默认为 25522 用于本地测试
SERVER_PORT="${PORT:-25522}"
AUTH_PASSWORD="20250930"
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
SNI="www.bing.com"
ALPN="h3"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Hysteria2 Koyeb 部署脚本"
echo "平台分配端口为: $SERVER_PORT"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# ... (脚本中间的架构检测、文件下载等部分保持不变) ...

# 生成配置文件（注意：监听地址应为 0.0.0.0 而非 127.0.0.1）
cat > server.yaml <<EOF
listen: "0.0.0.0:${SERVER_PORT}" # 修改点：确保监听所有网络接口
tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: "password"
  password: "${AUTH_PASSWORD}"
bandwidth:
  up: "200mbps"
  down: "200mbps"
quic:
  max_idle_timeout: "10s"
  max_concurrent_streams: 4
  initial_stream_receive_window: 65536
  max_stream_receive_window: 131072
  initial_conn_receive_window: 131072
  max_conn_receive_window: 262144
EOF
echo "✅ 配置文件生成成功"

# 获取IP并输出节点链接（在Koyeb上，通常使用平台分配的子域名）
# 注意：在Koyeb上，通常使用其分配的固定域名，而非服务器IP
SERVER_DOMAIN="你的Koyeb服务域名.koyeb.app" # 部署后需要你手动修改此处
echo "🎉 部署成功！节点信息如下："
echo "域名：$SERVER_DOMAIN"
echo "端口：$SERVER_PORT"
echo "密码：$AUTH_PASSWORD"
echo "节点链接：hysteria2://${AUTH_PASSWORD}@${SERVER_DOMAIN}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}&insecure=true#Hy2-Koyeb"

# 前台启动Hysteria2
echo "🚀 启动Hysteria2服务器..."
"$BIN_PATH" server -c server.yaml
