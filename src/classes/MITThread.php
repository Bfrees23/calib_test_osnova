<?php
/**
 * Класс для работы с устройством MIT (многоканальный измеритель температуры)
 */

require_once __DIR__ . '/DeviceManager.php';

class MITThread {
    private $deviceManager;
    private $portName;
    private $serialNumber = '';
    private $deviceName = 'MIT';
    private $temperatures = [
        1 => ['celsius' => '-', 'kelvin' => '-'],
        2 => ['celsius' => '-', 'kelvin' => '-'],
        3 => ['celsius' => '-', 'kelvin' => '-']
    ];
    private $isConnected = false;
    private $isValidVerification = false;
    
    const MIT_NULL_DATA = -1000000.0;
    
    public function __construct() {
        $this->deviceManager = DeviceManager::getInstance();
    }
    
    /**
     * Подключение к MIT
     */
    public function connect($portName) {
        $this->portName = $portName;
        $this->deviceManager->log("[MIT] Подключение к порту {$portName}");
        
        $fp = $this->deviceManager->connectToPort($portName, 9600);
        if ($fp) {
            $this->isConnected = true;
            
            // Получаем серийный номер
            $this->serialNumber = $this->getSerialNumber();
            
            if (!empty($this->serialNumber)) {
                $this->deviceName = "MIT {$this->serialNumber}";
                $this->checkVerification();
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Отключение от MIT
     */
    public function disconnect() {
        $this->deviceManager->log("[MIT] Отключение");
        $this->isConnected = false;
        
        // Сбрасываем показания
        foreach ($this->temperatures as &$temp) {
            $temp = ['celsius' => '-', 'kelvin' => '-'];
        }
    }
    
    /**
     * Получение серийного номера
     */
    private function getSerialNumber() {
        // В реальной реализации здесь будет чтение из устройства
        // Для эмуляции возвращаем фиктивный номер
        return 'MIT123456';
    }
    
    /**
     * Проверка поверки устройства
     */
    private function checkVerification() {
        // Проверяем дату поверки по серийному номеру
        // В реальной реализации здесь будет запрос к базе данных
        
        $this->deviceManager->log("[MIT] Проверка даты поверки для {$this->serialNumber}");
        
        // Эмуляция: считаем что поверка действительна
        $this->isValidVerification = true;
    }
    
    /**
     * Чтение температурных данных
     */
    public function readTemperatures() {
        if (!$this->isConnected) {
            return false;
        }
        
        // Читаем данные из порта
        $data = $this->readFromDevice();
        
        if (!empty($data)) {
            $this->parseTemperatureData($data);
            return true;
        }
        
        return false;
    }
    
    /**
     * Чтение данных из устройства
     */
    private function readFromDevice() {
        // Эмуляция данных от MIT
        // Формат: "1:25.5 B 2:26.3 B 3:24.8 B "
        
        $this->deviceManager->log("[MIT] Чтение данных...");
        
        // В реальной реализации здесь будет работа с COM-портом
        return $this->simulateMITData();
    }
    
    /**
     * Симуляция данных MIT
     */
    private function simulateMITData() {
        // Генерируем случайные температуры для демонстрации
        $temp1 = 20 + rand(0, 100) / 10;
        $temp2 = 20 + rand(0, 100) / 10;
        $temp3 = 20 + rand(0, 100) / 10;
        
        return "1:{$temp1} B 2:{$temp2} B 3:{$temp3} B ";
    }
    
    /**
     * Парсинг температурных данных
     */
    private function parseTemperatureData($data) {
        // Разделяем по маркеру "B "
        $parts = explode('B ', trim($data));
        
        foreach ($parts as $part) {
            if (empty($part)) continue;
            
            // Извлекаем индекс и значение
            $colonPos = strpos($part, ':');
            if ($colonPos === false) continue;
            
            $index = intval(substr($part, 0, $colonPos));
            $valueStr = substr($part, $colonPos + 1);
            
            if ($index < 1 || $index > 4) continue;
            
            $value = floatval($valueStr);
            
            // Проверяем на NULL данные
            if ($value === self::MIT_NULL_DATA) {
                $this->temperatures[$index] = ['celsius' => '-', 'kelvin' => '-'];
                continue;
            }
            
            // Конвертируем в Кельвины
            $kelvin = $value + 273.15;
            
            $this->temperatures[$index] = [
                'celsius' => number_format($value, 2),
                'kelvin' => number_format($kelvin, 2)
            ];
            
            $this->deviceManager->log("[MIT] Канал {$index}: {$value}°C / {$kelvin}K");
        }
    }
    
    /**
     * Получение температуры по каналу
     */
    public function getTemperature($channel) {
        return $this->temperatures[$channel] ?? ['celsius' => '-', 'kelvin' => '-'];
    }
    
    /**
     * Получение всех температур
     */
    public function getAllTemperatures() {
        return $this->temperatures;
    }
    
    /**
     * Получение статуса MIT
     */
    public function getStatus() {
        return [
            'deviceName' => $this->deviceName,
            'serialNumber' => $this->serialNumber,
            'portName' => $this->portName,
            'isConnected' => $this->isConnected,
            'isValidVerification' => $this->isValidVerification,
            'temperatures' => $this->temperatures
        ];
    }
}
