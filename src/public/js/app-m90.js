/**
 * Основное приложение для работы с ЭЛЕМЕР-ТК-М90К через Web Serial API
 */

document.addEventListener('DOMContentLoaded', () => {
    // Элементы М90
    const m90ConnectBtn = document.getElementById('m90ConnectBtn');
    const m90DisconnectBtn = document.getElementById('m90DisconnectBtn');
    const m90CheckConnectionBtn = document.getElementById('m90CheckConnectionBtn');
    const m90SetTempBtn = document.getElementById('m90SetTempBtn');
    const m90StatusEl = document.getElementById('m90Status');
    const m90DeviceTypeEl = document.getElementById('m90DeviceType');
    const m90SerialNumberEl = document.getElementById('m90SerialNumber');
    const m90TemperatureCEl = document.getElementById('m90TemperatureC');
    const m90TemperatureKEl = document.getElementById('m90TemperatureK');
    const m90FileOpenedEl = document.getElementById('m90FileOpened');
    const m90SetPointInput = document.getElementById('m90SetPoint');
    const m90StabTimeInput = document.getElementById('m90StabTime');
    const m90StopTempBtn = document.getElementById('m90StopTempBtn');
    const m90ProcessStatusEl = document.getElementById('m90ProcessStatus');
    
    // Элементы быстрой установки температуры
    const m90QuickTempInput = document.getElementById('m90QuickTemp');
    const m90SendQuickTempBtn = document.getElementById('m90SendQuickTempBtn');
    const m90QuickTempStatusEl = document.getElementById('m90QuickTempStatus');
    
    // Кнопки расширенных команд
    const m90ReadParamsBtn = document.getElementById('m90ReadParamsBtn');
    const m90ReadControlBtn = document.getElementById('m90ReadControlBtn');
    const m90ReadOutputBtn = document.getElementById('m90ReadOutputBtn');
    const m90OpenRAMBtn = document.getElementById('m90OpenRAMBtn');
    const m90OpenFlashBtn = document.getElementById('m90OpenFlashBtn');
    const m90UpdateFileBtn = document.getElementById('m90UpdateFileBtn');
    const m90PowerOnBtn = document.getElementById('m90PowerOnBtn');
    const m90PowerOffBtn = document.getElementById('m90PowerOffBtn');
    
    // Кнопка профилей
    const m90ProfilesBtn = document.getElementById('m90ProfilesBtn');
    
    // Элементы модального окна Flash
    const flashModal = document.getElementById('flashModal');
    const flashModalClose = document.getElementById('flashModalClose');
    const flashModalCancel = document.getElementById('flashModalCancel');
    const flashModalSend = document.getElementById('flashModalSend');
    const flashTemperature = document.getElementById('flashTemperature');
    const flashTime = document.getElementById('flashTime');
    const flashTempRate = document.getElementById('flashTempRate');
    
    // Элементы модального окна профилей
    const profilesModal = document.getElementById('profilesModal');
    const profilesModalClose = document.getElementById('profilesModalClose');
    const profilesModalCancel = document.getElementById('profilesModalCancel');
    const profilesModalSend = document.getElementById('profilesModalSend');
    const profileLoadBtn = document.getElementById('profileLoadBtn');
    const profileSaveBtn = document.getElementById('profileSaveBtn');
    const profileAddStepBtn = document.getElementById('profileAddStepBtn');
    const profileClearBtn = document.getElementById('profileClearBtn');
    const profileTableBody = document.getElementById('profileTableBody');
    const profileStepsCount = document.getElementById('profileStepsCount');
    const profileTotalTime = document.getElementById('profileTotalTime');
    const profileMinTemp = document.getElementById('profileMinTemp');
    const profileMaxTemp = document.getElementById('profileMaxTemp');
    
    // Массив для хранения шагов профиля
    let currentProfile = [];
    
    // Элементы детальной информации
    const m90AdvSetPointEl = document.getElementById('m90AdvSetPoint');
    const m90AdvPlateauEl = document.getElementById('m90AdvPlateau');
    const m90AdvSpeedEl = document.getElementById('m90AdvSpeed');
    const m90AdvRegulatorOnEl = document.getElementById('m90AdvRegulatorOn');
    const m90AdvStabTimeEl = document.getElementById('m90AdvStabTime');
    const m90AdvMinTempEl = document.getElementById('m90AdvMinTemp');
    const m90AdvMaxTempEl = document.getElementById('m90AdvMaxTemp');
    const m90AdvPropZoneEl = document.getElementById('m90AdvPropZone');
    const m90AdvDeadZoneEl = document.getElementById('m90AdvDeadZone');
    
    const logEl = document.getElementById('log');
    
    let m90Device = null;

    // Функция логгирования
    function log(message) {
        const timestamp = new Date().toLocaleTimeString();
        logEl.innerHTML += `[${timestamp}] ${message}<br>`;
        logEl.scrollTop = logEl.scrollHeight;
    }

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
                    m90TemperatureCEl.textContent = result.temperatureCelsius.toFixed(2);
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
            updateStatusIndicator('connected');
            m90ConnectBtn.disabled = true;
            m90DisconnectBtn.disabled = false;
            m90CheckConnectionBtn.disabled = false;
            m90SetTempBtn.disabled = false;
            m90StopTempBtn.disabled = false;
            m90SendQuickTempBtn.disabled = false;
            
            // Включаем расширенные кнопки
            m90ReadParamsBtn.disabled = false;
            m90ReadControlBtn.disabled = false;
            m90ReadOutputBtn.disabled = false;
            m90OpenRAMBtn.disabled = false;
            m90OpenFlashBtn.disabled = false;
            m90UpdateFileBtn.disabled = false;
            m90PowerOnBtn.disabled = false;
            m90PowerOffBtn.disabled = false;
            
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
                            m90TemperatureCEl.textContent = temp.celsius.toFixed(2);
                            if (temp.kelvin !== null && temp.kelvin !== undefined) {
                                m90TemperatureKEl.textContent = temp.kelvin.toFixed(2) + ' K';
                            }
                        } else {
                            log('Не удалось получить температуру');
                        }
                        
                        // Серийный номер (пока заглушка, т.к. в протоколе нет явной команды чтения серийного номера)
                        m90SerialNumberEl.textContent = 'Не поддерживается';
                        
                        m90StatusEl.textContent = 'Подключено и проверено';
                        updateStatusIndicator('connected');
                    } else {
                        log('Проверка подключения не удалась');
                        m90StatusEl.textContent = 'Ошибка проверки';
                        updateStatusIndicator('disconnected');
                    }
                } catch (error) {
                    log('Ошибка при автоматической проверке: ' + error.message);
                }
            }, 500);
            
        } catch (error) {
            log('Ошибка подключения к М90: ' + error.message);
            m90StatusEl.textContent = 'Ошибка';
            updateStatusIndicator('disconnected');
        }
    });
    
    // Функция обновления индикатора статуса
    function updateStatusIndicator(status) {
        const indicator = document.getElementById('m90StatusIndicator');
        if (indicator) {
            indicator.className = 'status-indicator status-' + status;
        }
    }

    // Отключение М90
    m90DisconnectBtn.addEventListener('click', async () => {
        if (m90Device) {
            await m90Device.disconnect();
            m90Device = null;
        }
        
        m90StatusEl.textContent = 'Отключено';
        updateStatusIndicator('disconnected');
        m90ConnectBtn.disabled = false;
        m90DisconnectBtn.disabled = true;
        m90CheckConnectionBtn.disabled = true;
        m90SetTempBtn.disabled = true;
        m90StopTempBtn.disabled = true;
        m90SendQuickTempBtn.disabled = true;
        
        // Отключаем расширенные кнопки
        m90ReadParamsBtn.disabled = true;
        m90ReadControlBtn.disabled = true;
        m90ReadOutputBtn.disabled = true;
        m90OpenRAMBtn.disabled = true;
        m90OpenFlashBtn.disabled = true;
        m90UpdateFileBtn.disabled = true;
        m90PowerOnBtn.disabled = true;
        m90PowerOffBtn.disabled = true;
        
        m90DeviceTypeEl.textContent = '--';
        m90SerialNumberEl.textContent = '--';
        m90TemperatureCEl.textContent = '--';
        m90TemperatureKEl.textContent = '-- K';
        m90FileOpenedEl.textContent = '--';
        
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
            updateStatusIndicator('working');
            
            const success = await m90Device.checkConnection();
            
            if (success) {
                log('Проверка подключения успешна!');
                m90StatusEl.textContent = 'Подключено и проверено';
                updateStatusIndicator('connected');
            } else {
                log('Проверка подключения не удалась');
                m90StatusEl.textContent = 'Ошибка проверки';
                updateStatusIndicator('disconnected');
            }
        } catch (error) {
            log('Ошибка при проверке подключения: ' + error.message);
            m90StatusEl.textContent = 'Ошибка';
            updateStatusIndicator('disconnected');
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
            const stabTime = parseInt(m90StabTimeInput.value) || 10;
            
            if (isNaN(setPoint)) {
                log('Введите корректное значение температуры');
                return;
            }
            
            log(`Установка температуры калибровки: ${setPoint}°C, время стабилизации: ${stabTime} мин...`);
            m90ProcessStatusEl.textContent = `Статус: Нагрев до ${setPoint}°C...`;
            
            // Устанавливаем температуру с учетом скорости нагрева и времени стабилизации
            const success = await m90Device.setCalibrationTemperatureWithRate(setPoint, stabTime);
            
            if (success) {
                log(`Температура ${setPoint}°C установлена успешно, время стабилизации: ${stabTime} мин`);
                m90ProcessStatusEl.textContent = `Статус: Поддержание ${setPoint}°C`;
                
                // Обновляем расширенную информацию
                updateAdvancedInfo();
            } else {
                log('Не удалось установить температуру');
                m90ProcessStatusEl.textContent = 'Статус: Ошибка установки';
            }
        } catch (error) {
            log('Ошибка установки температуры: ' + error.message);
            m90ProcessStatusEl.textContent = 'Статус: Ошибка';
        }
    });

    // Функция обновления расширенной информации
    async function updateAdvancedInfo() {
        try {
            // Читаем параметры регулятора
            const params = await m90Device.readRegulatorParamsStructure();
            if (params) {
                m90AdvSetPointEl.textContent = params.setpoint !== undefined ? params.setpoint.toFixed(2) + ' °C' : '--';
                m90AdvPlateauEl.textContent = params.plateau !== undefined ? params.plateau.toFixed(2) + ' °C' : '--';
                m90AdvSpeedEl.textContent = params.speed !== undefined ? params.speed.toFixed(2) + ' °C/мин' : '--';
            }
            
            // Читаем структуру управления
            const control = await m90Device.readRegulatorControlStructure();
            if (control) {
                m90AdvRegulatorOnEl.textContent = control.control?.regulatorOn ? '✅ Да' : '❌ Нет';
                m90AdvStabTimeEl.textContent = control.stabFlags?.stabilizationTimeMinutes !== undefined 
                    ? control.stabFlags.stabilizationTimeMinutes + ' мин' : '--';
                m90AdvMinTempEl.textContent = control.minTemp !== undefined ? control.minTemp + ' °C' : '--';
                m90AdvMaxTempEl.textContent = control.maxTemp !== undefined ? control.maxTemp + ' °C' : '--';
                m90AdvPropZoneEl.textContent = control.proportionalZone !== undefined ? control.proportionalZone.toFixed(2) + ' °C' : '--';
                m90AdvDeadZoneEl.textContent = control.deadZone !== undefined ? control.deadZone.toFixed(2) + ' °C' : '--';
            }
        } catch (error) {
            log('Ошибка чтения расширенной информации: ' + error.message);
        }
    }

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
                
                // Обновляем расширенную информацию
                updateAdvancedInfo();
            } else {
                log('Не удалось остановить нагрев');
                m90ProcessStatusEl.textContent = 'Статус: Ошибка остановки';
            }
        } catch (error) {
            log('Ошибка остановки: ' + error.message);
            m90ProcessStatusEl.textContent = 'Статус: Ошибка';
        }
    });

    // === Обработчики расширенных команд ===
    
    // Читать параметры регулятора
    m90ReadParamsBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Чтение параметров регулятора...');
            const params = await m90Device.readRegulatorParamsStructure();
            
            if (params) {
                log(`Параметры: Уставка=${params.setpoint.toFixed(2)}°C, Плато=${params.plateau.toFixed(2)}°C, Скорость=${params.speed.toFixed(2)}°C/мин`);
                m90AdvSetPointEl.textContent = params.setpoint.toFixed(2) + ' °C';
                m90AdvPlateauEl.textContent = params.plateau.toFixed(2) + ' °C';
                m90AdvSpeedEl.textContent = params.speed.toFixed(2) + ' °C/мин';
            } else {
                log('Не удалось прочитать параметры регулятора');
            }
        } catch (error) {
            log('Ошибка чтения параметров: ' + error.message);
        }
    });

    // Читать структуру управления
    m90ReadControlBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Чтение структуры управления...');
            const control = await m90Device.readRegulatorControlStructure();
            
            if (control) {
                log(`Управление: Регулятор=${control.control.regulatorOn ? 'ВКЛ' : 'ВЫКЛ'}, Время стаб=${control.stabFlags.stabilizationTimeMinutes} мин`);
                m90AdvRegulatorOnEl.textContent = control.control.regulatorOn ? '✅ Да' : '❌ Нет';
                m90AdvStabTimeEl.textContent = control.stabFlags.stabilizationTimeMinutes + ' мин';
                m90AdvMinTempEl.textContent = control.minTemp + ' °C';
                m90AdvMaxTempEl.textContent = control.maxTemp + ' °C';
                m90AdvPropZoneEl.textContent = control.proportionalZone.toFixed(2) + ' °C';
                m90AdvDeadZoneEl.textContent = control.deadZone.toFixed(2) + ' °C';
            } else {
                log('Не удалось прочитать структуру управления');
            }
        } catch (error) {
            log('Ошибка чтения управления: ' + error.message);
        }
    });

    // Читать выходные данные
    m90ReadOutputBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Чтение выходных данных...');
            const output = await m90Device.readOutputDataStructure();
            
            if (output) {
                log(`Температура: ${output.mainBlock.celsius}°C, Статус: ${JSON.stringify(output.status)}`);
                m90TemperatureCEl.textContent = output.mainBlock.celsius.toFixed(2) + ' °C';
                m90TemperatureKEl.textContent = output.mainBlock.kelvin.toFixed(2) + ' K';
            } else {
                log('Не удалось прочитать выходные данные');
            }
        } catch (error) {
            log('Ошибка чтения выходных данных: ' + error.message);
        }
    });

    // Открыть RAM
    m90OpenRAMBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Открытие RAM...');
            const success = await m90Device.openFile(1);
            log(success ? 'RAM открыта успешно' : 'Ошибка открытия RAM');
            m90FileOpenedEl.textContent = success ? 'Да (RAM)' : 'Нет';
        } catch (error) {
            log('Ошибка открытия RAM: ' + error.message);
        }
    });

    // Открыть Flash - теперь открывает модальное окно для ввода данных
    m90OpenFlashBtn.addEventListener('click', () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        // Предзаполняем поля текущими значениями из полей калибровки
        flashTemperature.value = m90SetPointInput.value;
        flashTime.value = m90StabTimeInput.value;
        flashTempRate.value = '5.0'; // Значение по умолчанию
        
        // Показываем модальное окно
        flashModal.classList.add('active');
    });
    
    // Закрытие модального окна (кнопка закрытия)
    flashModalClose.addEventListener('click', () => {
        flashModal.classList.remove('active');
    });
    
    // Отмена в модальном окне
    flashModalCancel.addEventListener('click', () => {
        flashModal.classList.remove('active');
    });
    
    // Отправка данных из модального окна в регулятор
    flashModalSend.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            const temperature = parseFloat(flashTemperature.value);
            const time = parseInt(flashTime.value);
            const tempRate = parseFloat(flashTempRate.value);
            
            if (isNaN(temperature) || isNaN(time) || isNaN(tempRate)) {
                log('Введите корректные значения всех параметров');
                return;
            }
            
            log(`Запись в Flash: Температура=${temperature}°C, Время=${time} мин, Скорость нагрева=${tempRate}°C/мин...`);
            
            // Закрываем модальное окно
            flashModal.classList.remove('active');
            
            // Устанавливаем температуру с учетом скорости нагрева и времени стабилизации
            const success = await m90Device.setCalibrationTemperatureWithRate(temperature, time, tempRate);
            
            if (success) {
                log(`Данные успешно записаны в Flash: ${temperature}°C, ${time} мин, ${tempRate}°C/мин`);
                
                // Обновляем расширенную информацию
                updateAdvancedInfo();
            } else {
                log('Ошибка записи данных в Flash');
            }
        } catch (error) {
            log('Ошибка при записи в Flash: ' + error.message);
        }
    });

    // ==================== УПРАВЛЕНИЕ ПРОФИЛЯМИ ====================
    
    // Открытие модального окна профилей
    m90ProfilesBtn.addEventListener('click', () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        // Очищаем профиль при открытии
        currentProfile = [];
        renderProfileTable();
        
        // Показываем модальное окно
        profilesModal.classList.add('active');
    });
    
    // Закрытие модального окна профилей
    profilesModalClose.addEventListener('click', () => {
        profilesModal.classList.remove('active');
    });
    
    // Отмена в модальном окне профилей
    profilesModalCancel.addEventListener('click', () => {
        profilesModal.classList.remove('active');
    });
    
    // Функция отрисовки таблицы профиля
    function renderProfileTable() {
        profileTableBody.innerHTML = '';
        
        let totalTime = 0;
        let minT = null;
        let maxT = null;
        
        currentProfile.forEach((step, index) => {
            const row = document.createElement('tr');
            
            const numCell = document.createElement('td');
            numCell.textContent = index + 1;
            row.appendChild(numCell);
            
            const tempCell = document.createElement('td');
            const tempInput = document.createElement('input');
            tempInput.type = 'number';
            tempInput.step = '0.1';
            tempInput.min = '-50';
            tempInput.max = '300';
            tempInput.value = step.temperature !== undefined ? step.temperature : 25.0;
            tempInput.addEventListener('change', (e) => {
                currentProfile[index].temperature = parseFloat(e.target.value);
                updateProfileStats();
            });
            tempCell.appendChild(tempInput);
            row.appendChild(tempCell);
            
            const timeCell = document.createElement('td');
            const timeInput = document.createElement('input');
            timeInput.type = 'number';
            timeInput.step = '1';
            timeInput.min = '0';
            timeInput.max = '999';
            timeInput.value = step.time !== undefined ? step.time : 10;
            timeInput.addEventListener('change', (e) => {
                currentProfile[index].time = parseInt(e.target.value);
                updateProfileStats();
            });
            timeCell.appendChild(timeInput);
            row.appendChild(timeCell);
            
            const actionsCell = document.createElement('td');
            actionsCell.className = 'profile-row-actions';
            
            // Кнопка вверх
            if (index > 0) {
                const upBtn = document.createElement('button');
                upBtn.className = 'btn-row-action btn-row-up';
                upBtn.textContent = '↑';
                upBtn.title = 'Переместить вверх';
                upBtn.addEventListener('click', () => {
                    [currentProfile[index - 1], currentProfile[index]] = [currentProfile[index], currentProfile[index - 1]];
                    renderProfileTable();
                });
                actionsCell.appendChild(upBtn);
            }
            
            // Кнопка вниз
            if (index < currentProfile.length - 1) {
                const downBtn = document.createElement('button');
                downBtn.className = 'btn-row-action btn-row-down';
                downBtn.textContent = '↓';
                downBtn.title = 'Переместить вниз';
                downBtn.addEventListener('click', () => {
                    [currentProfile[index + 1], currentProfile[index]] = [currentProfile[index], currentProfile[index + 1]];
                    renderProfileTable();
                });
                actionsCell.appendChild(downBtn);
            }
            
            // Кнопка удаления
            const deleteBtn = document.createElement('button');
            deleteBtn.className = 'btn-row-action btn-row-delete';
            deleteBtn.textContent = '✕';
            deleteBtn.title = 'Удалить шаг';
            deleteBtn.addEventListener('click', () => {
                currentProfile.splice(index, 1);
                renderProfileTable();
            });
            actionsCell.appendChild(deleteBtn);
            
            row.appendChild(actionsCell);
            profileTableBody.appendChild(row);
            
            // Статистика
            totalTime += step.time || 0;
            if (step.temperature !== undefined) {
                if (minT === null || step.temperature < minT) minT = step.temperature;
                if (maxT === null || step.temperature > maxT) maxT = step.temperature;
            }
        });
        
        // Обновление статистики
        profileStepsCount.textContent = currentProfile.length;
        profileTotalTime.textContent = totalTime;
        profileMinTemp.textContent = minT !== null ? minT.toFixed(1) : '--';
        profileMaxTemp.textContent = maxT !== null ? maxT.toFixed(1) : '--';
    }
    
    // Обновление статистики профиля
    function updateProfileStats() {
        let totalTime = 0;
        let minT = null;
        let maxT = null;
        
        currentProfile.forEach(step => {
            totalTime += step.time || 0;
            if (step.temperature !== undefined) {
                if (minT === null || step.temperature < minT) minT = step.temperature;
                if (maxT === null || step.temperature > maxT) maxT = step.temperature;
            }
        });
        
        profileStepsCount.textContent = currentProfile.length;
        profileTotalTime.textContent = totalTime;
        profileMinTemp.textContent = minT !== null ? minT.toFixed(1) : '--';
        profileMaxTemp.textContent = maxT !== null ? maxT.toFixed(1) : '--';
    }
    
    // Загрузить текущий профиль
    profileLoadBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Чтение текущего профиля из регулятора...');
            
            // Читаем текущие параметры регулятора
            const params = await m90Device.readRegulatorParamsStructure();
            
            if (params) {
                // Создаем профиль из одного шага с текущими параметрами
                currentProfile = [{
                    temperature: params.setpoint || 25.0,
                    time: params.plateau || 10
                }];
                
                renderProfileTable();
                log(`Профиль загружен: ${currentProfile.length} шаг(ов)`);
            } else {
                log('Не удалось прочитать параметры регулятора');
            }
        } catch (error) {
            log('Ошибка загрузки профиля: ' + error.message);
        }
    });
    
    // Сохранить профиль
    profileSaveBtn.addEventListener('click', () => {
        if (currentProfile.length === 0) {
            log('Профиль пуст. Добавьте хотя бы один шаг.');
            return;
        }
        
        // Сохраняем профиль в localStorage
        localStorage.setItem('m90_current_profile', JSON.stringify(currentProfile));
        log(`Профиль сохранен: ${currentProfile.length} шаг(ов), общее время: ${profileTotalTime.textContent} мин`);
    });
    
    // Добавить шаг
    profileAddStepBtn.addEventListener('click', () => {
        if (currentProfile.length >= 16) {
            log('Максимальное количество шагов в профиле - 16');
            return;
        }
        
        const lastStep = currentProfile.length > 0 ? currentProfile[currentProfile.length - 1] : null;
        const newTemp = lastStep ? lastStep.temperature : 25.0;
        
        currentProfile.push({
            temperature: newTemp,
            time: 10
        });
        
        renderProfileTable();
        log('Добавлен новый шаг в профиль');
    });
    
    // Очистить все
    profileClearBtn.addEventListener('click', () => {
        if (confirm('Вы уверены, что хотите очистить весь профиль?')) {
            currentProfile = [];
            renderProfileTable();
            log('Профиль очищен');
        }
    });
    
    // Применить профиль
    profilesModalSend.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        if (currentProfile.length === 0) {
            log('Профиль пуст. Добавьте хотя бы один шаг.');
            return;
        }
        
        try {
            log(`Применение профиля: ${currentProfile.length} шаг(ов)...`);
            
            // Закрываем модальное окно
            profilesModal.classList.remove('active');
            
            // Применяем первый шаг профиля
            const firstStep = currentProfile[0];
            log(`Установка температуры ${firstStep.temperature}°C, время стабилизации ${firstStep.time} мин...`);
            
            const speed = 5.0; // Скорость по умолчанию
            
            const success = await m90Device.setCalibrationTemperatureWithRate(
                firstStep.temperature, 
                firstStep.time, 
                speed
            );
            
            if (success) {
                log(`Первый шаг профиля применен успешно`);
                updateAdvancedInfo();
                
                // Если есть дополнительные шаги, информируем пользователя
                if (currentProfile.length > 1) {
                    log(`Внимание: Остальные ${currentProfile.length - 1} шаг(ов) требуют ручного переключения`);
                }
            } else {
                log('Ошибка применения профиля');
            }
        } catch (error) {
            log('Ошибка при применении профиля: ' + error.message);
        }
    });

    // Актуализировать файл
    m90UpdateFileBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Актуализация файла...');
            const success = await m90Device.updateFile();
            log(success ? 'Файл актуализирован успешно' : 'Ошибка актуализации');
        } catch (error) {
            log('Ошибка актуализации: ' + error.message);
        }
    });

    // Включить регулятор
    m90PowerOnBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Включение регулятора...');
            const success = await m90Device.setRegulatorPower(true);
            log(success ? 'Регулятор включен' : 'Ошибка включения регулятора');
            updateAdvancedInfo();
        } catch (error) {
            log('Ошибка включения регулятора: ' + error.message);
        }
    });

    // Выключить регулятор
    m90PowerOffBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            log('Выключение регулятора...');
            const success = await m90Device.setRegulatorPower(false);
            log(success ? 'Регулятор выключен' : 'Ошибка выключения регулятора');
            updateAdvancedInfo();
        } catch (error) {
            log('Ошибка выключения регулятора: ' + error.message);
        }
    });

    // Быстрая установка температуры (только уставка, без включения регулятора)
    m90SendQuickTempBtn.addEventListener('click', async () => {
        if (!m90Device || !m90Device.isConnected) {
            log('Сначала подключитесь к М90');
            return;
        }
        
        try {
            const quickTemp = parseFloat(m90QuickTempInput.value);
            
            if (isNaN(quickTemp)) {
                log('Введите корректное значение температуры');
                return;
            }
            
            log(`Установка уставки температуры: ${quickTemp}°C (без включения регулятора)...`);
            m90QuickTempStatusEl.textContent = `Статус: Установка ${quickTemp}°C...`;
            
            // Устанавливаем только уставку температуры, не включая регулятор
            const success = await m90Device.setTemperatureSetpointOnly(quickTemp);
            
            if (success) {
                log(`Температура ${quickTemp}°C установлена в регулятор и зафиксирована (регулятор не включен)`);
                m90QuickTempStatusEl.textContent = `Статус: Температура ${quickTemp}°C установлена`;
                
                // Обновляем расширенную информацию
                updateAdvancedInfo();
            } else {
                log('Не удалось установить температуру');
                m90QuickTempStatusEl.textContent = 'Статус: Ошибка установки';
            }
        } catch (error) {
            log('Ошибка установки температуры: ' + error.message);
            m90QuickTempStatusEl.textContent = 'Статус: Ошибка';
        }
    });

    // Инициализация
    m90DisconnectBtn.disabled = true;
    m90CheckConnectionBtn.disabled = true;
    m90SetTempBtn.disabled = true;
    m90StopTempBtn.disabled = true;
    m90SendQuickTempBtn.disabled = true;
    
    // Отключаем расширенные кнопки до подключения
    m90ReadParamsBtn.disabled = true;
    m90ReadControlBtn.disabled = true;
    m90ReadOutputBtn.disabled = true;
    m90OpenRAMBtn.disabled = true;
    m90OpenFlashBtn.disabled = true;
    m90UpdateFileBtn.disabled = true;
    m90PowerOnBtn.disabled = true;
    m90PowerOffBtn.disabled = true;
    
    m90StatusEl.textContent = 'Готов к подключению';
    m90StatusEl.className = 'status ready';
    
    // Проверка поддержки Web Serial API
    if (!navigator.serial) {
        log('ВНИМАНИЕ: Web Serial API не поддерживается этим браузером!');
        log('Используйте Google Chrome или Microsoft Edge на HTTPS или localhost.');
        m90StatusEl.textContent = 'API не поддерживается';
        m90StatusEl.className = 'status error';
        m90ConnectBtn.disabled = true;
    } else {
        log('Web Serial API доступен. Выберите устройство и нажмите "Подключиться".');
    }
});
