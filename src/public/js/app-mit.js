/**
 * Основное приложение для работы с МИТ 8 через Web Serial API
 */

document.addEventListener('DOMContentLoaded', () => {
    // Элементы МИТ 8
    const mitConnectBtn = document.getElementById('mitConnectBtn');
    const mitDisconnectBtn = document.getElementById('mitDisconnectBtn');
    const mitStatusEl = document.getElementById('mitStatus');
    const mitTemp1El = document.getElementById('mitTemp1');
    const mitTemp2El = document.getElementById('mitTemp2');
    const mitTemp3El = document.getElementById('mitTemp3');
    
    const logEl = document.getElementById('log');
    
    let mitDevice = null;

    // Функция логгирования
    function log(message) {
        const timestamp = new Date().toLocaleTimeString();
        logEl.innerHTML += `[${timestamp}] ${message}<br>`;
        logEl.scrollTop = logEl.scrollHeight;
    }

    // Подключение МИТ 8
    mitConnectBtn.addEventListener('click', async () => {
        try {
            log('Запрос порта у пользователя для МИТ 8...');
            
            mitDevice = new MIT8Device();
            
            // Обработчик обновления данных - вызывается автоматически при получении данных от МИТ
            mitDevice.onDataUpdate = (channels) => {
                if (channels[0] !== null) {
                    mitTemp1El.textContent = channels[0].toFixed(2) + ' °C';
                } else {
                    mitTemp1El.textContent = '-';
                }
                if (channels[1] !== null) {
                    mitTemp2El.textContent = channels[1].toFixed(2) + ' °C';
                } else {
                    mitTemp2El.textContent = '-';
                }
                if (channels[2] !== null) {
                    mitTemp3El.textContent = channels[2].toFixed(2) + ' °C';
                } else {
                    mitTemp3El.textContent = '-';
                }
            };
            
            // Подключение к порту (9600 - стандартная скорость для МИТ)
            await mitDevice.connect(9600);
            
            mitStatusEl.textContent = 'Подключено';
            mitStatusEl.className = 'status connected';
            mitConnectBtn.disabled = true;
            mitDisconnectBtn.disabled = false;
            
            log('Успешное подключение к МИТ 8. Ожидание данных...');
            
            // Проверка подключения - ждем первые данные
            const isConnected = await mitDevice.checkConnection();
            if (isConnected) {
                log('Данные от МИТ 8 получены успешно');
            } else {
                log('Внимание: данные от МИТ 8 не поступают. Проверьте настройки прибора.');
            }
            
        } catch (error) {
            log('Ошибка подключения к МИТ 8: ' + error.message);
            mitStatusEl.textContent = 'Ошибка';
            mitStatusEl.className = 'status error';
        }
    });

    // Отключение МИТ 8
    mitDisconnectBtn.addEventListener('click', async () => {
        if (mitDevice) {
            await mitDevice.disconnect();
            mitDevice = null;
        }
        
        mitStatusEl.textContent = 'Отключено';
        mitStatusEl.className = 'status disconnected';
        mitConnectBtn.disabled = false;
        mitDisconnectBtn.disabled = true;
        
        mitTemp1El.textContent = '--';
        mitTemp2El.textContent = '--';
        mitTemp3El.textContent = '--';
        
        log('Отключено от МИТ 8');
    });

    // Инициализация
    mitDisconnectBtn.disabled = true;
    mitStatusEl.textContent = 'Готов к подключению';
    mitStatusEl.className = 'status ready';
    
    // Проверка поддержки Web Serial API
    if (!navigator.serial) {
        log('ВНИМАНИЕ: Web Serial API не поддерживается этим браузером!');
        log('Используйте Google Chrome или Microsoft Edge на HTTPS или localhost.');
        mitStatusEl.textContent = 'API не поддерживается';
        mitStatusEl.className = 'status error';
        mitConnectBtn.disabled = true;
    } else {
        log('Web Serial API доступен. Выберите устройство и нажмите "Подключиться".');
    }
});
