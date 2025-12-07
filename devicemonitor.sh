#!/bin/bash
# Скрипт для мониторинга устройств с логированием

# Настройки лог-файла
LOG_FILE="ustroistva_log.txt"
OLD_DEVICES_FILE="starye_ustroistva.txt"
TIME_STAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "=== Начинаем проверку устройств ==="
echo "Лог будет записан в файл: $LOG_FILE"
echo ""

# Функция для записи в лог
zapisat_v_log() {
    echo "[$TIME_STAMP] $1" >> "$LOG_FILE"
    echo "$1"  # Также выводим на экран
}

# Функция для проверки новых устройств
proverit_novye_ustroistva() {
    local tekushie_ustroistva="$1"
    local tip_ustroistva="$2"
    
    # Если файл со старыми устройствами не существует, создаем его
    if [ ! -f "$OLD_DEVICES_FILE" ]; then
        echo "$tekushie_ustroistva" > "$OLD_DEVICES_FILE"
        zapisat_v_log "Создан файл со списком старых устройств"
        return
    fi
    
    # Читаем старые устройства
    starye_ustroistva=$(cat "$OLD_DEVICES_FILE" 2>/dev/null)
    
    # Сравниваем и находим новые
    novye_najdeny=0
    
    # Используем временный файл для обработки
    temp_file=$(mktemp)
    echo "$tekushie_ustroistva" > "$temp_file"
    
    while read -r ustroistvo; do
        if [ -n "$ustroistvo" ]; then  # Проверяем, что строка не пустая
            # Проверяем, есть ли это устройство в старых
            if ! echo "$starye_ustroistva" | grep -q "$ustroistvo"; then
                novye_najdeny=1
                zapisat_v_log "НОВОЕ УСТРОЙСТВО ($tip_ustroistva): $ustroistvo"
            fi
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    # Если были новые устройства, обновляем файл
    if [ $novye_najdeny -eq 1 ]; then
        echo "$tekushie_ustroistva" > "$OLD_DEVICES_FILE"
        zapisat_v_log "Обновлен список устройств"
    fi
}

# Начинаем запись в лог
echo "=== Запуск мониторинга устройств ===" > "$LOG_FILE"
zapisat_v_log "Начало проверки устройств"
zapisat_v_log "Время запуска: $TIME_STAMP"
zapisat_v_log ""

# Шаг 1: Проверяем папку /proc/bus/input
echo ""
zapisat_v_log "Шаг 1: Проверка папки /proc/bus/input"
echo "Шаг 1: Смотрю что в папке /proc/bus/input"
echo "----------------------------------------"

if [ -d "/proc/bus/input" ]; then
    zapisat_v_log "Папка /proc/bus/input найдена"
    echo "Папка найдена! Вот что в ней:"
    echo ""
    
    # Простой список файлов в папке
    echo "Список файлов:"
    ls -l /proc/bus/input/
    echo ""
    
    # Проверяем файл devices
    if [ -f "/proc/bus/input/devices" ]; then
        zapisat_v_log "Файл /proc/bus/input/devices найден"
        echo "Файл devices найден. Смотрю что в нем..."
        echo ""
        
        # Читаем файл построчно
        echo "=== Информация об устройствах ==="
        echo ""
        
        # Простой цикл для чтения файла
        line_number=1
        device_number=0
        tekushie_ustroistva_vvoda=""
        
        # Используем простой while read вместо exec
        while read -r line; do
            # Если строка начинается с I:, это начало информации об устройстве
            if [[ "$line" == I:* ]]; then
                device_number=$((device_number + 1))
                echo "Устройство №$device_number:"
                echo "------------------------"
            fi
            
            # Обрабатываем разные типы строк
            if [[ "$line" == I:* ]]; then
                echo "Информация о драйвере: $line"
            elif [[ "$line" == N:* ]]; then
                # Вытаскиваем название устройства
                name_part=$(echo "$line" | cut -d'=' -f2)
                echo "Название: $name_part"
                # Сохраняем для проверки новых устройств
                tekushie_ustroistva_vvoda="${tekushie_ustroistva_vvoda}${name_part}"$'\n'
            elif [[ "$line" == P:* ]]; then
                phys_part=$(echo "$line" | cut -d'=' -f2)
                echo "Физический адрес: $phys_part"
            elif [[ "$line" == S:* ]]; then
                sysfs_part=$(echo "$line" | cut -d'=' -f2)
                echo "Путь в системе: $sysfs_part"
            elif [[ "$line" == H:* ]]; then
                handlers_part=$(echo "$line" | cut -d'=' -f2)
                echo "Обработчики: $handlers_part"
            elif [[ "$line" == B:* ]]; then
                bitmap_part=$(echo "$line" | cut -d'=' -f2)
                # Берем только первую часть до пробела
                bitmap_name=$(echo "$line" | cut -d'=' -f1 | cut -d' ' -f2)
                echo "Настройка $bitmap_name: $bitmap_part"
            fi
            
            # Если пустая строка, выводим разделитель
            if [ -z "$line" ]; then
                echo ""
            fi
            
            line_number=$((line_number + 1))
        done < "/proc/bus/input/devices"
        
        echo "Всего найдено устройств: $device_number"
        zapisat_v_log "Найдено устройств ввода: $device_number"
        
        # Проверяем новые устройства ввода
        proverit_novye_ustroistva "$tekushie_ustroistva_vvoda" "устройство ввода"
        
        echo ""
        
    else
        echo "Ошибка: файл devices не найден"
        zapisat_v_log "ОШИБКА: файл devices не найден"
    fi
    
else
    echo "Ошибка: папка /proc/bus/input не найдена"
    zapisat_v_log "ОШИБКА: папка /proc/bus/input не найдена"
fi

# Шаг 2: Смотрим устройства в /dev/input
echo ""
zapisat_v_log "Шаг 2: Проверка устройств в /dev/input"
echo "Шаг 2: Смотрю устройства в /dev/input"
echo "-------------------------------------"

if [ -d "/dev/input" ]; then
    zapisat_v_log "Папка /dev/input найдена"
    echo "Нашел папку /dev/input. Вот что в ней:"
    echo ""
    
    # Считаем сколько файлов
    file_count=0
    tekushie_dev_ustroistva=""
    
    for file in /dev/input/*; do
        if [ -e "$file" ]; then
            file_count=$((file_count + 1))
            imya_faila=$(basename "$file")
            tekushie_dev_ustroistva="${tekushie_dev_ustroistva}${imya_faila}"$'\n'
        fi
    done
    
    echo "Всего файлов: $file_count"
    zapisat_v_log "Файлов в /dev/input: $file_count"
    echo ""
    
    # Простой список с нумерацией
    echo "Список устройств:"
    echo "№ | Имя файла          | Тип"
    echo "--|--------------------|-----"
    
    counter=1
    for device_file in /dev/input/*; do
        if [ -e "$device_file" ]; then
            filename=$(basename "$device_file")
            
            # Определяем тип файла
            if [ -c "$device_file" ]; then
                file_type="символьное"
            elif [ -b "$device_file" ]; then
                file_type="блочное"
            elif [ -L "$device_file" ]; then
                file_type="ссылка"
            else
                file_type="обычный"
            fi
            
            echo "$counter | $filename | $file_type"
            counter=$((counter + 1))
        fi
    done
    
    # Проверяем новые устройства в /dev/input
    proverit_novye_ustroistva "$tekushie_dev_ustroistva" "файл в /dev/input"
    
else
    echo "Ошибка: папка /dev/input не найдена"
    zapisat_v_log "ОШИБКА: папка /dev/input не найдена"
fi

# Шаг 3: Проверяем USB устройства (если есть команда lsusb)
echo ""
zapisat_v_log "Шаг 3: Проверка USB устройств"
echo "Шаг 3: Проверяю USB устройства"
echo "-------------------------------"

# Проверяем есть ли команда lsusb
if command -v lsusb > /dev/null 2>&1; then
    zapisat_v_log "Команда lsusb доступна"
    echo "Команда lsusb найдена. Запускаю..."
    echo ""
    
    # Получаем количество USB устройств
    usb_count=$(lsusb | wc -l)
    echo "Найдено USB устройств: $usb_count"
    zapisat_v_log "Найдено USB устройств: $usb_count"
    echo ""
    
    if [ "$usb_count" -gt 0 ]; then
        echo "Список USB устройств:"
        echo "№ | ID производителя | Описание"
        echo "--|------------------|----------"
        
        # Читаем вывод lsusb построчно
        usb_num=1
        tekushie_usb_ustroistva=""
        
        while read -r usb_line; do
            # Берем 6-е поле (ID производителя:устройства)
            usb_id=$(echo "$usb_line" | awk '{print $6}')
            
            # Берем все что после 6-го поля (описание)
            usb_desc=$(echo "$usb_line" | cut -d' ' -f7-)
            
            echo "$usb_num | $usb_id | $usb_desc"
            
            # Сохраняем для проверки новых устройств
            tekushie_usb_ustroistva="${tekushie_usb_ustroistva}${usb_desc}"$'\n'
            
            usb_num=$((usb_num + 1))
        done < <(lsusb)
        
        # Простой анализ: какие производители есть
        echo ""
        echo "Анализ производителей:"
        
        # Временный файл для хранения ID
        temp_file=$(mktemp)
        lsusb | awk '{print $6}' | cut -d':' -f1 > "$temp_file"
        
        # Считаем уникальные производители
        echo "Найдены производители:"
        while read -r vendor; do
            if [ -n "$vendor" ]; then
                count=$(grep -c "^${vendor}$" "$temp_file" 2>/dev/null || true)
                if [ -z "$count" ]; then
                    count=0
                fi
                echo "  $vendor: $count устройств"
                zapisat_v_log "Производитель $vendor: $count устройств"
            fi
        done < <(sort "$temp_file" | uniq)
        
        # Удаляем временный файл
        rm -f "$temp_file"
        
        # Проверяем новые USB устройства
        proverit_novye_ustroistva "$tekushie_usb_ustroistva" "USB устройство"
        
    else
        echo "USB устройств не найдено"
        zapisat_v_log "USB устройств не найдено"
    fi
    
else
    echo "Команда lsusb не найдена. Пропускаем этот шаг."
    zapisat_v_log "Команда lsusb не найдена"
fi

# Шаг 4: Простая сводка
echo ""
zapisat_v_log "Шаг 4: Создание сводки"
echo "=== Сводка ==="
echo "--------------"

# Собираем информацию
input_devices_count=0
if [ -f "/proc/bus/input/devices" ]; then
    # Простой способ подсчета устройств - ищем строки с "I:"
    input_devices_count=$(grep -c "^I:" /proc/bus/input/devices 2>/dev/null || echo "0")
fi

dev_input_count=0
if [ -d "/dev/input" ]; then
    dev_input_count=$(ls /dev/input/ | wc -l)
fi

usb_total=0
if command -v lsusb > /dev/null 2>&1; then
    usb_total=$(lsusb | wc -l)
fi

echo "Всего обнаружено:"
echo "  - Устройств ввода: $input_devices_count"
echo "  - Файлов в /dev/input: $dev_input_count"
echo "  - USB устройств: $usb_total"
echo ""

zapisat_v_log "=== Сводка обнаруженных устройств ==="
zapisat_v_log "Устройств ввода: $input_devices_count"
zapisat_v_log "Файлов в /dev/input: $dev_input_count"
zapisat_v_log "USB устройств: $usb_total"

# Завершаем запись в лог
echo "Проверка завершена!"
zapisat_v_log "=== Проверка завершена ==="
echo ""
echo "Лог записан в файл: $LOG_FILE"
echo "Список старых устройств в: $OLD_DEVICES_FILE"
echo ""
echo "Для следующего запуска:"
echo "  - Новые устройства будут записаны в лог"
echo "  - Старые устройства не будут записываться повторно"

# Функция для просмотра лога
pokazat_log() {
    echo ""
    echo "=== Последние записи в логе ==="
    echo "--------------------------------"
    if [ -f "$LOG_FILE" ]; then
        tail -20 "$LOG_FILE"
    else
        echo "Лог-файл не найден"
    fi
}

# Предлагаем показать лог
echo ""
read -p "Показать последние записи из лога? (y/n): " otvet
if [ "$otvet" = "y" ] || [ "$otvet" = "Y" ]; then
    pokazat_log
fi