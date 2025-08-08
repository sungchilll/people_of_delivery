#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <user@host> <path-to-key.pem>"
  exit 1
fi

APP_DEST="$1"           # ex) ec2-user@192.168.2.77
APP_KEY="$2"            # ex) ~/goorm-keypair.pem

# user@host 를 분리
APP_USER="${APP_DEST%@*}"
APP_HOST="${APP_DEST#*@}"
REMOTE_DIR="/home/${APP_USER}"

echo "==== [Bastion → App 서버: ${APP_USER}@${APP_HOST}] ===="

# 1. App 서버에 필요한 파일 복사 (docker-compose.yml, application.yml)
scp -i "${APP_KEY}" -o StrictHostKeyChecking=no docker-compose.yml \
    "${APP_DEST}:${REMOTE_DIR}/"
scp -i "${APP_KEY}" -o StrictHostKeyChecking=no application.yml \
    "${APP_DEST}:${REMOTE_DIR}/"

# 2. App 서버에 SSH로 진입해서 도커 컨테이너 재기동
ssh -i "${APP_KEY}" -o StrictHostKeyChecking=no "${APP_DEST}" << EOF
  set -euo pipefail
  cd "${REMOTE_DIR}"
  echo "===== DOCKER DEPLOY START ====="

  #— JDK 21 설치 (Amazon Corretto 21)
  if ! java -version 2>&1 | grep -q "Corretto"; then
    sudo yum update -y
    sudo yum install -y java-21-amazon-corretto-devel
    echo 'export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto.x86_64' \
      | sudo tee /etc/profile.d/jdk21.sh
    sudo chmod +x /etc/profile.d/jdk21.sh
    source /etc/profile.d/jdk21.sh
  fi

  # 도커/도커컴포즈 설치 (최초 1회만 필요)
  if ! command -v docker &> /dev/null; then
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
  fi

  if ! command -v docker-compose &> /dev/null; then
    sudo curl -L \
      "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi

  # 컨테이너 배포
  sudo docker-compose down || true
  sudo docker pull sungchilll/peopleofdelivery:latest
  sudo docker-compose up -d

  # (필요시 로그)
  sudo docker ps -a
  sudo docker image prune -a -f
  echo "===== DOCKER DEPLOY END ====="
EOF

echo "==== [배포 완료!] ===="
