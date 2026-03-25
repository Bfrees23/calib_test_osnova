#!/bin/bash

echo "=========================================="
echo "  Запуск сервера ЭЛЕМЕР-КТ (М90) в WSL   "
echo "=========================================="

# Проверка наличия Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Ошибка: Node.js не найден."
    echo "Установите его командой: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
fi

# Проверка наличия USB устройства
echo "🔍 Поиск подключенных USB устройств..."
if ls /dev/ttyUSB* 1> /dev/null 2>&1; then
    echo "✅ Найдено устройство: $(ls /dev/ttyUSB*)"
elif ls /dev/ttyACM* 1> /dev/null 2>&1; then
    echo "✅ Найдено устройство: $(ls /dev/ttyACM*)"
else
    echo "⚠️  Внимание: USB устройство не найдено в /dev/ttyUSB* или /dev/ttyACM*"
    echo "   Убедитесь, что вы выполнили проброс порта из Windows через usbipd:"
    echo "   1. В Windows (PowerShell Admin): usbipd bind --busid <BUSID>"
    echo "   2. В Windows (PowerShell Admin): usbipd attach --wsl --busid <BUSID>"
    echo ""
fi

echo ""
echo "🚀 Запуск веб-сервера..."
echo "Откройте браузер по адресу: http://localhost:3000"
echo "(Нажмите Ctrl+C для остановки)"
echo "=========================================="

# Запуск сервера
npx http-server . -p 3000 -c-1 --cors
