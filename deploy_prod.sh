#!/usr/bin/env bash
set -euo pipefail

# 一键部署到生产服务器（已预置你的服务器信息）
HOST="118.178.121.21"
USER_NAME="root"
DEST_DIR="/var/www/mysite"
SSH_PORT="22"

if ! command -v expect >/dev/null 2>&1; then
  echo "缺少 expect，请先安装后再执行。"
  echo "macOS 可执行：brew install expect"
  exit 1
fi

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN="1"
else
  DRY_RUN="0"
fi

# 默认密码按你提供的信息填写；可手动输入覆盖。
DEFAULT_PASSWORD="sys2546238632+-"
if [[ -n "${DEPLOY_PASSWORD:-}" ]]; then
  PASSWORD="${DEPLOY_PASSWORD}"
else
  read -r -s -p "请输入服务器密码（回车使用默认）: " INPUT_PASSWORD
  echo
  PASSWORD="${INPUT_PASSWORD:-$DEFAULT_PASSWORD}"
fi

SRC_DIR="$(pwd)"
if [[ ! -f "${SRC_DIR}/index.html" ]]; then
  echo "请在项目根目录执行本脚本（当前目录缺少 index.html）"
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  RSYNC_DRY="-n"
  echo "当前为演练模式，不会真正写入服务器。"
else
  RSYNC_DRY=""
fi

EXPECT_SCRIPT="$(mktemp)"
cat > "$EXPECT_SCRIPT" <<'EOF'
set timeout -1
set host [lindex $argv 0]
set user [lindex $argv 1]
set pass [lindex $argv 2]
set dest [lindex $argv 3]
set src [lindex $argv 4]
set port [lindex $argv 5]
set dry  [lindex $argv 6]

proc run_with_password {cmd pass} {
  eval spawn $cmd
  expect {
    "*yes/no*" { send "yes\r"; exp_continue }
    "*password:*" { send "$pass\r"; exp_continue }
    eof
  }
}

set mkdir_cmd [list ssh -p $port -o StrictHostKeyChecking=accept-new "$user@$host" "mkdir -p '$dest'"]
run_with_password $mkdir_cmd $pass

set rsync_cmd [list rsync -a --delete --links --times --compress --human-readable --progress --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r]
if {$dry == "1"} {
  lappend rsync_cmd -n
}
lappend rsync_cmd -e "ssh -p $port -o StrictHostKeyChecking=accept-new"
lappend rsync_cmd --delete-excluded --exclude ".git/" --exclude ".DS_Store" --exclude "README.md" --exclude "更新说明.md" --exclude "项目说明.txt" --exclude "deploy.sh" --exclude "deploy_prod.sh"
lappend rsync_cmd "$src/" "$user@$host:$dest/"
run_with_password $rsync_cmd $pass

set reload_cmd [list ssh -p $port -o StrictHostKeyChecking=accept-new "$user@$host" "nginx -s reload"]
run_with_password $reload_cmd $pass
EOF

expect "$EXPECT_SCRIPT" "$HOST" "$USER_NAME" "$PASSWORD" "$DEST_DIR" "$SRC_DIR" "$SSH_PORT" "$DRY_RUN"
rm -f "$EXPECT_SCRIPT"

echo "部署完成：${USER_NAME}@${HOST}:${DEST_DIR}"
echo "Nginx 已重载（nginx -s reload）"

