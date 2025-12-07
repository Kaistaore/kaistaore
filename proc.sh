#!/bin/bash

# Лог-файл
LOG_FILE="proc_monitor.log"

# Функция для вывода разделителя
print_separator() {
	echo "------------------------------------------------------------------------------------------------------------------------"
}

# Запись времени запуска скрипта в лог
echo "=== Запуск скрипта: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

# Заголовок таблицы
print_separator
printf "| %-8s | %-20s | %-20s | %-12s | %-10s | %-30s |\n" \
       "PID" "Name" "Current Dir" "Max Files" "Env Vars" "Command Line"
print_separator

ls -d /proc/[0-9]*/ 2>/dev/null | while read dir; do
	pid=$(basename "$dir")
	
	if [ -L "/proc/$pid/exe" ]; then
		exe_path=$(readlink "/proc/$pid/exe" 2>/dev/null)
		
		if [ -n "$exe_path" ]; then
			process_name=$(basename "$exe_path")
			
			# Обрезаем длинное имя процесса
			if [ ${#process_name} -gt 18 ]; then
				process_name_display="${process_name:0:15}..."
			else
				process_name_display="$process_name"
			fi
			
			# 1. Текущая рабочая директория (/proc/N/cwd)
			cwd_info="N/A"
			if [ -L "/proc/$pid/cwd" ]; then
				cwd_path=$(readlink "/proc/$pid/cwd" 2>/dev/null)
				if [ -n "$cwd_path" ]; then
					cwd_base=$(basename "$cwd_path")
					if [ ${#cwd_base} -gt 18 ]; then
						cwd_info="${cwd_base:0:15}..."
					else
						cwd_info="$cwd_base"
					fi
				fi
			fi
			
			# 2. Ограничения процесса (/proc/N/limits)
			max_files_info="N/A"
			if [ -r "/proc/$pid/limits" ]; then
				max_files_info=$(grep 'Max open files' "/proc/$pid/limits" 2>/dev/null | awk '{print $4}')
				max_files_info=${max_files_info:-"N/A"}
			fi
			
			# 3. Переменные окружения (/proc/N/environ)
			env_vars_info="N/A"
			if [ -r "/proc/$pid/environ" ]; then
				env_vars_info=$(cat "/proc/$pid/environ" 2>/dev/null | tr '\0' '\n' | wc -l)
			fi
			
			# 4. Командная строка (/proc/N/cmdline)
			cmdline_info="N/A"
			if [ -r "/proc/$pid/cmdline" ]; then
				cmdline_info=$(cat "/proc/$pid/cmdline" | tr '\0' ' ' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
				if [ -n "$cmdline_info" ]; then
					if [ ${#cmdline_info} -gt 28 ]; then
						cmdline_info="${cmdline_info:0:25}..."
					fi
				else
					cmdline_info="[empty]"
				fi
			fi
			
			# Выводим строку таблицы
			printf "| %-8s | %-20s | %-20s | %-12s | %-10s | %-30s |\n" \
			       "$pid" \
			       "$process_name_display" \
			       "$cwd_info" \
			       "$max_files_info" \
			       "$env_vars_info" \
			       "$cmdline_info"
			       
			# Проверяем, является ли процесс новым (ищем PID в лог-файле)
			if ! grep -q "^PID $pid:" "$LOG_FILE" 2>/dev/null; then
				# Это новый процесс - записываем в лог
				echo "PID $pid: $process_name появился в $(date '+%H:%M:%S')" >> "$LOG_FILE"
			fi
			       
		else
			# Если не удалось прочитать exe
			printf "| %-8s | %-20s | %-20s | %-12s | %-10s | %-30s |\n" \
			       "$pid" "?" "N/A" "N/A" "N/A" "N/A"
		fi
	else
		# Если нет доступа к процессу
		printf "| %-8s | %-20s | %-20s | %-12s | %-10s | %-30s |\n" \
		       "$pid" "NO ACCESS" "N/A" "N/A" "N/A" "N/A"
	fi
done

print_separator

# Запись времени завершения скрипта в лог
echo "=== Завершение скрипта: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Выводим информацию о логе
echo ""
echo "Логирование выполнено в файл: $LOG_FILE"
echo "Новые процессы записаны в лог."
