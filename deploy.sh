#!/bin/bash

# Photo Estimator Bot - Deploy Script
# Автоматическое развертывание проекта

set -e  # Остановить при любой ошибке

echo "🚀 Начинаем развертывание Photo Estimator Bot..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен запускаться с правами root"
fi

# Определение директории проекта
PROJECT_DIR="/root/photo-estimator-bot"
VENV_DIR="$PROJECT_DIR/gpt-bot-env"
REPO_URL="https://github.com/Marakoris/photo-estimator-bot.git"

log "Проверяем системные зависимости..."

# Установка системных зависимостей
apt update
apt install -y python3 python3-venv python3-pip git curl

log "Клонируем репозиторий с GitHub..."
if [ -d "$PROJECT_DIR" ]; then
    warning "Директория $PROJECT_DIR уже существует. Обновляем..."
    cd $PROJECT_DIR
    git pull origin main
else
    log "Клонируем репозиторий..."
    git clone $REPO_URL $PROJECT_DIR
    cd $PROJECT_DIR
fi

log "Создаем виртуальное окружение..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

log "Активируем виртуальное окружение и устанавливаем зависимости..."
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

log "Проверяем файл .env..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        warning "Файл .env не найден. Создаем на основе .env.example"
        cp .env.example .env
    else
        warning "Создаем .env файл с базовыми настройками"
        cat > .env << 'EOF'
# OpenRouter API для GPT-4
OPENROUTER_API_KEY=your_openrouter_api_key_here

# VK API токен для бота
VK_API_TOKEN=your_vk_bot_token_here

# Telegram уведомления (опционально)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
TELEGRAM_CHAT_ID=your_telegram_chat_id_here
EOF
    fi
    warning "⚠️  ВАЖНО: Отредактируйте файл .env и добавьте ваши API ключи:"
    echo "nano $PROJECT_DIR/.env"
    echo ""
fi

log "Проверяем systemd сервисы..."
# Проверяем, где находятся файлы служб
if [ -f "services/gpt-bot.service" ]; then
    SERVICE_DIR="services"
elif [ -f "gpt-bot.service" ]; then
    SERVICE_DIR="."
else
    warning "Файлы служб не найдены, создаем их..."
    mkdir -p services
    SERVICE_DIR="services"
    
    # Создаем службу для VK бота
    cat > services/gpt-bot.service << EOF
[Unit]
Description=VK GPT фотоскупка бот
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/gpt-bot-env/bin
ExecStart=$PROJECT_DIR/gpt-bot-env/bin/python $PROJECT_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gpt-bot

[Install]
WantedBy=multi-user.target
EOF

    # Создаем службу для Web API
    cat > services/gpt-web.service << EOF
[Unit]
Description=Flask GPT Web API
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/gpt-bot-env/bin
Environment=FLASK_ENV=production
ExecStart=$PROJECT_DIR/gpt-bot-env/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 --timeout 120 web_api:app
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gpt-web

[Install]
WantedBy=multi-user.target
EOF
fi

log "Обновляем пути в systemd сервисах..."
# Обновляем пути в сервисах (если они есть и нужно обновить)
if [ "$SERVICE_DIR" != "." ]; then
    sed -i "s|/root/photo-estimator-bot|$PROJECT_DIR|g" $SERVICE_DIR/gpt-bot.service 2>/dev/null || true
    sed -i "s|/root/photo-estimator-bot|$PROJECT_DIR|g" $SERVICE_DIR/gpt-web.service 2>/dev/null || true
fi

log "Устанавливаем systemd сервисы..."
cp $SERVICE_DIR/gpt-bot.service /etc/systemd/system/
cp $SERVICE_DIR/gpt-web.service /etc/systemd/system/

log "Перезагружаем systemd и включаем сервисы..."
systemctl daemon-reload
systemctl enable gpt-bot.service gpt-web.service

log "Проверяем конфигурацию..."
if [ -f ".env" ]; then
    if grep -q "your_.*_here" .env; then
        warning "В файле .env обнаружены placeholder значения. Обновите API ключи!"
    fi
fi

log "Тестируем импорты Python..."
source $VENV_DIR/bin/activate
python3 -c "import flask, vk_api, openai; print('✅ Все зависимости установлены')" || error "Ошибка импорта зависимостей"

echo ""
echo "🎉 Развертывание завершено!"
echo ""
echo "📝 Следующие шаги:"
echo "1. Проверьте и отредактируйте файл .env с вашими API ключами:"
echo "   nano $PROJECT_DIR/.env"
echo ""
echo "2. Запустите сервисы:"
echo "   systemctl start gpt-bot.service gpt-web.service"
echo ""
echo "3. Проверьте статус:"
echo "   systemctl status gpt-bot.service"
echo "   systemctl status gpt-web.service"
echo ""
echo "4. Просмотр логов:"
echo "   journalctl -u gpt-bot.service -f"
echo "   journalctl -u gpt-web.service -f"
echo ""
echo "🌐 Web API будет доступен на порту 8080"
echo "🤖 VK бот начнет отвечать после запуска сервиса"

# Автоматически запускаем сервисы, если .env настроен
if grep -q "your_.*_here" .env 2>/dev/null; then
    warning "⚠️  В файле .env найдены placeholder значения. Обновите API ключи перед запуском!"
else
    log "API ключи настроены, автоматически запускаем сервисы..."
    systemctl start gpt-bot.service gpt-web.service
    sleep 2
    
    echo ""
    echo "📊 Статус сервисов:"
    systemctl is-active gpt-bot.service && echo "✅ VK Bot запущен" || echo "❌ VK Bot не запущен"
    systemctl is-active gpt-web.service && echo "✅ Web API запущен" || echo "❌ Web API не запущен"
    
    echo ""
    echo "📋 Для просмотра логов используйте:"
    echo "   journalctl -u gpt-bot.service -f"
    echo "   journalctl -u gpt-web.service -f"
fi
echo ""
echo "2. Запустите сервисы:"
echo "   systemctl start gpt-bot.service gpt-web.service"
echo ""
echo "3. Проверьте статус:"
echo "   systemctl status gpt-bot.service"
echo "   systemctl status gpt-web.service"
echo ""
echo "4. Просмотр логов:"
echo "   journalctl -u gpt-bot.service -f"
echo "   journalctl -u gpt-web.service -f"
echo ""
echo "🌐 Web API будет доступен на порту 8080"
echo "🤖 VK бот начнет отвечать после запуска сервиса"

log "Развертывание завершено успешно!"
