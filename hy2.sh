#!/usr/bin/env bash
set -e
set -x

# 配置信息（使用正确的带app目录的下载链接）
HYSTERIA_VERSION="v2.6.4"
SERVER_PORT=25522  # 可改为30000+避免冲突
AUTH_PASSWORD="20250930"
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
SNI="www.bing.com"
ALPN="h3"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Hysteria2 部署脚本（彻底移除file命令依赖）"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# 检测服务器架构
arch_name() {
    machine=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [[ "$machine" == *"arm64"* || "$machine" == *"aarch64"* ]]; then
        echo "arm64"
    elif [[ "$machine" == *"x86_64"* || "$machine" == *"amd64"* ]]; then
        echo "amd64"
    else
        echo ""
    fi
}

ARCH=$(arch_name)
if [ -z "$ARCH" ]; then
  echo "❌ 不支持的CPU架构：$(uname -m)"
  exit 1
fi

BIN_NAME="hysteria-linux-${ARCH}"
BIN_PATH="./${BIN_NAME}"

# 清理旧文件，强制重新下载
echo "⏳ 清理旧文件..."
rm -f "$BIN_PATH"

# 下载二进制文件（使用带app目录的正确链接）
URL="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${BIN_NAME}"
echo "⏳ 下载程序：$URL"
if ! curl -L --retry 5 --connect-timeout 30 -o "$BIN_PATH" "$URL"; then
    echo "❌ 下载失败（网络错误），请检查服务器能否访问GitHub"
    exit 1
fi

# 仅通过文件大小验证（正常二进制约10-20MB，设置5MB阈值）
FILE_SIZE=$(wc -c < "$BIN_PATH")
MIN_SIZE=$((5 * 1024 * 1024))  # 5MB
if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
    echo "❌ 下载的文件过小（可能是错误页面），大小：$FILE_SIZE 字节"
    rm -f "$BIN_PATH"
    exit 1
fi

# 赋予执行权限（确认文件有效）
chmod +x "$BIN_PATH"
echo "✅ 程序下载并验证成功（文件大小正常）"

# 生成证书（若不存在，检查openssl是否可用）
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "🔑 生成自签证书..."
    if ! command -v openssl &> /dev/null; then
        echo "❌ 缺少openssl，无法生成证书，请手动上传cert.pem和key.pem"
        exit 1
    fi
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}"
    echo "✅ 证书生成成功"
else
    echo "✅ 证书已存在，跳过生成"
fi

# 生成配置文件
cat > server.yaml <<EOF
listen: ":${SERVER_PORT}"
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

# 获取IP并输出节点链接
SERVER_IP=$(curl -s --max-time 10 https://api.ipify.org || echo "请手动输入服务器IP")
echo "🎉 部署成功！节点信息如下："
echo "IP地址：$SERVER_IP"
echo "端口：$SERVER_PORT"
echo "密码：$AUTH_PASSWORD"
echo "节点链接：hysteria2://${AUTH_PASSWORD}@${SERVER_IP}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}&insecure=true#Hy2-Bing"

# 前台启动Hysteria2
echo "🚀 启动Hysteria2服务器（前台运行）..."
"$BIN_PATH" server -c server.yaml