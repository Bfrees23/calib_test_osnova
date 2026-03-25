<?php
/**
 * Класс для работы с COM-портами и устройствами
 */

class DeviceManager {
    private static $instance = null;
    private $devices = [];
    private $logFile;
    
    // Состояния калибратора
    const STATE_TYPE_CONFIRMED = 1;
    const STATE_SERIAL_CONFIRMED = 2;
    const STATE_FILE_OPENED = 4;
    const STATE_ADJUSTED = 8;
    const STATE_CRC_ERROR = 16;
    const STATE_FAILED = 32;
    
    // Процедуры устройства
    const PROC_CHECK_CONNECTION = 'checkConnection';
    const PROC_OBTAIN_DATA = 'obtainData';
    const PROC_PREPARE_TO_CALIBRATION = 'prepareToCalibration';
    const PROC_TURN_OFF_REGULATOR = 'turnOffRegulator';
    
    private function __construct() {
        $this->logFile = LOGS_PATH . '/device_' . date('Y-m-d') . '.log';
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Логирование сообщений
     */
    public function log($message, $level = 'INFO') {
        $timestamp = date('Y-m-d H:i:s');
        $logEntry = "[$timestamp] [$level] $message" . PHP_EOL;
        file_put_contents($this->logFile, $logEntry, FILE_APPEND);
        
        if (DEBUG) {
            echo $logEntry;
        }
    }
    
    /**
     * Расчет CRC16 (алгоритм из Delphi кода)
     */
    public function calcCRC16($data) {
        if (empty($data)) {
            return 0xFFFF;
        }
        
        $crc = 0xFFFF;
        for ($i = 0; $i < strlen($data); $i++) {
            $crc ^= ord($data[$i]);
            for ($bit = 0; $bit < 8; $bit++) {
                if ($crc & 1) {
                    $crc = ($crc >> 1) ^ 40961;
                } else {
                    $crc = $crc >> 1;
                }
            }
        }
        return $crc;
    }
    
    /**
     * Расчет CRC8
     */
    public function calcCRC8($data) {
        $crc = 0x00;
        for ($i = 0; $i < strlen($data); $i++) {
            $crc += ord($data[$i]);
        }
        return (~$crc) & 0xFF;
    }
    
    /**
     * Проверка CRC в ответе устройства
     * Формат ответа: !DATA;CRC<CR>
     * CRC считается от строки данных с ';' в конце
     */
    public function checkCRCInAnswer($answer) {
        // Ответ должен начинаться с '!' и заканчиваться CR
        if (strlen($answer) < 4 || $answer[0] !== '!') {
            return false;
        }
        
        // Удаляем первый символ '!' и последний CR
        $cleanAnswer = trim(substr($answer, 1));
        
        // Находим последнюю точку с запятой для разделения данных и CRC
        $lastSemiIndex = strrpos($cleanAnswer, ';');
        if ($lastSemiIndex === false || $lastSemiIndex >= strlen($cleanAnswer) - 1) {
            return false;
        }
        
        // Извлекаем данные и CRC
        $dataPart = substr($cleanAnswer, 0, $lastSemiIndex);
        $receivedCRC = intval(substr($cleanAnswer, $lastSemiIndex + 1));
        
        // Считаем CRC от данных с добавленной ';'
        $calculatedCRC = $this->calcCRC16($dataPart . ';');
        
        return $calculatedCRC === $receivedCRC;
    }
    
    /**
     * Извлечение данных из ответа устройства
     * Возвращает массив данных без CRC
     */
    public function parseAnswer($answer) {
        // Ответ должен начинаться с '!' и заканчиваться CR
        if (strlen($answer) < 4 || $answer[0] !== '!') {
            return false;
        }
        
        // Удаляем первый символ '!' и последний CR
        $cleanAnswer = trim(substr($answer, 1));
        
        // Находим последнюю точку с запятой для разделения данных и CRC
        $lastSemiIndex = strrpos($cleanAnswer, ';');
        if ($lastSemiIndex === false || $lastSemiIndex >= strlen($cleanAnswer) - 1) {
            return false;
        }
        
        // Извлекаем данные и CRC
        $dataPart = substr($cleanAnswer, 0, $lastSemiIndex);
        $receivedCRC = intval(substr($cleanAnswer, $lastSemiIndex + 1));
        
        // Проверяем CRC
        $calculatedCRC = $this->calcCRC16($dataPart . ';');
        if ($calculatedCRC !== $receivedCRC) {
            $this->log("CRC ошибка! Получено: {$receivedCRC}, Ожидалось: {$calculatedCRC}", 'ERROR');
            return false;
        }
        
        // Разбиваем данные по ';'
        return explode(';', $dataPart);
    }
    
    /**
     * Получение списка доступных COM-портов
     */
    public function getAvailablePorts() {
        $ports = [];
        
        // Проверка демо-режима
        $demoMode = getenv('DEMO_MODE') === 'true';
        
        if ($demoMode) {
            return [
                'COM1 (Demo)', 
                'COM3 (Demo MIT)', 
                'COM5 (Demo M90)', 
                'COM7 (Demo LKG)'
            ];
        }
        
        // Для Linux
        if (PHP_OS === 'Linux') {
            // Попытка через glob (более надежно в контейнере)
            $patterns = ['/dev/ttyUSB*', '/dev/ttyACM*', '/dev/ttyS*'];
            foreach ($patterns as $pattern) {
                $found = glob($pattern);
                if ($found) {
                    foreach ($found as $port) {
                        $ports[] = basename($port);
                    }
                }
            }
            
            // Если ничего не найдено, пробуем shell_exec
            if (empty($ports)) {
                $output = @shell_exec('ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null');
                if ($output) {
                    $ports = array_filter(explode("\n", trim($output)));
                }
            }
        }
        // Для Windows
        elseif (PHP_OS === 'WINNT') {
            exec('mode', $output);
            foreach ($output as $line) {
                if (preg_match('/COM\d+/', $line, $matches)) {
                    $ports[] = $matches[0];
                }
            }
        }
        
        return $ports;
    }
    
    /**
     * Подключение к COM-порту
     */
    public function connectToPort($portName, $baudRate = 9600, $dataBits = 8, $parity = 'none', $stopBits = 1) {
        if (!function_exists('serialport_open')) {
            $this->log("PHP Serial extension not available", 'ERROR');
            return false;
        }
        
        $device = "/dev/{$portName}";
        $fp = serialport_open($device, $baudRate, [
            'parity' => $parity,
            'stop_bits' => $stopBits,
            'data_bits' => $dataBits,
            'flow_control' => SERIALPORT_FLOW_CONTROL_NONE
        ]);
        
        if ($fp === false) {
            $this->log("Failed to open port {$portName}", 'ERROR');
            return false;
        }
        
        $this->log("Connected to port {$portName}");
        return $fp;
    }
    
    /**
     * Отправка данных в порт
     */
    public function sendToPort($fp, $data) {
        if (is_resource($fp)) {
            serialport_write($fp, $data);
            return true;
        }
        return false;
    }
    
    /**
     * Чтение данных из порта
     */
    public function readFromPort($fp, $timeout = 2000) {
        $startTime = microtime(true) * 1000;
        $data = '';
        
        while ((microtime(true) * 1000 - $startTime) < $timeout) {
            if (is_resource($fp)) {
                $chunk = serialport_read($fp, 1024);
                if ($chunk !== false && $chunk !== '') {
                    $data .= $chunk;
                    
                    // Проверяем наличие полного ответа
                    if (strpos($data, "\r") !== false) {
                        break;
                    }
                }
            }
            usleep(10000);
        }
        
        return $data;
    }
    
    /**
     * Закрытие порта
     */
    public function closePort($fp) {
        if (is_resource($fp)) {
            serialport_close($fp);
            $this->log("Port closed");
        }
    }
    
    /**
     * Формирование команды с CRC
     * Формат: :COMMAND<CRC><CR>
     * CRC считается от строки БЕЗ двоеточия в начале
     */
    public function buildCommandWithCRC($command) {
        // Удаляем двоеточие если есть, чтобы посчитать CRC только от команды
        $cmdWithoutColon = ltrim($command, ':');
        $crc = $this->calcCRC16($cmdWithoutColon);
        return ':' . $cmdWithoutColon . $crc . chr(13); // 13 = VK_RETURN
    }
    
    /**
     * Преобразование байтового массива в HEX строку
     */
    public function byteArrayToHexString($bytes) {
        $hex = '';
        foreach ($bytes as $byte) {
            $hex .= strtoupper(str_pad(dechex($byte), 2, '0', STR_PAD_LEFT));
        }
        return $hex;
    }
    
    /**
     * Преобразование HEX строки в байтовый массив
     */
    public function hexStringToByteArray($hex) {
        $bytes = [];
        for ($i = 0; $i < strlen($hex); $i += 2) {
            $bytes[] = hexdec(substr($hex, $i, 2));
        }
        return $bytes;
    }
}
