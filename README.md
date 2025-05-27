# Photo Estimator Bot

Система для оценки фототехники, состоящая из VK бота и веб-интерфейса с интеграцией GPT-4.

## 🚀 Возможности

- **VK Бот** - принимает текстовые запросы и фото в ВКонтакте
- **Web API** - обрабатывает запросы с веб-сайта
- **GPT-4 Vision** - анализирует изображения и оценивает технику
- **Защита от спама** - таймауты и дедупликация сообщений
- **Telegram уведомления** - отправка статистики в Telegram
- **Автозапуск** - systemd сервисы для автоматической работы

## 📁 Структура проекта

```
photo-estimator-bot/
├── bot.py              # VK бот
├── web_api.py          # Flask веб API
├── requirements.txt    # Python зависимости
├── .env.example       # Пример переменных окружения
├── services/          # Systemd сервисы
│   ├── gpt-bot.service
│   └── gpt-web.service
└── README.md          # Документация
```

## 🛠 Установка

### 1. Клонирование репозитория
```bash
git clone https://github.com/your-username/photo-estimator-bot.git
cd photo-estimator-bot
```

### 2. Создание виртуального окружения
```bash
python3 -m venv gpt-bot-env
source gpt-bot-env/bin/activate
pip install -r requirements.txt
```

### 3. Настройка переменных окружения
```bash
cp .env.example .env
nano .env
```

Заполните необходимые API ключи и токены.

### 4. Тестовый запуск
```bash
# VK бот
python bot.py

# Web API (в отдельном терминале)
source gpt-bot-env/bin/activate
python web_api.py
```

## 🔧 Настройка как системных сервисов

### 1. Копирование сервисов
```bash
sudo cp services/gpt-bot.service /etc/systemd/system/
sudo cp services/gpt-web.service /etc/systemd/system/
```

### 2. Обновление путей в сервисах
Отредактируйте пути в файлах сервисов под вашу систему:
```bash
sudo nano /etc/systemd/system/gpt-bot.service
sudo nano /etc/systemd/system/gpt-web.service
```

### 3. Запуск сервисов
```bash
sudo systemctl daemon-reload
sudo systemctl enable gpt-bot.service gpt-web.service
sudo systemctl start gpt-bot.service gpt-web.service
```

### 4. Проверка статуса
```bash
sudo systemctl status gpt-bot.service
sudo systemctl status gpt-web.service
```

## 📋 Требуемые API ключи

| Сервис | Переменная | Описание |
|--------|------------|----------|
| OpenRouter | `OPENROUTER_API_KEY` | Ключ для GPT-4 |
| VK API | `VK_API_TOKEN` | Токен VK бота |
| Telegram | `TELEGRAM_BOT_TOKEN` | Токен Telegram бота (опционально) |
| Telegram | `TELEGRAM_CHAT_ID` | ID чата для уведомлений (опционально) |

## 🔍 Мониторинг и логи

### Просмотр логов
```bash
# VK бот
sudo journalctl -u gpt-bot.service -f

# Web API
sudo journalctl -u gpt-web.service -f

# Последние ошибки
sudo journalctl -u gpt-bot.service --lines=50
```

### Перезапуск сервисов
```bash
sudo systemctl restart gpt-bot.service
sudo systemctl restart gpt-web.service
```

## 🌐 Web API Endpoints

| Endpoint | Method | Описание |
|----------|--------|----------|
| `/health` | GET | Проверка работоспособности |
| `/chat` | POST | Обработка запросов с сайта |

### Пример запроса к API
```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"text": "Canon 5D Mark IV", "image_base64": "..."}'
```

## 🐛 Решение проблем

### VK бот не отвечает
1. Проверьте статус сервиса: `sudo systemctl status gpt-bot.service`
2. Посмотрите логи: `sudo journalctl -u gpt-bot.service -f`
3. Проверьте VK токен в `.env` файле

### Web API возвращает ошибки
1. Проверьте CORS настройки для мобильных устройств
2. Убедитесь, что размер изображения не превышает 10MB
3. Проверьте OpenRouter API ключ

### Общие проблемы
- Убедитесь, что все зависимости установлены: `pip install -r requirements.txt`
- Проверьте права доступа к файлам: `chmod +x bot.py web_api.py`
- Убедитесь, что порт 8080 не занят: `netstat -tulpn | grep 8080`

## 📊 Функции

### VK Бот
- ✅ Обработка текстовых запросов
- ✅ Анализ изображений
- ✅ История диалогов для каждого пользователя
- ✅ Защита от спама (5 сек таймаут)
- ✅ Автоответы на ключевые слова продажи
- ✅ Дедупликация сообщений

### Web API
- ✅ CORS поддержка для всех доменов
- ✅ Обработка мобильных устройств
- ✅ Ограничение размера изображений
- ✅ Telegram уведомления
- ✅ Подробное логирование

## 📝 Лицензия

MIT License - используйте свободно для личных и коммерческих проектов.

## 🤝 Поддержка

При возникновении проблем:
1. Проверьте логи сервисов
2. Убедитесь в корректности API ключей
3. Проверьте сетевое соединение
