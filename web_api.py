# -*- coding: utf-8 -*-
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import traceback
from dotenv import load_dotenv
import requests
from openai import OpenAI

# Загрузка переменных
load_dotenv("/root/.env")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

# Инициализация OpenAI клиента для веб-версии
client = OpenAI(
    api_key=OPENROUTER_API_KEY,
    base_url="https://openrouter.ai/api/v1",
    default_headers={
        "HTTP-Referer": "https://your-domain.ru",
        "X-Title": "VK Photo Estimator Bot Web"
    }
)

# Глобальная переменная для истории чатов веб-версии
web_chat_history = {}

app = Flask(__name__)
# Расширенная CORS конфигурация для мобильных устройств
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

def send_to_gpt_web(user_id, user_message, base64_image=None):
    """Отдельная функция для веб-версии с собственной историей чатов"""
    if user_id not in web_chat_history:
        web_chat_history[user_id] = [
            {"role": "system", "content": (
                "Ты работаешь в скупке фототехники в России. "
                "Твоя задача — кратко и чётко оценивать камеры и объективы "
                "в рублях по российским рыночным ценам."
            )}
        ]
    
    content = []
    if user_message:
        content.append({"type": "text", "text": user_message})
    if base64_image:
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}})
    
    web_chat_history[user_id].append({"role": "user", "content": content})
    
    try:
        response = client.chat.completions.create(
            model="openai/gpt-4o-2024-05-13",
            messages=web_chat_history[user_id],
            max_tokens=1000
        )
        
        if not response.choices:
            return "Ошибка: пустой ответ от модели."
            
        reply = response.choices[0].message.content
        web_chat_history[user_id].append({"role": "assistant", "content": reply})
        return reply
        
    except Exception as e:
        print(f"[GPT ERROR] {e}")
        traceback.print_exc()
        return f"Ошибка при обращении к GPT: {str(e)}"

@app.route('/chat', methods=['POST', 'OPTIONS'])
def chat():
    # Обработка CORS preflight запросов
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"}), 200
        
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No JSON data received"}), 400
            
        text = data.get("text", "").strip()
        image_base64 = data.get("image_base64")

        print(f"[WEB REQUEST] text: '{text}', has_image: {bool(image_base64)}, user_agent: {request.headers.get('User-Agent', 'unknown')}")

        # Дополнительная обработка для мобильных устройств
        if image_base64:
            try:
                # Проверяем размер base64 строки (примерно размер файла)
                image_size_mb = len(image_base64) * 3 / 4 / 1024 / 1024
                print(f"[IMAGE] Size: {image_size_mb:.2f} MB")
                
                # Ограничиваем размер изображения (10MB для мобильных)
                if image_size_mb > 10:
                    return jsonify({"error": "Изображение слишком большое. Максимум 10MB."}), 400
                    
            except Exception as e:
                print(f"[IMAGE ERROR] {e}")
                return jsonify({"error": "Ошибка обработки изображения"}), 400

        if not text and not image_base64:
            return jsonify({"error": "Отправьте текст или изображение"}), 400

        # Создаем уникальный ID для веб-пользователя
        user_id = f"web-user-{request.remote_addr.replace('.', '-')}"
        
        # Если есть изображение, но нет текста - добавляем стандартный запрос
        if image_base64 and not text:
            text = "Определи, что на фото, и уточни детали для оценки."

        # Получаем ответ от GPT
        reply = send_to_gpt_web(user_id, text, image_base64)
        
        print(f"[WEB REPLY] {reply[:100]}...")  # Логируем первые 100 символов ответа

        # Отправляем уведомление в Telegram
        try:
            notify_telegram(user_id, text, reply)
        except Exception as telegram_error:
            print(f"[TELEGRAM ERROR] {telegram_error}")
            # Не прерываем выполнение, если Telegram не работает

        return jsonify({"reply": reply})
        
    except Exception as e:
        print(f"[WEB ERROR] {e}")
        traceback.print_exc()
        return jsonify({"error": f"Внутренняя ошибка сервера: {str(e)}"}), 500

def notify_telegram(user_id, text, reply):
    """Отправка уведомления в Telegram"""
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        print("[TELEGRAM] Token or Chat ID not configured")
        return
        
    message = (
        "🌐 Новый чат с сайта:\n\n"
        f"👤 Пользователь: {user_id}\n"
        f"❓ Вопрос: {text or '(только фото)'}\n"
        f"💬 Ответ: {reply[:500]}{'...' if len(reply) > 500 else ''}"
    )
    
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    try:
        response = requests.post(
            url, 
            json={"chat_id": TELEGRAM_CHAT_ID, "text": message},
            timeout=5
        )
        if response.status_code == 200:
            print("[TELEGRAM] Notification sent successfully")
        else:
            print(f"[TELEGRAM] Error: {response.status_code}, {response.text}")
    except Exception as e:
        print(f"[TELEGRAM ERROR] {e}")

@app.route('/health', methods=['GET'])
def health():
    """Проверка работоспособности API"""
    return jsonify({"status": "ok", "message": "Web API is running"})

if __name__ == '__main__':
    print("[WEB API] Starting on http://0.0.0.0:8080")
    app.run(host='0.0.0.0', port=8080, debug=True)
