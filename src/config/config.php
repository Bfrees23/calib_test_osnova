<?php
/**
 * Конфигурационный файл приложения
 */

// Режим отладки
define('DEBUG', true);

// Настройки подключения к COM-портам
define('DEFAULT_TIMEOUT', 2000);
define('MAX_SENDING_ATTEMPTS', 2);

// Пути
define('BASE_PATH', dirname(__DIR__));
define('LOGS_PATH', BASE_PATH . '/logs');

// Создаем директорию для логов если не существует
if (!is_dir(LOGS_PATH)) {
    mkdir(LOGS_PATH, 0755, true);
}

// Таймзона
date_default_timezone_set('Europe/Moscow');

// Кодировка
mb_internal_encoding('UTF-8');

// Настройки устройств
$deviceConfig = [
    'mit' => [
        'name' => 'MIT',
        'timeout' => 4000,
        'port_setting' => 'MITPort'
    ],
    'calibrators' => [
        'count' => 3,
        'name_prefix' => 'M90',
        'timeout' => 2000,
        'port_setting_prefix' => 'CalibratorPortNameArray'
    ],
    'correctors' => [
        'count' => 3,
        'name_prefix' => 'Corrector',
        'timeout' => 2000,
        'port_setting_prefix' => 'CorrectorPortNameArray'
    ]
];
