#!/usr/bin/env bash
set -euo pipefail

# 本脚本用于把本地 index.html 项目部署到远端静态站点目录。
# 依赖：ssh、rsync（macOS 自带 rsync，一般也有 ssh）

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

HOST="${1:-}"
USER_NAME="${2:-}"
DEST_DIR="${3:-}"
SSH_PORT="${4:-22}"
RESTART_CMD="${5:-}" # 可选：例如 "sudo systemctl restart nginx"

if [[ -z "$HOST" || -z "$USER_NAME" || -z "$DEST_DIR" ]]; then
  echo "用法："
  echo "  ./deploy.sh [--dry-run] <host> <user> <dest_dir> [ssh_port] [restart_cmd]"
  echo "示例："
  echo "  ./deploy.sh 118.178.121.21 sys2546238632+- /var/www/html"
  echo "  ./deploy.sh 118.178.121.21 sys2546238632+- /var/www/html 22 'sudo systemctl restart nginx'"
  exit 1
fi

SRC_DIR="$(pwd)"

SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new)
RSYNC_BASE_OPTS=(
  -a
  --delete
  --links
  --times
  --compress
  --human-readable
  --progress
  --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_BASE_OPTS+=(-n)
fi

# 确保远端目标目录存在（需要能登录到服务器）。
ssh "${SSH_OPTS[@]}" "${USER_NAME}@${HOST}" "mkdir -p '$DEST_DIR'"

# 只部署网站需要的文件，避免把说明文档也暴露到站点目录。
rsync "${RSYNC_BASE_OPTS[@]}" \
  -e "ssh ${SSH_OPTS[*]}" \
  --delete-excluded \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  --exclude "README.md" \
  --exclude "更新说明.md" \
  --exclude "项目说明.txt" \
  --exclude "deploy.sh" \
  --exclude "deploy_prod.sh" \
  "${SRC_DIR}/" \
  "${USER_NAME}@${HOST}:${DEST_DIR}/"

echo "部署完成：${HOST}:${DEST_DIR}"

if [[ -n "$RESTART_CMD" ]]; then
  ssh "${SSH_OPTS[@]}" "${USER_NAME}@${HOST}" "cd '$DEST_DIR' && ${RESTART_CMD}"
  echo "已执行远端重启命令：${RESTART_CMD}"
fi

