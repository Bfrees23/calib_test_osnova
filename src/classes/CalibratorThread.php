<?php
/**
 * Класс для работы с калибраторами M90
 */

require_once __DIR__ . '/DeviceManager.php';

class CalibratorThread {
    private $deviceManager;
    private $index;
    private $portName;
    private $serialNumber = '';
    private $deviceName = '';
    private $state = 0;
    private $procedure = 'checkConnection';
    private $temperature = ['celsius' => '-', 'kelvin' => '-'];
    private $accuracy = '-';
    private $isReadyToCalibrate = false;
    private $adjusterState = 'unknown'; // unknown, on, off
    private $stabilizationTime = '';
    private $setPoint = 0;
    
    // Команды для калибратора (из Delphi кода)
    private $commands = [
        'checkConnection' => [
            ['name' => 'Тип', 'command' => ':', 'timeout' => 2000],
            ['name' => 'FLASH', 'command' => '!F', 'timeout' => 2000],
            ['name' => 'Серийный номер', 'command' => '!', 'timeout' => 2000]
        ],
        'obtainData' => [
            ['name' => 'FLASH', 'command' => '!F', 'timeout' => 2000],
            ['name' => 'Температура', 'command' => 'T', 'timeout' => 2000],
            ['name' => 'Файл 76', 'command' => '!R76', 'timeout' => 2000],
            ['name' => 'RAM', 'command' => '!R', 'timeout' => 2000],
            ['name' => 'Файл 0', 'command' => '!R0', 'timeout' => 2000]
        ],
        'prepareToCalibration' => [
            ['name' => 'FLASH', 'command' => '!F', 'timeout' => 2000],
            ['name' => 'Файл 63', 'command' => '!R63', 'timeout' => 2000],
            ['name' => 'Запись 63', 'command' => '!W63', 'timeout' => 2000],
            ['name' => 'Файл 76', 'command' => '!R76', 'timeout' => 2000],
            ['name' => 'Запись 76', 'command' => '!W76', 'timeout' => 2000]
        ]
    ];
    
    public function __construct($index) {
        $this->index = $index;
        $this->deviceManager = DeviceManager::getInstance();
        $this->deviceName = "M90 {$index}";
    }
    
    /**
     * Подключение к калибратору
     */
    public function connect($portName) {
        $this->portName = $portName;
        $this->deviceManager->log("[M90 {$this->index}] Подключение к порту {$portName}");
        
        $fp = $this->deviceManager->connectToPort($portName);
        if ($fp) {
            $this->procedure = 'checkConnection';
            return true;
        }
        return false;
    }
    
    /**
     * Отключение от калибратора
     */
    public function disconnect() {
        $this->deviceManager->log("[M90 {$this->index}] Отключение");
        $this->procedure = 'idle';
        $this->state = 0;
    }
    
    /**
     * Проверка подключения
     */
    public function checkConnection() {
        $this->deviceManager->log("[M90 {$this->index}] Проверка подключения");
        
        // Отправляем команду подтверждения типа
        $command = $this->deviceManager->buildCommandWithCRC(':');
        $answer = $this->sendCommand($command);
        
        if ($answer === '64') {
            $this->state |= DeviceManager::STATE_TYPE_CONFIRMED;
            $this->deviceManager->log("[M90 {$this->index}] Тип подтвержден");
            
            // Получаем серийный номер
            $command = $this->deviceManager->buildCommandWithCRC('!');
            $answer = $this->sendCommand($command);
            
            if (!empty($answer) && $answer !== '64') {
                $this->serialNumber = $answer;
                $this->state |= DeviceManager::STATE_SERIAL_CONFIRMED;
                $this->deviceName = "M90 {$this->serialNumber}";
                $this->deviceManager->log("[M90 {$this->index}] Серийный номер: {$this->serialNumber}");
                
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Получение данных от калибратора
     */
    public function obtainData() {
        if (!($this->state & DeviceManager::STATE_TYPE_CONFIRMED)) {
            return false;
        }
        
        // Читаем температуру
        $command = $this->deviceManager->buildCommandWithCRC('T');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            $tempValue = floatval($answer);
            if ($tempValue !== -1000000.0) { // MIT_NULL_DATA
                $this->temperature['celsius'] = number_format($tempValue, 2);
                $this->temperature['kelvin'] = number_format($tempValue + 273.15, 2);
                $this->deviceManager->log("[M90 {$this->index}] Температура: {$this->temperature['celsius']}°C");
            }
        }
        
        // Читаем файл 76 (состояние регулятора)
        $command = $this->deviceManager->buildCommandWithCRC('!R76');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            $this->parseFile76($answer);
        }
        
        // Читаем файл 0 (параметры регулировки)
        $command = $this->deviceManager->buildCommandWithCRC('!R0');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            $this->parseFile0($answer);
        }
        
        return true;
    }
    
    /**
     * Подготовка к калибровке
     */
    public function prepareToCalibration($setPoint) {
        $this->setPoint = $setPoint;
        $this->procedure = 'prepareToCalibration';
        
        $this->deviceManager->log("[M90 {$this->index}] Подготовка к калибровке, уставка: {$setPoint}");
        
        // Читаем файл 63 (параметры регулятора)
        $command = $this->deviceManager->buildCommandWithCRC('!R63');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            // Формируем новые параметры
            $newParams = $this->prepareFile63($answer, $setPoint);
            
            // Записываем файл 63
            $command = $this->deviceManager->buildCommandWithCRC('!W63' . $newParams);
            $answer = $this->sendCommand($command);
            
            if ($answer === '$0') {
                $this->deviceManager->log("[M90 {$this->index}] Параметры записаны успешно");
            }
        }
        
        // Включаем регулятор (файл 76)
        $command = $this->deviceManager->buildCommandWithCRC('!R76');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            $newFile76 = $this->prepareFile76($answer);
            $command = $this->deviceManager->buildCommandWithCRC('!W76' . $newFile76);
            $answer = $this->sendCommand($command);
            
            if ($answer === '$0') {
                $this->adjusterState = 'on';
                $this->deviceManager->log("[M90 {$this->index}] Регулятор включен");
            }
        }
        
        $this->procedure = 'obtainData';
        return true;
    }
    
    /**
     * Выключение регулятора
     */
    public function turnOffRegulator() {
        $this->deviceManager->log("[M90 {$this->index}] Выключение регулятора");
        
        $command = $this->deviceManager->buildCommandWithCRC('!R76');
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            // Выключаем бит включения
            $bytes = $this->deviceManager->hexStringToByteArray($answer);
            $bytes[0] = $bytes[0] & ~1; // Clear bit 0
            
            $crc = $this->deviceManager->calcCRC8($bytes);
            $bytes[count($bytes) - 1] = $crc;
            
            $hexString = $this->deviceManager->byteArrayToHexString($bytes);
            $command = $this->deviceManager->buildCommandWithCRC('!W76' . $hexString);
            $answer = $this->sendCommand($command);
            
            if ($answer === '$0') {
                $this->adjusterState = 'off';
                $this->deviceManager->log("[M90 {$this->index}] Регулятор выключен");
            }
        }
    }
    
    /**
     * Отправка команды и получение ответа
     */
    private function sendCommand($command) {
        // Эмуляция отправки команды (для веб-интерфейса)
        // В реальной реализации здесь будет работа с COM-портом
        
        $this->deviceManager->log("[M90 {$this->index}] --> {$command}");
        
        // Для демонстрации возвращаем тестовые данные
        // В продакшене здесь будет реальное чтение из порта
        return $this->simulateAnswer($command);
    }
    
    /**
     * Симуляция ответа устройства (для тестирования)
     */
    private function simulateAnswer($command) {
        // Здесь должна быть реальная работа с портом
        // Для демонстрации возвращаем фиктивные данные
        
        if (strpos($command, ':') !== false) {
            return '64'; // Подтверждение типа
        }
        
        if (strpos($command, '!') !== false && strpos($command, '!R') === false && strpos($command, '!W') === false) {
            return 'SN123456'; // Серийный номер
        }
        
        if (strpos($command, 'T') !== false) {
            return '25.5'; // Температура
        }
        
        if (strpos($command, '!R76') !== false) {
            return '01000000000000000000000A'; // Файл 76
        }
        
        if (strpos($command, '!R0') !== false) {
            return '00000000000000000000000000000000000000000000'; // Файл 0
        }
        
        if (strpos($command, '!R63') !== false) {
            return '000000000000000000'; // Файл 63
        }
        
        if (strpos($command, '!W') !== false) {
            return '$0'; // Подтверждение записи
        }
        
        return '';
    }
    
    /**
     * Парсинг файла 76
     */
    private function parseFile76($hexData) {
        $bytes = $this->deviceManager->hexStringToByteArray($hexData);
        
        if (isset($bytes[0])) {
            if (($bytes[0] & 1) === 1) {
                $this->adjusterState = 'on';
            } else {
                $this->adjusterState = 'off';
            }
        }
    }
    
    /**
     * Парсинг файла 0
     */
    private function parseFile0($hexData) {
        // Парсим данные о состоянии стабилизации
        $bytes = $this->deviceManager->hexStringToByteArray($hexData);
        
        if (count($bytes) >= 20) {
            $hours = $bytes[16];
            $minutes = $bytes[17];
            $seconds = $bytes[18];
            
            if ($hours > 0 || $minutes > 0 || $seconds > 0) {
                $this->state |= DeviceManager::STATE_ADJUSTED;
                $this->stabilizationTime = sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds);
            } else {
                $this->state &= ~DeviceManager::STATE_ADJUSTED;
                $this->stabilizationTime = '';
            }
        }
    }
    
    /**
     * Подготовка файла 63 для записи
     */
    private function prepareFile63($hexData, $setPoint) {
        $bytes = $this->deviceManager->hexStringToByteArray($hexData);
        
        // Устанавливаем уставку (упрощенно)
        // В реальной реализации нужно правильно конвертировать float в bytes
        
        // Рассчитываем CRC
        $crc = $this->deviceManager->calcCRC8($bytes);
        $bytes[count($bytes) - 1] = $crc;
        
        return $this->deviceManager->byteArrayToHexString($bytes);
    }
    
    /**
     * Подготовка файла 76 для записи (включение регулятора)
     */
    private function prepareFile76($hexData) {
        $bytes = $this->deviceManager->hexStringToByteArray($hexData);
        
        // Включаем бит 0
        $bytes[0] = $bytes[0] | 1;
        
        // Пересчитываем CRC
        $crc = $this->deviceManager->calcCRC8($bytes);
        $bytes[count($bytes) - 1] = $crc;
        
        return $this->deviceManager->byteArrayToHexString($bytes);
    }
    
    /**
     * Установка температуры калибровки
     */
    public function setCalibrationTemperature($temperature) {
        $this->setPoint = $temperature;
        $this->deviceManager->log("[M90 {$this->index}] Уставка температуры: {$temperature}");
    }
    
    /**
     * Получение статуса калибратора
     */
    public function getStatus() {
        return [
            'index' => $this->index,
            'deviceName' => $this->deviceName,
            'serialNumber' => $this->serialNumber,
            'portName' => $this->portName,
            'procedure' => $this->procedure,
            'temperature' => $this->temperature,
            'accuracy' => $this->accuracy,
            'adjusterState' => $this->adjusterState,
            'stabilizationTime' => $this->stabilizationTime,
            'isReadyToCalibrate' => $this->isReadyToCalibrate,
            'setPoint' => $this->setPoint
        ];
    }
}
