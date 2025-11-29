#!/bin/bash

# Функция для проверки привилегий root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo "Ошибка: Скрипт должен запускаться с повышенными привилегиями (root)."
        exit 1
    fi
}

# Проверка IPv4 адреса или его части
validate_ip_part() {
    local part="$1"
    local type="$2"
    
    if [[ -z "$part" ]]; then
        return 0  # Пустое значение допустимо
    fi
    
    if [[ "$part" =~ ^[0-9]{1,3}$ ]] && (( part >= 0 && part <= 255 )); then
        return 0
    else
        echo "Ошибка: Неверный формат $type. Должен быть числом от 0 до 255."
        exit 1
    fi
}

# Проверка интерфейса
validate_interface() {
    local interface="$1"
    
    if [[ -z "$interface" ]]; then
        echo "Ошибка: Интерфейс не указан."
        exit 1
    fi
    
    if ! ip link show "$interface" &> /dev/null; then
        echo "Ошибка: Интерфейс '$interface' не существует."
        exit 1
    fi
}

# Выполнения сканирования
perform_scan() {
    local prefix="$1"
    local interface="$2"
    local subnet="$3"
    local host="$4"
    
    if [[ -n "$subnet" && -n "$host" ]]; then
        # Сканирование одного IP
        echo "[*] Сканирование IP: ${prefix}.${subnet}.${host}"
        arping -c 3 -i "$interface" "${prefix}.${subnet}.${host}" 2> /dev/null
        
    elif [[ -n "$subnet" ]]; then
        # Сканирование одной подсети
        echo "[*] Сканирование подсети: ${prefix}.${subnet}.x"
        for HOST in {1..254}; do
            echo "[*] IP: ${prefix}.${subnet}.${HOST}"
            arping -c 1 -i "$interface" "${prefix}.${subnet}.${HOST}" 2> /dev/null
        done
        
    else
        # Сканирование всей сети
        echo "[*] Сканирование всей сети: ${prefix}.x.x"
        for SUBNET in {1..254}; do
            for HOST in {1..254}; do
                echo "[*] IP: ${prefix}.${SUBNET}.${HOST}"
                arping -c 1 -i "$interface" "${prefix}.${SUBNET}.${HOST}" 2> /dev/null
            done
        done
    fi
}

# Основная логика скрипта
main() {
    # Проверка привилегий root
    check_root_privileges
    
    # Парсинг аргументов
    PREFIX="$1"
    INTERFACE="$2"
    SUBNET="$3"
    HOST="$4"
    
    # Валидация обязательных параметров
    if [[ -z "$PREFIX" ]]; then
        echo "Использование: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
        echo "Примеры:"
        echo "  $0 192.168 eth0          # Сканирование всей сети"
        echo "  $0 192.168 eth0 1        # Сканирование подсети 192.168.1.x"
        echo "  $0 192.168 eth0 1 100    # Сканирование одного IP 192.168.1.100"
        exit 1
    fi
    
    # Проверка формата PREFIX (должен быть в формате xxx.xxx)
    if [[ ! "$PREFIX" =~ ^[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Ошибка: PREFIX должен быть в формате xxx.xxx (например, 192.168)"
        exit 1
    fi
    
    # Проверка частей PREFIX
    IFS='.' read -r PREFIX1 PREFIX2 <<< "$PREFIX"
    validate_ip_part "$PREFIX1" "первая часть PREFIX"
    validate_ip_part "$PREFIX2" "вторая часть PREFIX"
    
    # Проверка интерфейса
    validate_interface "$INTERFACE"
    
    # Проверка опциональных параметров
    validate_ip_part "$SUBNET" "SUBNET"
    validate_ip_part "$HOST" "HOST"
    
    # Выполнение сканирования
    perform_scan "$PREFIX" "$INTERFACE" "$SUBNET" "$HOST"
}

# Запуск основной функции
main "$@"
