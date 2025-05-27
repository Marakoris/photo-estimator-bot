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

echo "📦 Установка системных зависимостей..."
apt update
apt install -y python3 python3-venv python3-pip git curl

echo "📥 Клонирование репозитория..."
if [ -d "$PROJECT_DIR" ]; then
    echo "⚠️  Директория уже существует. Удаляем для чистой установки..."
    rm -rf "$PROJECT_DIR"
fi

git clone $REPO_URL $PROJECT_DIR
cd $PROJECT_DIR

echo "🐍 Создание виртуального окружения..."
python3 -m venv gpt-bot-env
source gpt-bot-env/bin/activate

echo "📚 Установка Python зависимостей..."
pip install --upgrade pip
pip install -r requirements.txt

echo "⚙️ Настройка .env файла..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "📝 Файл .env создан из .env.example"
    else
        cat > .env << 'EOF'
# OpenRouter API для GPT-4
OPENROUTER_API_KEY=your_openrouter_api_key_here

# VK API токен для бота
VK_API_TOKEN=your_vk_bot_token_here

# Telegram уведомления (опционально)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
TELEGRAM_CHAT_ID=your_telegram_chat_id_here
EOF
        echo "📝 Создан базовый .env файл"
    fi
fi

echo "🧪 Тестирование зависимостей..."
python3 -c "import flask, vk_api, openai; print('✅ Все зависимости установлены корректно')"

echo "🔧 Остановка старых служб (если есть)..."
systemctl stop gpt-bot.service gpt-web.service 2>/dev/null || true
systemctl disable gpt-bot.service gpt-web.service 2>/dev/null || true

echo "📋 Создание systemd служб..."
cat > /etc/systemd/system/gpt-bot.service << 'EOF'
[Unit]
Description=VK GPT Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/photo-estimator-bot
ExecStart=/bin/bash -c 'cd /root/photo-estimator-bot && source gpt-bot-env/bin/activate && python bot.py'
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gpt-bot

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpt-web.service << 'EOF'
[Unit]
Description=Web API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/photo-estimator-bot
ExecStart=/bin/bash -c 'cd /root/photo-estimator-bot && source gpt-bot-env/bin/activate && gunicorn --bind 0.0.0.0:8080 --workers 2 web_api:app'
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gpt-web

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Перезагрузка systemd и включение служб..."
systemctl daemon-reload
systemctl enable gpt-bot.service gpt-web.service

echo ""
echo "🎉 Развертывание завершено успешно!"
echo ""

# Проверяем .env файл
if grep -q "your_.*_here" .env 2>/dev/null; then
    echo "⚠️  ВНИМАНИЕ: Настройте API ключи перед запуском!"
    echo "   nano $PROJECT_DIR/.env"
    echo ""
    echo "📝 После настройки .env запустите службы:"
    echo "   systemctl start gpt-bot.service gpt-web.service"
    echo ""
else
    echo "🚀 API ключи настроены, запускаем службы..."
    systemctl start gpt-bot.service gpt-web.service
    sleep 3
    
    echo "📊 Статус служб:"
    if systemctl is-active --quiet gpt-bot.service; then
        echo "✅ VK Bot запущен"
    else
        echo "❌ VK Bot не запустился"
    fi
    
    if systemctl is-active --quiet gpt-web.service; then
        echo "✅ Web API запущен на порту 8080"
    else
        echo "❌ Web API не запустился"
    fi
fi

echo ""
echo "📋 Полезные команды:"
echo "   Статус:     systemctl status gpt-bot.service gpt-web.service"
echo "   Логи:       journalctl -u gpt-bot.service -f"
echo "   Перезапуск: systemctl restart gpt-bot.service gpt-web.service"
echo "   Тест API:   curl http://localhost:8080/health"
echo ""
echo "🎯 Развертывание завершено!"
