# Запуск проекта ЭЛЕМЕР-КТ (М90) в WSL Ubuntu

## 📋 Предварительные требования

### 1. Установка Node.js (если не установлен)
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Настройка доступа к USB в WSL

Для работы с USB-устройством в WSL необходимо пробросить порт из Windows:

#### Шаг 1: Установите usbipd в Windows (из PowerShell от имени администратора)
```powershell
winget install dorssel.usbipd-win
```

#### Шаг 2: Найдите BUSID вашего устройства
В Windows (PowerShell):
```powershell
usbipd list
```
Найдите ваше устройство (например, CH340, FTDI, CP210x) и запомните BUSID (например, `3-1`).

#### Шаг 3: Привяжите устройство
```powershell
usbipd bind --busid 3-1
```
*(замените `3-1` на ваш BUSID)*

#### Шаг 4: Подключите устройство к WSL
```powershell
usbipd attach --wsl --busid 3-1
```

После этого в WSL появится устройство `/dev/ttyUSB0` или `/dev/ttyACM0`.

---

## 🚀 Запуск проекта

### Вариант 1: Использование скрипта запуска (рекомендуется)
```bash
./start.sh
```

### Вариант 2: Ручной запуск
```bash
npx http-server . -p 3000 -c-1 --cors
```

### Вариант 3: Если установлен Python
```bash
python3 -m http.server 3000
```

---

## 🌐 Доступ к интерфейсу

Откройте браузер (в Windows или WSL) по адресу:
```
http://localhost:3000
```

---

## 🔍 Проверка подключения устройства

В WSL выполните:
```bash
ls -l /dev/ttyUSB*
# или
ls -l /dev/ttyACM*
```

Если устройство найдено, вы увидите что-то вроде:
```
crw-rw---- 1 root dialout 188, 0 дата время /dev/ttyUSB0
```

### Если устройство не видно:
1. Убедитесь, что usbipd работает в Windows
2. Проверьте, что устройство подключено к ПК
3. Повторите команды attach в Windows PowerShell

---

## ⚙️ Права доступа к порту (опционально)

Если возникают проблемы с правами доступа:
```bash
sudo usermod -aG dialout $USER
```
После этого **перезайдите в систему** или выполните:
```bash
newgrp dialout
```

---

## 🛑 Остановка сервера

Нажмите `Ctrl+C` в терминале для остановки сервера.

---

## 📝 Примечания

- Проект использует Web Serial API, который работает только в браузерах на базе Chromium (Chrome, Edge, Opera)
- Убедитесь, что вы используете совместимый браузер
- Для работы в Firefox может потребоваться дополнительная настройка
