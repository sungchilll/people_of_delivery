#!/bin/bash
APP_HOST=$1        # app 서버의 프라이빗 IP
APP_USER=$2        # ec2-user (Amazon Linux)
APP_KEY=$3         # app 서버 ssh 키파일 경로

echo "==== [Bastion → App 서버 SSH] ===="

# 1. App 서버에 필요한 파일 복사 (docker-compose.yml, application.yml)
scp -i "$APP_KEY" -o StrictHostKeyChecking=no /home/${USER}/docker-compose.yml ${APP_USER}@${APP_HOST}:/home/${APP_USER}/
scp -i "$APP_KEY" -o StrictHostKeyChecking=no /home/${USER}/application.yml ${APP_USER}@${APP_HOST}:/home/${APP_USER}/

# 2. App 서버에 SSH로 진입해서 도커 컨테이너 재기동
ssh -i "$APP_KEY" -o StrictHostKeyChecking=no ${APP_USER}@${APP_HOST} << 'EOF'
  cd /home/ec2-user/
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
