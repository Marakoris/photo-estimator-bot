#!/bin/bash

set -e

echo "🚀 Развертывание Photo Estimator Bot..."

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Запустите с правами root: sudo ./deploy.sh"
   exit 1
fi

PROJECT_DIR="/root/photo-estimator-bot"
REPO_URL="https://github.com/Marakoris/photo-estimator-bot.git"

echo "📦 Установка зависимостей..."
apt update
apt install -y python3 python3-venv python3-pip git

echo "📥 Клонирование репозитория..."
git clone $REPO_URL $PROJECT_DIR
cd $PROJECT_DIR

echo "🐍 Создание виртуального окружения..."
python3 -m venv gpt-bot-env
source gpt-bot-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "⚙️ Настройка .env файла..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        cat > .env << 'EOF'
OPENROUTER_API_KEY=your_key_here
VK_API_TOKEN=your_token_here
TELEGRAM_BOT_TOKEN=your_telegram_token
TELEGRAM_CHAT_ID=your_chat_id
EOF
    fi
fi

echo "🔧 Настройка служб..."
# Создаем службы с правильными путями
cat > /etc/systemd/system/gpt-bot.service << EOF
[Unit]
Description=VK GPT Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/gpt-bot-env/bin
ExecStart=$PROJECT_DIR/gpt-bot-env/bin/python $PROJECT_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpt-web.service << EOF
[Unit]
Description=Web API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/gpt-bot-env/bin
ExecStart=$PROJECT_DIR/gpt-bot-env/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 web_api:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpt-bot.service gpt-web.service

echo ""
echo "✅ Развертывание завершено!"
echo ""
echo "📝 Следующие шаги:"
echo "1. Настройте API ключи: nano $PROJECT_DIR/.env"
echo "2. Запустите службы: systemctl start gpt-bot.service gpt-web.service"
echo "3. Проверьте статус: systemctl status gpt-bot.service"
echo ""
