#!/bin/bash

# Путь к файлу блокировки
LOCKFILE="/tmp/cron_script.lock"

# Путь к лог-файлу веб-сервера
LOGFILE="/home/vagrant/access.log"

# Путь к файлу для хранения последнего прочитанного места в логе
LASTPOSFILE="/tmp/lastlogpos.txt"

# Получатель письма
EMAIL="test@test.ru"

# Файл логов скрипта
SCRIPT_LOG="/tmp/script.log"

# Файл для дублирования сообщения
DUPLICATE_FILE="/tmp/email_duplicate.log"

# Проверка на существование файла блокировки

if [ -e "$LOCKFILE" ]; then
    echo "$(date): Скрипт уже запущен" >> "$SCRIPT_LOG"
    exit 1
fi

# Создание файла блокировки

touch "$LOCKFILE"

# Определение последней прочитанной позиции в лог-файле

LASTPOS=0
if [ -f "$LASTPOSFILE" ]; then
    LASTPOS=$(cat "$LASTPOSFILE")
fi

# Определение текущего размера лог-файла
CURPOS=$(wc -c < "$LOGFILE")

# Если лог-файл был очищен, читаем с начала
if [ "$CURPOS" -lt "$LASTPOS" ]; then
    LASTPOS=0
fi

# Извлечение новых записей из лог-файла
tail -c +$((LASTPOS + 1)) "$LOGFILE" > /tmp/newlogs.txt

# Обновление позиции
echo "$CURPOS" > "$LASTPOSFILE"

# Анализ логов
IP_COUNTS=$(awk '{print $1}' /tmp/newlogs.txt | sort | uniq -c | sort -nr | head)
URL_COUNTS=$(awk '{print $7}' /tmp/newlogs.txt | sort | uniq -c | sort -nr | head)
ERRORS=$(grep "error" /tmp/newlogs.txt)
HTTP_CODES=$(awk '{print $9}' /tmp/newlogs.txt | sort | uniq -c | sort -nr)

# Формирование письма
EMAIL_SUBJECT="Отчёт о запросах и ошибках веб-сервера"
EMAIL_BODY=$(cat <<EOF

Список IP адресов с наибольшим количеством запросов:
$IP_COUNTS

Список запрашиваемых URL с наибольшим количеством запросов:
$URL_COUNTS

Ошибки веб-сервера/приложения:
$ERRORS

Список всех кодов HTTP ответа:
$HTTP_CODES
EOF
)

# Дублирование сообщения в файл
echo "=== $(date) ===" >> "$DUPLICATE_FILE"
echo "$EMAIL_BODY" >> "$DUPLICATE_FILE"
echo "" >> "$DUPLICATE_FILE"

# Отправка письма
if echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL"; then
    echo "$(date): Письмо успешно отправлено на $EMAIL" >> "$SCRIPT_LOG"
else
    echo "$(date): Ошибка отправки письма на $EMAIL" >> "$SCRIPT_LOG"
fi

# Удаление файла блокировки
rm -f "$LOCKFILE"

