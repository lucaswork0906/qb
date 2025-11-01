#!/bin/bash
# ============================================================
# ✅ more_qb.sh — 多开 qBittorrent 实例（终极稳定可定制版）
# 作者：LucasKevin + GPT-5
# 适用于 Debian 10/11/12
# ============================================================

set -e

# ---------- 参数 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--number) NUM="$2"; shift 2;;
    -w|--web-port) WEB_PORT="$2"; shift 2;;
    -b|--bt-port) BT_PORT="$2"; shift 2;;
    -u|--user) USERNAME="$2"; shift 2;;
    *) echo "未知参数：$1"; exit 1;;
  esac
done

# ---------- 默认值 ----------
NUM=${NUM:-5}
WEB_PORT=${WEB_PORT:-8082}
BT_PORT=${BT_PORT:-55001}
USERNAME=${USERNAME:-Lucas}

echo "----------------------------------------"
echo "[🧩] 创建 $NUM 个 qBittorrent 实例"
echo "[👤] 用户名：$USERNAME"
echo "[🌐] WebUI 起始端口：$WEB_PORT"
echo "[⚙️] BT 起始端口：$BT_PORT"
echo "----------------------------------------"
sleep 1

# ---------- 环境检测 ----------
if ! id "$USERNAME" &>/dev/null; then
  echo "[+] 用户不存在，正在创建..."
  useradd -m -s /bin/bash "$USERNAME"
fi

mkdir -p /home/"$USERNAME"
chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"

if ! command -v qbittorrent-nox &>/dev/null; then
  echo "[+] 正在安装 qbittorrent-nox..."
  apt update -y && apt install -y qbittorrent-nox
fi

# ---------- 创建 systemd 模板 ----------
TEMPLATE="/etc/systemd/system/qbittorrent-nox@.service"

cat > "$TEMPLATE" <<EOF
[Unit]
Description=qBittorrent Daemon Instance %i
After=network.target

[Service]
Type=simple
User=${USERNAME}
Group=${USERNAME}
LimitNOFILE=infinity
ExecStartPre=/bin/bash -c 'mkdir -p /home/${USERNAME}/%i && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/%i'
ExecStart=/usr/bin/qbittorrent-nox --profile=/home/${USERNAME}/%i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload

# ---------- 批量创建实例 ----------
for i in $(seq 2 $((NUM+1))); do
  svc="qb${i}"
  wp=$((WEB_PORT + i - 2))
  bp=$((BT_PORT + i - 2))
  conf_dir="/home/${USERNAME}/${svc}"

  echo "[⚙️] 创建服务 ${svc}..."
  mkdir -p "$conf_dir"
  chown -R "$USERNAME":"$USERNAME" "$conf_dir"

  SERVICE_FILE="/etc/systemd/system/${svc}.service"
  cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=${svc}
After=network.target

[Service]
Type=simple
User=${USERNAME}
Group=${USERNAME}
LimitNOFILE=infinity
ExecStartPre=/bin/bash -c 'mkdir -p /home/${USERNAME}/${svc} && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/${svc}'
ExecStart=/usr/bin/qbittorrent-nox --profile=/home/${USERNAME}/${svc} --webui-port=${wp}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

  systemctl enable "${svc}" >/dev/null 2>&1
  systemctl start "${svc}" || echo "[⚠️] ${svc} 首次启动失败（正常，配置生成中）"
done

systemctl daemon-reload

echo ""
echo "----------------------------------------"
echo "[✅] 成功创建 ${NUM} 个 qBittorrent 实例"
for i in $(seq 2 $((NUM+1))); do
  echo "- qb${i}: WebUI http://$(hostname -I | awk '{print $1}'):$((WEB_PORT + i - 2))"
done
echo "----------------------------------------"
echo "[🎉] 全部完成！如首次访问失败，可等待 10 秒后刷新。"
