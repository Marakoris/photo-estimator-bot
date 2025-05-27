# Photo Estimator Bot

Бот для оценки фототехники в VK и веб-интерфейс.

## Описание
- **VK бот** - принимает сообщения и фото в ВКонтакте
- **Web API** - обрабатывает запросы с сайта
- **GPT интеграция** - использует OpenRouter для анализа

## Установка
```bash
git clone your-repo-url
cd photo-estimator-bot
python -m venv gpt-bot-env
source gpt-bot-env/bin/activate
pip install -r requirements.txt
```

## Настройка
Создайте файл `.env`:
```
OPENROUTER_API_KEY=your_key
VK_API_TOKEN=your_token
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_CHAT_ID=your_chat_id
```
