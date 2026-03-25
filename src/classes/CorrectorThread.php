<?php
/**
 * Класс для работы с корректорами (LKG)
 */

require_once __DIR__ . '/DeviceManager.php';

class CorrectorThread {
    private $deviceManager;
    private $index;
    private $portName;
    private $deviceName = '';
    private $serialNumber = '';
    private $procedure = 'checkConnection';
    private $isConnected = false;
    
    // Адрес корректора
    private $correctorAddress = 0x01;
    
    // Функции Modbus
    const FUNC_READ_INPUT = 0x03;
    const FUNC_READ_HOLDING = 0x04;
    const FUNC_WRITE_SINGLE = 0x10;
    const FUNC_READ_RESPONSE = 0x11;
    const FUNC_READ_WRITE = 0x17;
    
    public function __construct($index) {
        $this->index = $index;
        $this->deviceManager = DeviceManager::getInstance();
        $this->deviceName = "Корректор {$index}";
    }
    
    /**
     * Подключение к корректору
     */
    public function connect($portName, $baudRate = 9600) {
        $this->portName = $portName;
        $this->deviceManager->log("[Корректор {$this->index}] Подключение к порту {$portName}, скорость: {$baudRate}");
        
        $fp = $this->deviceManager->connectToPort($portName, $baudRate);
        if ($fp) {
            $this->procedure = 'checkConnection';
            return true;
        }
        return false;
    }
    
    /**
     * Отключение от корректора
     */
    public function disconnect() {
        $this->deviceManager->log("[Корректор {$this->index}] Отключение");
        $this->procedure = 'idle';
        $this->isConnected = false;
    }
    
    /**
     * Проверка подключения и чтение паспорта устройства
     */
    public function checkConnection() {
        $this->deviceManager->log("[Корректор {$this->index}] Чтение паспорта устройства");
        
        // Команда чтения паспорта (функция 0x11)
        $command = $this->buildCommand(self::FUNC_READ_RESPONSE);
        $answer = $this->sendCommand($command);
        
        if (!empty($answer)) {
            $passport = $this->parsePassport($answer);
            
            if ($passport) {
                $this->deviceName = "{$passport['name']} {$passport['serialNumber']}";
                $this->serialNumber = $passport['serialNumber'];
                $this->isConnected = true;
                
                $this->deviceManager->log("[Корректор {$this->index}] Устройство: {$this->deviceName}");
                
                // Инициализация LKG ключа
                $this->initializeLKG($passport);
                
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Получение данных от корректора
     */
    public function obtainData() {
        if (!$this->isConnected) {
            return false;
        }
        
        // Чтение текущих параметров
        $registers = [
            ['define' => 'REG_DATETIME', 'name' => 'Дата/время'],
            ['define' => 'REG_SERIAL', 'name' => 'Серийный номер'],
            ['define' => 'REG_LKG', 'name' => 'LKG ключ']
        ];
        
        foreach ($registers as $reg) {
            $commandParams = $this->getCommandParams($reg['define']);
            if ($commandParams) {
                $command = $this->buildCommand(
                    $commandParams['readFunc'],
                    $commandParams['firstReg'],
                    $commandParams['regAmount']
                );
                $answer = $this->sendCommand($command);
                
                if (!empty($answer)) {
                    $data = $this->convertAnswerData($answer, $commandParams);
                    $this->deviceManager->log("[Корректор {$this->index}] {$reg['name']}: {$data}");
                }
            }
        }
        
        return true;
    }
    
    /**
     * Инициализация LKG ключа
     */
    private function initializeLKG($passport) {
        $this->deviceManager->log("[Корректор {$this->index}] Инициализация LKG ключа");
        
        // Формирование LKG ключа на основе серийного номера и даты
        $lkgKey = $this->generateLKGKey($passport['serialNumber'], time());
        
        // Запись LKG ключа в устройство
        $commandParams = $this->getCommandParams('REG_INIT_LKG');
        if ($commandParams) {
            $data = $this->prepareLKGData($lkgKey);
            $command = $this->buildCommand(
                $commandParams['writeFunc'],
                $commandParams['firstReg'],
                $commandParams['regAmount'],
                $data
            );
            $answer = $this->sendCommand($command);
            
            if ($answer && $this->checkResponse($answer, 0x10)) {
                $this->deviceManager->log("[Корректор {$this->index}] LKG ключ записан успешно");
                $this->procedure = 'obtainData';
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Генерация LKG ключа
     */
    private function generateLKGKey($serialNumber, $timestamp) {
        // Алгоритм генерации LKG ключа из Delphi кода
        $dt = intval(date('dmY', $timestamp));
        $moveIndex = intval(date('m', $timestamp));
        $sn = hexdec(substr($serialNumber, -8));
        
        // Сдвиг LKG строки
        $lkgString = $this->getDongleLKG();
        $octLKG = $this->shiftLKG($lkgString, $moveIndex);
        
        // Криптоключ
        $cryptLKG = $sn ^ $dt ^ $octLKG;
        
        return [
            'lkg' => $lkgString,
            'crypt' => $cryptLKG,
            'dt' => $dt,
            'sn' => $sn
        ];
    }
    
    /**
     * Получение LKG строки из dongle
     */
    private function getDongleLKG() {
        // В реальной реализации здесь будет чтение из аппаратного ключа
        // Для эмуляции возвращаем фиктивное значение
        return 'ABCDEF1234567890';
    }
    
    /**
     * Сдвиг LKG строки
     */
    private function shiftLKG($lkg, $index) {
        $tempString = substr($lkg, $index - 1) . substr($lkg, 0, $index - 1);
        $tempString = substr($tempString, 0, 8);
        return hexdec($tempString);
    }
    
    /**
     * Построение Modbus команды
     */
    private function buildCommand($functionCode, $firstRegister = 0, $registerAmount = 0, $data = []) {
        $command = pack('C', $this->correctorAddress);
        $command .= pack('C', $functionCode);
        $command .= pack('n', $firstRegister);
        $command .= pack('n', $registerAmount);
        
        if ($functionCode === self::FUNC_WRITE_SINGLE && !empty($data)) {
            $command .= pack('C', count($data));
            $command .= implode('', array_map(function($b) { return pack('C', $b); }, $data));
        }
        
        // Добавляем CRC16
        $crc = $this->calcCRC16Modbus($command);
        $command .= pack('v', $crc);
        
        return $command;
    }
    
    /**
     * Расчет CRC16 для Modbus
     */
    private function calcCRC16Modbus($data) {
        $crc = 0xFFFF;
        for ($i = 0; $i < strlen($data); $i++) {
            $crc ^= ord($data[$i]);
            for ($j = 0; $j < 8; $j++) {
                if ($crc & 0x0001) {
                    $crc = ($crc >> 1) ^ 0xA001;
                } else {
                    $crc = $crc >> 1;
                }
            }
        }
        return $crc;
    }
    
    /**
     * Отправка команды и получение ответа
     */
    private function sendCommand($command) {
        $this->deviceManager->log("[Корректор {$this->index}] --> " . bin2hex($command));
        
        // Эмуляция ответа
        return $this->simulateAnswer($command);
    }
    
    /**
     * Симуляция ответа корректора
     */
    private function simulateAnswer($command) {
        $funcCode = ord($command[1]);
        
        if ($funcCode === self::FUNC_READ_RESPONSE) {
            // Ответ с паспортом устройства
            $passport = "EPM-12345678\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00V1.0\x00\x00\x00\x00\x00\x00\x00\x00";
            return pack('C', $this->correctorAddress) . pack('C', $funcCode) . $passport;
        }
        
        if ($funcCode === self::FUNC_WRITE_SINGLE) {
            // Подтверждение записи
            return pack('C', $this->correctorAddress) . pack('C', $funcCode) . $command[2] . $command[3] . $command[4] . $command[5];
        }
        
        return '';
    }
    
    /**
     * Парсинг паспорта устройства
     */
    private function parsePassport($data) {
        if (strlen($data) < 6) {
            return null;
        }
        
        $name = trim(substr($data, 2, 20));
        $version = trim(substr($data, 22, 12));
        $serialNumber = trim(substr($data, 34, 19));
        
        return [
            'name' => $name,
            'version' => $version,
            'serialNumber' => $serialNumber
        ];
    }
    
    /**
     * Получение параметров команды по определению
     */
    private function getCommandParams($define) {
        // Параметры регистров (из конфигурации корректора)
        $params = [
            'REG_DATETIME' => [
                'firstReg' => 0x0100,
                'regAmount' => 4,
                'readFunc' => self::FUNC_READ_INPUT,
                'dataType' => 'Time64_t'
            ],
            'REG_SERIAL' => [
                'firstReg' => 0x0104,
                'regAmount' => 4,
                'readFunc' => self::FUNC_READ_INPUT,
                'dataType' => 'Uint64'
            ],
            'REG_INIT_LKG' => [
                'firstReg' => 0x0200,
                'regAmount' => 4,
                'writeFunc' => self::FUNC_WRITE_SINGLE
            ],
            'REG_LKG' => [
                'firstReg' => 0x0204,
                'regAmount' => 2,
                'readFunc' => self::FUNC_READ_INPUT,
                'writeFunc' => self::FUNC_WRITE_SINGLE
            ]
        ];
        
        return $params[$define] ?? null;
    }
    
    /**
     * Преобразование ответа в читаемый формат
     */
    private function convertAnswerData($data, $params) {
        if (strlen($data) < 5) {
            return '';
        }
        
        $dataType = $params['dataType'] ?? '';
        
        switch ($dataType) {
            case 'Uint64':
                return unpack('J', substr($data, 2, 8))[1] ?? 0;
            case 'Uint32':
                return unpack('N', substr($data, 2, 4))[1] ?? 0;
            case 'Uint16':
                return unpack('n', substr($data, 2, 2))[1] ?? 0;
            case 'Time64_t':
                $timestamp = unpack('J', substr($data, 2, 8))[1] ?? 0;
                return date('d.m.Y H:i:s', $timestamp);
            default:
                return bin2hex(substr($data, 2));
        }
    }
    
    /**
     * Подготовка LKG данных для записи
     */
    private function prepareLKGData($lkgKey) {
        $data = [];
        
        // Упаковка криптоключа (4 байта)
        $cryptBytes = pack('N', $lkgKey['crypt']);
        for ($i = 0; $i < 4; $i++) {
            $data[] = ord($cryptBytes[$i]);
        }
        
        return $data;
    }
    
    /**
     * Проверка ответа устройства
     */
    private function checkResponse($response, $expectedFunc) {
        if (strlen($response) < 4) {
            return false;
        }
        
        $funcCode = ord($response[1]);
        return $funcCode === $expectedFunc;
    }
    
    /**
     * Выбор меню корректора
     */
    public function selectMenu($menuNumber, $menuName) {
        $this->deviceManager->log("[Корректор {$this->index}] Выбор меню: {$menuName} ({$menuNumber})");
        
        $data = pack('n', $menuNumber);
        $byteData = [];
        for ($i = 0; $i < strlen($data); $i++) {
            $byteData[] = ord($data[$i]);
        }
        
        $command = $this->buildCommand(self::FUNC_WRITE_SINGLE, 0x233, 1, $byteData);
        $answer = $this->sendCommand($command);
        
        return $this->checkResponse($answer, self::FUNC_WRITE_SINGLE);
    }
    
    /**
     * Получение статуса корректора
     */
    public function getStatus() {
        return [
            'index' => $this->index,
            'deviceName' => $this->deviceName,
            'serialNumber' => $this->serialNumber,
            'portName' => $this->portName,
            'procedure' => $this->procedure,
            'isConnected' => $this->isConnected
        ];
    }
}
