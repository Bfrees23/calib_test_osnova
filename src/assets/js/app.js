/**
 * JavaScript приложение для управления приборами
 */

const API_BASE = '/api/devices.php';

// Состояние приложения
const appState = {
    mit: {
        connected: false,
        port: ''
    },
    calibrators: {},
    correctors: {}
};

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    loadPorts();
    setupEventListeners();
    updateStatus('Готов к работе');
});

/**
 * Загрузка списка COM-портов
 */
async function loadPorts() {
    try {
        const response = await fetch(`${API_BASE}?action=getPorts`);
        const data = await response.json();
        
        if (data.success) {
            populatePortSelects(data.ports);
        }
    } catch (error) {
        console.error('Ошибка загрузки портов:', error);
        // Для демонстрации добавляем фиктивные порты
        populatePortSelects(['COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6']);
    }
}

/**
 * Заполнение селекторов портами
 */
function populatePortSelects(ports) {
    // MIT порт
    const mitPortSelect = document.getElementById('mit-port');
    if (mitPortSelect) {
        ports.forEach(port => {
            const option = document.createElement('option');
            option.value = port;
            option.textContent = port;
            mitPortSelect.appendChild(option);
        });
    }
    
    // Порты калибраторов
    document.querySelectorAll('.calibrator-port').forEach(select => {
        ports.forEach(port => {
            const option = document.createElement('option');
            option.value = port;
            option.textContent = port;
            select.appendChild(option);
        });
    });
    
    // Порты корректоров
    document.querySelectorAll('.corrector-port').forEach(select => {
        ports.forEach(port => {
            const option = document.createElement('option');
            option.value = port;
            option.textContent = port;
            select.appendChild(option);
        });
    });
}

/**
 * Настройка обработчиков событий
 */
function setupEventListeners() {
    // MIT кнопки
    document.getElementById('mit-connect')?.addEventListener('click', () => connectMIT());
    document.getElementById('mit-disconnect')?.addEventListener('click', () => disconnectMIT());
    document.getElementById('mit-read')?.addEventListener('click', () => readMIT());
    
    // Калибраторы
    document.querySelectorAll('.calibrator-connect').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.calibrator-card');
            const index = card.dataset.index;
            connectCalibrator(index);
        });
    });
    
    document.querySelectorAll('.calibrator-disconnect').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.calibrator-card');
            const index = card.dataset.index;
            disconnectCalibrator(index);
        });
    });
    
    document.querySelectorAll('.calibrator-start-calibration').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.calibrator-card');
            const index = card.dataset.index;
            const tempInput = card.querySelector('.calibration-temp');
            startCalibration(index, tempInput.value);
        });
    });
    
    document.querySelectorAll('.calibrator-stop-calibration').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.calibrator-card');
            const index = card.dataset.index;
            stopCalibration(index);
        });
    });
    
    // Корректоры
    document.querySelectorAll('.corrector-connect').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.corrector-card');
            const index = card.dataset.index;
            connectCorrector(index);
        });
    });
    
    document.querySelectorAll('.corrector-disconnect').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.corrector-card');
            const index = card.dataset.index;
            disconnectCorrector(index);
        });
    });
    
    document.querySelectorAll('.corrector-check-connection').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.corrector-card');
            const index = card.dataset.index;
            checkCorrectorConnection(index);
        });
    });
    
    document.querySelectorAll('.corrector-obtain-data').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const card = e.target.closest('.corrector-card');
            const index = card.dataset.index;
            obtainCorrectorData(index);
        });
    });
}

/**
 * Обновление статуса в статус-баре
 */
function updateStatus(message) {
    const statusBar = document.getElementById('status-bar');
    if (statusBar) {
        statusBar.textContent = message;
    }
}

// ==================== MIT Функции ====================

async function connectMIT() {
    const portSelect = document.getElementById('mit-port');
    const port = portSelect.value;
    
    if (!port) {
        alert('Выберите порт для подключения');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}?action=connectMIT`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ port })
        });
        const data = await response.json();
        
        if (data.success) {
            appState.mit.connected = true;
            appState.mit.port = port;
            
            document.getElementById('mit-status').textContent = 'Подключено';
            document.getElementById('mit-status').className = 'value connected';
            document.getElementById('mit-serial').textContent = data.status.serialNumber || '-';
            
            // Обновляем кнопки
            document.getElementById('mit-connect').disabled = true;
            document.getElementById('mit-disconnect').disabled = false;
            document.getElementById('mit-read').disabled = false;
            
            updateStatus(`MIT подключен: ${data.status.deviceName}`);
        } else {
            alert('Ошибка подключения: ' + data.message);
        }
    } catch (error) {
        console.error('Ошибка:', error);
        alert('Ошибка подключения к MIT');
    }
}

async function disconnectMIT() {
    try {
        const response = await fetch(`${API_BASE}?action=disconnectMIT`);
        const data = await response.json();
        
        appState.mit.connected = false;
        
        document.getElementById('mit-status').textContent = 'Не подключено';
        document.getElementById('mit-status').className = 'value disconnected';
        document.getElementById('mit-serial').textContent = '-';
        
        // Сбрасываем показания температур
        for (let i = 1; i <= 3; i++) {
            document.getElementById(`mit-temp-${i}-c`).textContent = '-';
            document.getElementById(`mit-temp-${i}-k`).textContent = '-';
        }
        
        // Обновляем кнопки
        document.getElementById('mit-connect').disabled = false;
        document.getElementById('mit-disconnect').disabled = true;
        document.getElementById('mit-read').disabled = true;
        
        updateStatus('MIT отключен');
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

async function readMIT() {
    try {
        const response = await fetch(`${API_BASE}?action=readMIT`);
        const data = await response.json();
        
        if (data.success && data.temperatures) {
            for (let i = 1; i <= 3; i++) {
                const temp = data.temperatures[i];
                if (temp) {
                    document.getElementById(`mit-temp-${i}-c`).textContent = temp.celsius;
                    document.getElementById(`mit-temp-${i}-k`).textContent = temp.kelvin;
                }
            }
            updateStatus('Данные MIT обновлены');
        }
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

// ==================== Калибраторы Функции ====================

async function connectCalibrator(index) {
    const card = document.querySelector(`.calibrator-card[data-index="${index}"]`);
    const portSelect = card.querySelector('.calibrator-port');
    const port = portSelect.value;
    
    if (!port) {
        alert('Выберите порт для подключения');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}?action=connectCalibrator`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ index, port })
        });
        const data = await response.json();
        
        if (data.success) {
            appState.calibrators[index] = { connected: true, port };
            
            card.querySelector('.calibrator-status').textContent = 'Подключено';
            card.querySelector('.calibrator-status').className = 'value connected';
            
            const connectBtn = card.querySelector('.calibrator-connect');
            const disconnectBtn = card.querySelector('.calibrator-disconnect');
            const startCalibBtn = card.querySelector('.calibrator-start-calibration');
            
            connectBtn.disabled = true;
            disconnectBtn.disabled = false;
            startCalibBtn.disabled = false;
            
            updateStatus(`Калибратор ${index} подключен`);
        } else {
            alert('Ошибка подключения: ' + data.message);
        }
    } catch (error) {
        console.error('Ошибка:', error);
        alert('Ошибка подключения к калибратору');
    }
}

async function disconnectCalibrator(index) {
    try {
        const response = await fetch(`${API_BASE}?action=disconnectCalibrator&index=${index}`);
        const data = await response.json();
        
        delete appState.calibrators[index];
        
        const card = document.querySelector(`.calibrator-card[data-index="${index}"]`);
        card.querySelector('.calibrator-status').textContent = 'Не подключено';
        card.querySelector('.calibrator-status').className = 'value disconnected';
        card.querySelector('.calibrator-serial').textContent = '-';
        card.querySelector('.calibrator-temp-c').textContent = '-';
        card.querySelector('.calibrator-temp-k').textContent = '-';
        card.querySelector('.calibrator-state').textContent = '-';
        card.querySelector('.calibrator-stab-time').textContent = '-';
        
        const connectBtn = card.querySelector('.calibrator-connect');
        const disconnectBtn = card.querySelector('.calibrator-disconnect');
        const startCalibBtn = card.querySelector('.calibrator-start-calibration');
        const stopCalibBtn = card.querySelector('.calibrator-stop-calibration');
        
        connectBtn.disabled = false;
        disconnectBtn.disabled = true;
        startCalibBtn.disabled = true;
        stopCalibBtn.disabled = true;
        
        updateStatus(`Калибратор ${index} отключен`);
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

async function startCalibration(index, temperature) {
    try {
        const response = await fetch(`${API_BASE}?action=startCalibration`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ index, temperature })
        });
        const data = await response.json();
        
        if (data.success) {
            const card = document.querySelector(`.calibrator-card[data-index="${index}"]`);
            card.querySelector('.calibrator-stop-calibration').disabled = false;
            updateStatus(`Калибровка запущена (температура: ${temperature}°C)`);
        } else {
            alert('Ошибка запуска калибровки: ' + data.message);
        }
    } catch (error) {
        console.error('Ошибка:', error);
        alert('Ошибка запуска калибровки');
    }
}

async function stopCalibration(index) {
    try {
        const response = await fetch(`${API_BASE}?action=stopCalibration&index=${index}`);
        const data = await response.json();
        
        const card = document.querySelector(`.calibrator-card[data-index="${index}"]`);
        card.querySelector('.calibrator-stop-calibration').disabled = true;
        
        updateStatus('Калибровка остановлена');
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

// ==================== Корректоры Функции ====================

async function connectCorrector(index) {
    const card = document.querySelector(`.corrector-card[data-index="${index}"]`);
    const portSelect = card.querySelector('.corrector-port');
    const baudrateSelect = card.querySelector('.corrector-baudrate');
    const port = portSelect.value;
    const baudRate = parseInt(baudrateSelect.value);
    
    if (!port) {
        alert('Выберите порт для подключения');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}?action=connectCorrector`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ index, port, baudRate })
        });
        const data = await response.json();
        
        if (data.success) {
            appState.correctors[index] = { connected: true, port };
            
            card.querySelector('.corrector-status').textContent = 'Подключено';
            card.querySelector('.corrector-status').className = 'value connected';
            
            const connectBtn = card.querySelector('.corrector-connect');
            const disconnectBtn = card.querySelector('.corrector-disconnect');
            const checkConnBtn = card.querySelector('.corrector-check-connection');
            const obtainDataBtn = card.querySelector('.corrector-obtain-data');
            
            connectBtn.disabled = true;
            disconnectBtn.disabled = false;
            checkConnBtn.disabled = false;
            obtainDataBtn.disabled = false;
            
            updateStatus(`Корректор ${index} подключен`);
        } else {
            alert('Ошибка подключения: ' + data.message);
        }
    } catch (error) {
        console.error('Ошибка:', error);
        alert('Ошибка подключения к корректору');
    }
}

async function disconnectCorrector(index) {
    try {
        const response = await fetch(`${API_BASE}?action=disconnectCorrector&index=${index}`);
        const data = await response.json();
        
        delete appState.correctors[index];
        
        const card = document.querySelector(`.corrector-card[data-index="${index}"]`);
        card.querySelector('.corrector-status').textContent = 'Не подключено';
        card.querySelector('.corrector-status').className = 'value disconnected';
        card.querySelector('.corrector-name').textContent = '-';
        card.querySelector('.corrector-serial').textContent = '-';
        
        const connectBtn = card.querySelector('.corrector-connect');
        const disconnectBtn = card.querySelector('.corrector-disconnect');
        const checkConnBtn = card.querySelector('.corrector-check-connection');
        const obtainDataBtn = card.querySelector('.corrector-obtain-data');
        
        connectBtn.disabled = false;
        disconnectBtn.disabled = true;
        checkConnBtn.disabled = true;
        obtainDataBtn.disabled = true;
        
        updateStatus(`Корректор ${index} отключен`);
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

async function checkCorrectorConnection(index) {
    try {
        const response = await fetch(`${API_BASE}?action=checkCorrectorConnection&index=${index}`);
        const data = await response.json();
        
        if (data.success) {
            const card = document.querySelector(`.corrector-card[data-index="${index}"]`);
            card.querySelector('.corrector-name').textContent = data.status.deviceName || '-';
            card.querySelector('.corrector-serial').textContent = data.status.serialNumber || '-';
            updateStatus(`Корректор ${index}: проверка выполнена`);
        }
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

async function obtainCorrectorData(index) {
    try {
        const response = await fetch(`${API_BASE}?action=obtainCorrectorData&index=${index}`);
        const data = await response.json();
        
        if (data.success) {
            updateStatus(`Корректор ${index}: данные получены`);
        }
    } catch (error) {
        console.error('Ошибка:', error);
    }
}
