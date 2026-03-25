/**
 * Основное приложение для работы с приборами через Web Serial API
 */

document.addEventListener('DOMContentLoaded', () => {
    // Элементы МИТ 8
    const mitConnectBtn = document.getElementById('mitConnectBtn');
    const mitDisconnectBtn = document.getElementById('mitDisconnectBtn');
    const mitStatusEl = document.getElementById('mitStatus');
    const mitTemp1El = document.getElementById('mitTemp1');
    const mitTemp2El = document.getElementById('mitTemp2');
    const mitTemp3El = document.getElementById('mitTemp3');
    
    // Элементы М90
    const m90ConnectBtn = document.getElementById('m90ConnectBtn');
    const m90DisconnectBtn = document.getElementById('m90DisconnectBtn');
    const m90CheckConnectionBtn = document.getElementById('m90CheckConnectionBtn');
    const m90ReadTempBtn = document.getElementById('m90ReadTempBtn');
    const m90SetTempBtn = document.getElementById('m90SetTempBtn');
    const m90StopTempBtn = document.getElementById('m90StopTempBtn');
    const m90StatusEl = document.getElementById('m90Status');
    const m90DeviceTypeEl = document.getElementById('m90DeviceType');
    const m90SerialNumberEl = document.getElementById('m90SerialNumber');
    const m90TemperatureCEl = document.getElementById('m90TemperatureC');
    const m90TemperatureKEl = document.getElementById('m90TemperatureK');
    const m90FileOpenedEl = document.getElementById('m90FileOpened');
    const m90SetPointInput = document.getElementById('m90SetPoint');
    const m90ProcessStatusEl = document.getElementById('m90ProcessStatus');
    
    const logEl = document.getElementById('log');
    
    let mitDevice = null;
    let m90Device = null;
    let mitUpdateInterval = null;

    // Функция логгирования
    function log(message) {
        const timestamp = new Date().toLocaleTimeString();
        logEl.innerHTML += `[${timestamp}] ${message}<br>`;
        logEl.scrollTop = logEl.scrollHeight;
    }

    // ==================== МИТ 8 ====================
    
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
            // Если не работает, попробуйте 115200
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
            
            // Запускаем периодическое обновление температуры каждые 5 секунд
            mitUpdateInterval = setInterval(async () => {
                if (mitDevice && mitDevice.isConnected) {
                    try {
                        await mitDevice.getTemperature();
                    } catch (e) {
                        console.log('Ошибка получения температуры МИТ 8:', e.message);
                    }
                }
            }, 5000);
            
        } catch (error) {
            log('Ошибка подключения к МИТ 8: ' + error.message);
            mitStatusEl.textContent = 'Ошибка';
            mitStatusEl.className = 'status error';
        }
    });

    // Отключение МИТ 8
    mitDisconnectBtn.addEventListener('click', async () => {
        if (mitUpdateInterval) {
            clearInterval(mitUpdateInterval);
            mitUpdateInterval = null;
        }
        
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

    // ==================== М90 ====================
    
    // Подключение М90
    m90ConnectBtn.addEventListener('click', async () => {
        try {
            log('Запрос порта у пользователя для М90...');
            
            m90Device = new M90Device();
            
            // Обработчик обновления данных от М90
            m90Device.onDataUpdate = (result) => {
                if (result.error) {
                    log('Ошибка М90: ' + result.error);
                    return;
                }
                
                // Обновляем информацию на экране
                if (result.deviceType) {
                    m90DeviceTypeEl.textContent = result.deviceType;
                }
                if (result.serialNumber) {
                    m90SerialNumberEl.textContent = result.serialNumber;
                }
                if (result.temperatureCelsius !== null) {
                    m90TemperatureCEl.textContent = result.temperatureCelsius.toFixed(2) + ' °C';
                }
                if (result.temperatureKelvin !== null) {
                    m90TemperatureKEl.textContent = result.temperatureKelvin.toFixed(2) + ' K';
                }
                if (result.fileOpened !== undefined) {
                    m90FileOpenedEl.textContent = result.fileOpened ? 'Да' : 'Нет';
                }
            };
            
            // Подключение к порту (9600 - стандартная скорость для М90)
            await m90Device.connect(9600);
            
            m90StatusEl.textContent = 'Подключено';
            m90StatusEl.className = 'status connected';
            m90ConnectBtn.disabled = true;
            m90DisconnectBtn.disabled = false;
            m90CheckConnectionBtn.disabled = false;
            m90ReadTempBtn.disabled = false;
            m90SetTempBtn.disabled = false;
            
            log('Успешное подключение к М90');
            
            // Автоматическая проверка подключения и чтение данных после подключения
            setTimeout(async () => {
                try {
                    log('Автоматическая проверка подключения...');
                    const success = await m90Device.checkConnection();
                    
                    if (success) {
                        log('Устройство подтверждено. Чтение данных...');
                        // Обновляем тип прибора в интерфейсе
                        m90DeviceTypeEl.textContent = 'ЭЛЕМЕР-КТ (тип 64)';
                        
                        // Читаем температуру
                        const temp = await m90Device.obtainData();
                        if (temp && temp.celsius !== null && temp.celsius !== undefined) {
                            log(`Температура: ${temp.celsius.toFixed(2)}°C`);
                            m90TemperatureCEl.textContent = temp.celsius.toFixed(2) + ' °C';
                            if (temp.kelvin !== null && temp.kelvin !== undefined) {
                                m90TemperatureKEl.textContent = temp.kelvin.toFixed(2) + ' K';
                            }
                        } else {
                            log('Не удалось получить температуру');
                        }
                        
                        // Серийный номер (пока заглушка, т.к. в протоколе нет явной команды чтения серийного номера)
                        m90SerialNumberEl.textContent = 'Не поддерживается';
                        
                        m90StatusEl.textContent = 'Подключено и проверено';
                        m90StatusEl.className = 'status connected';
                    } else {
                        log('Проверка подключения не удалась');
                        m90StatusEl.textContent = 'Ошибка проверки';
                        m90StatusEl.className = 'status error';
                    }
                } catch (error) {
                    log('Ошибка при автоматической проверке: ' + error.message);
                }
            }, 500);
            
        } catch (error) {
            log('Ошибка подключения к М90: ' + error.message);
            m90StatusEl.textContent = 'Ошибка';
            m90StatusEl.className = 'status error';
        }
    });

    // Отключение М90
    m90DisconnectBtn.addEventListener('click', async () => {
        if (m90Device) {
            await m90Device.disconnect();
            m90Device = null;
        }
        
        m90StatusEl.textContent = 'Отключено';
        m90StatusEl.className = 'status disconnected';
        m90ConnectBtn.disabled = false;
        m90DisconnectBtn.disabled = true;
        m90CheckConnectionBtn.disabled = true;
        m90ReadTempBtn.disabled = true;
        m90SetTempBtn.disabled = true;
        m90StopTempBtn.disabled = true;
        
        m90DeviceTypeEl.textContent = '--';
        m90SerialNumberEl.textContent = '--';
        m90TemperatureCEl.textContent = '--';
        m90TemperatureKEl.textContent = '--';
        m90FileOpenedEl.textContent = '--';
        m90ProcessStatusEl.textContent = 'Статус: Ожидание...';
        
        log('Отключено от М90');
    });

    // Проверка подключения М90 (полный цикл)
    m90CheckConnectionBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Начало проверки подключения к М90...');
            m90StatusEl.textContent = 'Проверка...';
            m90StatusEl.className = 'status working';
            
            const success = await m90Device.checkConnection();
            
            if (success) {
                log('Проверка подключения успешна!');
                m90StatusEl.textContent = 'Подключено и проверено';
                m90StatusEl.className = 'status connected';
            } else {
                log('Проверка подключения не удалась');
                m90StatusEl.textContent = 'Ошибка проверки';
                m90StatusEl.className = 'status error';
            }
        } catch (error) {
            log('Ошибка при проверке подключения: ' + error.message);
            m90StatusEl.textContent = 'Ошибка';
            m90StatusEl.className = 'status error';
        }
    });

    // Чтение температуры М90
    m90ReadTempBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Чтение температуры с М90...');
            
            const temp = await m90Device.obtainData();
            
            if (temp && temp.celsius !== null) {
                log(`Температура: ${temp.celsius.toFixed(2)}°C`);
                m90TemperatureCEl.textContent = temp.celsius.toFixed(2) + ' °C';
                if (temp.kelvin !== null) {
                    m90TemperatureKEl.textContent = temp.kelvin.toFixed(2) + ' K';
                }
            } else {
                log('Не удалось прочитать температуру');
            }
        } catch (error) {
            log('Ошибка чтения температуры: ' + error.message);
        }
    });

    // Установка температуры калибровки
    m90SetTempBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            const setPoint = parseFloat(m90SetPointInput.value);
            
            if (isNaN(setPoint)) {
                log('Введите корректное значение температуры');
                return;
            }
            
            log(`Установка температуры калибровки: ${setPoint}°C...`);
            m90ProcessStatusEl.textContent = `Статус: Нагрев до ${setPoint}°C...`;
            
            const success = await m90Device.setCalibrationTemperature(setPoint);
            
            if (success) {
                log(`Температура ${setPoint}°C установлена успешно`);
                m90ProcessStatusEl.textContent = `Статус: Поддержание ${setPoint}°C`;
            } else {
                log('Не удалось установить температуру');
                m90ProcessStatusEl.textContent = 'Статус: Ошибка установки';
            }
        } catch (error) {
            log('Ошибка установки температуры: ' + error.message);
            m90ProcessStatusEl.textContent = 'Статус: Ошибка';
        }
    });

    // Стоп / Выключение нагрева
    m90StopTempBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Остановка нагрева и выключение регулятора...');
            m90ProcessStatusEl.textContent = 'Статус: Остановка...';
            
            const success = await m90Device.stopCalibration();
            
            if (success) {
                log('Нагрев остановлен, регулятор выключен');
                m90ProcessStatusEl.textContent = 'Статус: Остановлено';
            } else {
                log('Не удалось остановить нагрев');
                m90ProcessStatusEl.textContent = 'Статус: Ошибка остановки';
            }
        } catch (error) {
            log('Ошибка остановки: ' + error.message);
            m90ProcessStatusEl.textContent = 'Статус: Ошибка';
        }
    });

    // Инициализация
    mitDisconnectBtn.disabled = true;
    m90DisconnectBtn.disabled = true;
    m90CheckConnectionBtn.disabled = true;
    m90ReadTempBtn.disabled = true;
    m90SetTempBtn.disabled = true;
    m90StopTempBtn.disabled = true;
    
    mitStatusEl.textContent = 'Готов к подключению';
    mitStatusEl.className = 'status ready';
    m90StatusEl.textContent = 'Готов к подключению';
    m90StatusEl.className = 'status ready';
    
    // Проверка поддержки Web Serial API
    if (!navigator.serial) {
        log('ВНИМАНИЕ: Web Serial API не поддерживается этим браузером!');
        log('Используйте Google Chrome или Microsoft Edge на HTTPS или localhost.');
        mitStatusEl.textContent = 'API не поддерживается';
        mitStatusEl.className = 'status error';
        m90StatusEl.textContent = 'API не поддерживается';
        m90StatusEl.className = 'status error';
        mitConnectBtn.disabled = true;
        m90ConnectBtn.disabled = true;
    } else {
        log('Web Serial API доступен. Выберите устройство и нажмите "Подключиться".');
    }
});
