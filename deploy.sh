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

log "Проверяем системные зависимости..."

# Установка системных зависимостей
apt update
apt install -y python3 python3-venv python3-pip git curl

log "Создаем директорию проекта..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

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
    warning "Файл .env не найден. Создайте его на основе .env.example"
    cp .env.example .env
    warning "Отредактируйте файл .env и добавьте ваши API ключи:"
    echo "nano $PROJECT_DIR/.env"
    echo ""
fi

log "Обновляем пути в systemd сервисах..."
# Обновляем пути в сервисах
sed -i "s|/root/photo-estimator-bot|$PROJECT_DIR|g" services/gpt-bot.service
sed -i "s|/root/photo-estimator-bot|$PROJECT_DIR|g" services/gpt-web.service

log "Устанавливаем systemd сервисы..."
cp services/gpt-bot.service /etc/systemd/system/
cp services/gpt-web.service /etc/systemd/system/

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
echo "1. Отредактируйте файл .env с вашими API ключами:"
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

log "Развертывание завершено успешно!"
