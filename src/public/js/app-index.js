/**
 * Скрипт для главной страницы с ссылками на устройства
 */

document.addEventListener('DOMContentLoaded', () => {
    const logEl = document.getElementById('log');
    
    // Функция логгирования
    function log(message) {
        const timestamp = new Date().toLocaleTimeString();
        logEl.innerHTML += `[${timestamp}] ${message}<br>`;
        logEl.scrollTop = logEl.scrollHeight;
    }
    
    // Проверка поддержки Web Serial API
    if (!navigator.serial) {
        log('ВНИМАНИЕ: Web Serial API не поддерживается этим браузером!');
        log('Используйте Google Chrome или Microsoft Edge на HTTPS или localhost.');
    } else {
        log('Web Serial API доступен. Выберите устройство для работы.');
    }
    
    log('Добро пожаловать! Выберите устройство для начала работы.');
});
