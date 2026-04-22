#!/bin/bash
# archive-sessions.sh - Архивирование сессий OpenClaw
# Запускай вручную или через cron на RPi
# 
# Использование:
#   ./archive-sessions.sh          — архивировать все завершённые сессии
#   ./archive-sessions.sh --full   — архивировать всё, включая текущую

set -e

echo "📦 АРХИВАЦИЯ СЕССИЙ OPENCLAW"
echo "=============================="

# Директории
SESSIONS_DIR="/home/brigadir/.openclaw/agents/main/sessions"
ARCHIVE_DIR="/home/brigadir/.openclaw/workspace/sessions-archive"
DATE=$(date +%Y-%m-%d)

# Создаём архивную папку
mkdir -p "$ARCHIVE_DIR"

echo ""
echo "📁 Текущие сессии:"
ls -lh "$SESSIONS_DIR"/*.jsonl 2>/dev/null

echo ""
echo "📦 Архивация..."

# Определяем текущую сессию (не архивируем её, если не --full)
CURRENT_SESSION=$(readlink -f /proc/$$/fd/0 2>/dev/null || echo "")

ARCHIVED=0
SKIPPED=0

for session_file in "$SESSIONS_DIR"/*.jsonl; do
    [[ -f "$session_file" ]] || continue
    
    # Получаем имя файла
    filename=$(basename "$session_file")
    session_id="${filename%.jsonl}"
    
    # Если это не полная архивация, проверяем не текущая ли это сессия
    if [[ "$1" != "--full" ]]; then
        # Проверяем, активна ли сессия (обновлялась за последние 5 минут)
        if [[ $(stat -c %Y "$session_file" 2>/dev/null) -gt $(($(date +%s) - 300)) ]]; then
            echo "   ⏭️  Пропускаю активную сессию: $session_id"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
    fi
    
    # Архивируем
    archive_name="${session_id}_${DATE}.jsonl.gz"
    
    if [[ -f "$ARCHIVE_DIR/$archive_name" ]]; then
        echo "   ⏭️  Уже архивирована: $filename"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Копируем и сжимаем
    gzip -c "$session_file" > "$ARCHIVE_DIR/$archive_name"
    
    # Проверяем что архив создался
    if [[ -f "$ARCHIVE_DIR/$archive_name" ]]; then
        original_size=$(stat -c%s "$session_file" 2>/dev/null || stat -f%z "$session_file" 2>/dev/null)
        archive_size=$(stat -c%s "$ARCHIVE_DIR/$archive_name" 2>/dev/null || stat -f%z "$ARCHIVE_DIR/$archive_name" 2>/dev/null)
        compression=$(( (original_size - archive_size) * 100 / original_size ))
        
        echo "   ✅ $filename → $archive_name (сжато на ${compression}%)"
        ARCHIVED=$((ARCHIVED + 1))
    else
        echo "   ❌ Ошибка архивации: $filename"
    fi
done

echo ""
echo "📊 ИТОГИ:"
echo "   Заархивировано: $ARCHIVED"
echo "   Пропущено: $SKIPPED"
echo ""

# Считаем общий размер архива
if [[ -d "$ARCHIVE_DIR" ]]; then
    total_size=$(du -sh "$ARCHIVE_DIR" | cut -f1)
    total_files=$(find "$ARCHIVE_DIR" -name "*.jsonl.gz" | wc -l)
    echo "📦 Архив: $total_files файлов, всего $total_size"
fi

echo ""
echo "📍 Архив: $ARCHIVE_DIR"
echo "📋 Для просмотра содержимого: gunzip -c архив.gz | less"

# Если запущено с параметром --stats, показываем статистику
if [[ "$1" == "--stats" ]]; then
    echo ""
    echo "📈 СТАТИСТИКА ПО СЕССИЯМ:"
    for f in "$ARCHIVE_DIR"/*.jsonl.gz; do
        [[ -f "$f" ]] || continue
        filename=$(basename "$f")
        size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
        # Пытаемся определить дату из имени
        date_part=$(echo "$filename" | grep -oP '\d{4}-\d{2}-\d{2}' || echo "неизвестно")
        echo "   • $date_part — $(numfmt --to=iec $size 2>/dev/null || echo "$size байт")"
    done
fi

echo ""
echo "========================================"
echo "✅ АРХИВАЦИЯ ЗАВЕРШЕНА"
echo "========================================"