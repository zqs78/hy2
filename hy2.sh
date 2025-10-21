#!/usr/bin/env bash
set -e
set -x

# 配置信息
HYSTERIA_VERSION="v2.6.4"
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

# 下载二进制文件
URL="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${BIN_NAME}"
echo "⏳ 下载程序：$URL"
if ! curl -L --retry 5 --connect-timeout 30 -o "$BIN_PATH" "$URL"; then
    echo "❌ 下载失败（网络错误），请检查服务器能否访问GitHub"
    exit 1
fi

# 文件大小验证
FILE_SIZE=$(wc -c < "$BIN_PATH")
MIN_SIZE=$((5 * 1024 * 1024))
if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
    echo "❌ 下载的文件过小，大小：$FILE_SIZE 字节"
    rm -f "$BIN_PATH"
    exit 1
fi

# 赋予执行权限
chmod +x "$BIN_PATH"
echo "✅ 程序下载并验证成功"

# 生成证书
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "🔑 生成自签证书..."
    if ! command -v openssl &> /dev/null; then
        echo "❌ 缺少openssl，无法生成证书"
        exit 1
    fi
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}"
    echo "✅ 证书生成成功"
else
    echo "✅ 证书已存在，跳过生成"
fi

# 生成配置文件
cat > server.yaml <<EOF
listen: "0.0.0.0:${SERVER_PORT}"
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

# 获取域名信息（部署后需要手动修改）
SERVER_DOMAIN="你的Koyeb服务域名.koyeb.app"
echo "🎉 部署成功！节点信息如下："
echo "域名：$SERVER_DOMAIN"
echo "端口：$SERVER_PORT"
echo "密码：$AUTH_PASSWORD"
echo "节点链接：hysteria2://${AUTH_PASSWORD}@${SERVER_DOMAIN}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}&insecure=true#Hy2-Koyeb"

# 启动服务
echo "🚀 启动Hysteria2服务器..."
"$BIN_PATH" server -c server.yaml
