# -*- coding: utf-8 -*-
import os
import base64
import requests
import time
import random
import hashlib
import traceback
from dotenv import load_dotenv
import vk_api
from vk_api.longpoll import VkLongPoll, VkEventType
from openai import OpenAI

# Load environment
load_dotenv("/root/.env")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
VK_API_TOKEN = os.getenv("VK_API_TOKEN")

# Initialize clients
client = OpenAI(
    api_key=OPENROUTER_API_KEY,
    base_url="https://openrouter.ai/api/v1",
    default_headers={
        "HTTP-Referer": "https://your-domain.ru",
        "X-Title": "VK Photo Estimator Bot"
    }
)

vk_session = vk_api.VkApi(token=VK_API_TOKEN)
vk = vk_session.get_api()
longpoll = VkLongPoll(vk_session)

# Глобальные переменные
chat_history = {}
last_message_time = {}
sent_messages = {}

def generate_random_id():
    """Генерирует уникальный random_id для VK API"""
    return random.randint(1, 2147483647)

def send_message(user_id, message):
    """Безопасная отправка сообщения с уникальным random_id"""
    try:
        vk.messages.send(
            user_id=user_id, 
            message=message, 
            random_id=generate_random_id()
        )
        print(f"[SENT] to {user_id}: {message[:50]}...")
        return True
    except Exception as e:
        print(f"[ERROR] sending message to {user_id}: {e}")
        return False

def get_message_hash(message):
    """Создает хеш сообщения для проверки дублирования"""
    return hashlib.md5(message.encode('utf-8')).hexdigest()

def download_photo(photo_url):
    try:
        response = requests.get(photo_url, timeout=10)
        if response.status_code == 200:
            return base64.b64encode(response.content).decode("utf-8")
    except Exception as e:
        print(f"[ERROR] downloading photo: {e}")
    return None

def send_to_gpt(user_id, user_message, base64_image=None):
    global chat_history
    
    if user_id not in chat_history:
        chat_history[user_id] = [
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
    
    chat_history[user_id].append({"role": "user", "content": content})
    
    try:
        response = client.chat.completions.create(
            model="openai/gpt-4o-2024-05-13",
            messages=chat_history[user_id],
            max_tokens=1000
        )
        
        if not response.choices:
            return "Ошибка: пустой ответ от модели."
            
        reply = response.choices[0].message.content
        chat_history[user_id].append({"role": "assistant", "content": reply})
        return reply
        
    except Exception as e:
        traceback.print_exc()
        return f"Ошибка GPT: {e}"

def run_bot():
    global chat_history, last_message_time, sent_messages
    
    # Инициализируем глобальные переменные
    processed_ids = set()
    
    # Константы
    SPAM_TIMEOUT = 5
    SELL_KEYWORDS = ["выкуп", "продать", "продажа", "заберете", "забрать", "как вам продать"]
    SELL_MESSAGE = (
        "На данный момент мы не занимаемся прямым выкупом фототехники — мы производим только оценку.\n\n"
        "Если вы хотите продать технику, вы можете разместить объявление в нашей группе:\n"
        "https://vk.com/topic-144479474_53207215\n\n"
        "Пожалуйста, ознакомьтесь с правилами оформления перед размещением."
    )

    print("[BOT] запущен и готов к работе")
    
    while True:
        try:
            for event in longpoll.listen():
                if event.type == VkEventType.MESSAGE_NEW and event.to_me:
                    msg_id = event.message_id
                    user_id = event.user_id
                    
                    # Проверка на уже обработанное сообщение
                    if msg_id in processed_ids:
                        print(f"[SKIP] Уже обработано: {msg_id}")
                        continue
                    
                    processed_ids.add(msg_id)
                    print(f"[EVENT] id={msg_id}, user={user_id}, text={event.text}")

                    # Защита от спама
                    now = time.time()
                    if user_id in last_message_time and now - last_message_time[user_id] < SPAM_TIMEOUT:
                        print(f"[SPAM] ignored from {user_id}")
                        continue
                    last_message_time[user_id] = now

                    # Обработка ключевых слов продажи
                    user_message = event.text.strip().lower() if event.text else ""
                    if any(keyword in user_message for keyword in SELL_KEYWORDS):
                        # Проверка на дублирование продажного сообщения
                        sell_hash = get_message_hash(SELL_MESSAGE)
                        if user_id in sent_messages and sent_messages[user_id] == sell_hash:
                            print(f"[DUPLICATE] Sell message already sent to {user_id}")
                            continue
                        
                        if send_message(user_id, SELL_MESSAGE):
                            sent_messages[user_id] = sell_hash
                        continue

                    # Загрузка вложений (фото)
                    base64_img = None
                    try:
                        msg_data = vk.messages.getById(message_ids=msg_id)
                        for attachment in msg_data["items"][0].get("attachments", []):
                            if attachment["type"] == "photo":
                                sizes = attachment["photo"].get("sizes", [])
                                if sizes:
                                    url = max(sizes, key=lambda x: x["width"])["url"]
                                    base64_img = download_photo(url)
                                    break  # Берем только первое фото
                    except Exception as e:
                        print(f"[ERROR] attach load: {e}")

                    # Проверка на пустое сообщение
                    if len(user_message) < 3 and not base64_img:
                        empty_msg = "Пожалуйста, отправьте модель техники или фото."
                        empty_hash = get_message_hash(empty_msg)
                        
                        if user_id not in sent_messages or sent_messages[user_id] != empty_hash:
                            if send_message(user_id, empty_msg):
                                sent_messages[user_id] = empty_hash
                        continue

                    # Если есть фото, но нет текста - добавляем стандартный запрос
                    if base64_img and not user_message:
                        user_message = "Определи, что на фото, и уточни детали для оценки."

                    print(f"[PROCESS] from {user_id}: '{user_message}' | image={'yes' if base64_img else 'no'}")
                    
                    # Получение ответа от GPT
                    reply = send_to_gpt(user_id, user_message, base64_img)
                    
                    # Проверка на дублирование ответа
                    reply_hash = get_message_hash(reply)
                    if user_id in sent_messages and sent_messages[user_id] == reply_hash:
                        print(f"[DUPLICATE] Same reply already sent to {user_id}")
                        continue
                    
                    # Отправка ответа
                    if send_message(user_id, reply):
                        sent_messages[user_id] = reply_hash
                        
        except Exception as e:
            print(f"[ERROR] Main loop: {e}")
            traceback.print_exc()
            time.sleep(2)  # Пауза при ошибке

if __name__ == "__main__":
    run_bot()
