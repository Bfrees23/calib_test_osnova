<?php
/**
 * API для работы с устройствами
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../classes/DeviceManager.php';
require_once __DIR__ . '/../classes/MITThread.php';
require_once __DIR__ . '/../classes/CalibratorThread.php';
require_once __DIR__ . '/../classes/CorrectorThread.php';

header('Content-Type: application/json');

// Получаем действие из запроса
$action = $_GET['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($action) {
        case 'getPorts':
            // Получение списка доступных COM-портов
            $deviceManager = DeviceManager::getInstance();
            echo json_encode([
                'success' => true,
                'ports' => $deviceManager->getAvailablePorts()
            ]);
            break;
            
        case 'getStatus':
            // Получение статуса всех устройств
            echo json_encode(getDevicesStatus());
            break;
            
        case 'connectMIT':
            // Подключение к MIT
            if ($method === 'POST') {
                $data = json_decode(file_get_contents('php://input'), true);
                $portName = $data['port'] ?? '';
                
                if (empty($portName)) {
                    throw new Exception('Не указан порт');
                }
                
                $mit = new MITThread();
                $result = $mit->connect($portName);
                
                echo json_encode([
                    'success' => $result,
                    'message' => $result ? 'Подключено' : 'Ошибка подключения',
                    'status' => $mit->getStatus()
                ]);
            }
            break;
            
        case 'disconnectMIT':
            // Отключение от MIT
            $mit = new MITThread();
            $mit->disconnect();
            
            echo json_encode([
                'success' => true,
                'message' => 'Отключено'
            ]);
            break;
            
        case 'readMIT':
            // Чтение данных MIT
            $mit = new MITThread();
            $result = $mit->readTemperatures();
            
            echo json_encode([
                'success' => $result,
                'temperatures' => $mit->getAllTemperatures()
            ]);
            break;
            
        case 'connectCalibrator':
            // Подключение к калибратору
            if ($method === 'POST') {
                $data = json_decode(file_get_contents('php://input'), true);
                $index = intval($data['index'] ?? 1);
                $portName = $data['port'] ?? '';
                
                if (empty($portName)) {
                    throw new Exception('Не указан порт');
                }
                
                $calibrator = new CalibratorThread($index);
                $result = $calibrator->connect($portName);
                
                echo json_encode([
                    'success' => $result,
                    'message' => $result ? 'Подключено' : 'Ошибка подключения',
                    'status' => $calibrator->getStatus()
                ]);
            }
            break;
            
        case 'disconnectCalibrator':
            // Отключение калибратора
            $index = intval($_GET['index'] ?? 1);
            $calibrator = new CalibratorThread($index);
            $calibrator->disconnect();
            
            echo json_encode([
                'success' => true,
                'message' => 'Отключено'
            ]);
            break;
            
        case 'checkCalibratorConnection':
            // Проверка подключения калибратора
            $index = intval($_GET['index'] ?? 1);
            $calibrator = new CalibratorThread($index);
            $result = $calibrator->checkConnection();
            
            echo json_encode([
                'success' => $result,
                'status' => $calibrator->getStatus()
            ]);
            break;
            
        case 'obtainCalibratorData':
            // Получение данных от калибратора
            $index = intval($_GET['index'] ?? 1);
            $calibrator = new CalibratorThread($index);
            $result = $calibrator->obtainData();
            
            echo json_encode([
                'success' => $result,
                'status' => $calibrator->getStatus()
            ]);
            break;
            
        case 'startCalibration':
            // Запуск калибровки
            if ($method === 'POST') {
                $data = json_decode(file_get_contents('php://input'), true);
                $index = intval($data['index'] ?? 1);
                $temperature = floatval($data['temperature'] ?? 25.0);
                
                $calibrator = new CalibratorThread($index);
                $result = $calibrator->prepareToCalibration($temperature);
                
                echo json_encode([
                    'success' => $result,
                    'message' => $result ? 'Калибровка запущена' : 'Ошибка запуска',
                    'status' => $calibrator->getStatus()
                ]);
            }
            break;
            
        case 'stopCalibration':
            // Остановка калибровки (выключение регулятора)
            $index = intval($_GET['index'] ?? 1);
            $calibrator = new CalibratorThread($index);
            $calibrator->turnOffRegulator();
            
            echo json_encode([
                'success' => true,
                'message' => 'Регулятор выключен'
            ]);
            break;
            
        case 'connectCorrector':
            // Подключение к корректору
            if ($method === 'POST') {
                $data = json_decode(file_get_contents('php://input'), true);
                $index = intval($data['index'] ?? 1);
                $portName = $data['port'] ?? '';
                $baudRate = intval($data['baudRate'] ?? 9600);
                
                if (empty($portName)) {
                    throw new Exception('Не указан порт');
                }
                
                $corrector = new CorrectorThread($index);
                $result = $corrector->connect($portName, $baudRate);
                
                echo json_encode([
                    'success' => $result,
                    'message' => $result ? 'Подключено' : 'Ошибка подключения',
                    'status' => $corrector->getStatus()
                ]);
            }
            break;
            
        case 'disconnectCorrector':
            // Отключение корректора
            $index = intval($_GET['index'] ?? 1);
            $corrector = new CorrectorThread($index);
            $corrector->disconnect();
            
            echo json_encode([
                'success' => true,
                'message' => 'Отключено'
            ]);
            break;
            
        case 'checkCorrectorConnection':
            // Проверка подключения корректора
            $index = intval($_GET['index'] ?? 1);
            $corrector = new CorrectorThread($index);
            $result = $corrector->checkConnection();
            
            echo json_encode([
                'success' => $result,
                'status' => $corrector->getStatus()
            ]);
            break;
            
        case 'obtainCorrectorData':
            // Получение данных от корректора
            $index = intval($_GET['index'] ?? 1);
            $corrector = new CorrectorThread($index);
            $result = $corrector->obtainData();
            
            echo json_encode([
                'success' => $result,
                'status' => $corrector->getStatus()
            ]);
            break;
            
        default:
            echo json_encode([
                'success' => false,
                'message' => 'Неизвестное действие'
            ]);
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

/**
 * Получение статуса всех устройств
 */
function getDevicesStatus() {
    $mit = new MITThread();
    
    $calibrators = [];
    for ($i = 1; $i <= 3; $i++) {
        $calibrator = new CalibratorThread($i);
        $calibrators[] = $calibrator->getStatus();
    }
    
    $correctors = [];
    for ($i = 1; $i <= 3; $i++) {
        $corrector = new CorrectorThread($i);
        $correctors[] = $corrector->getStatus();
    }
    
    return [
        'success' => true,
        'mit' => $mit->getStatus(),
        'calibrators' => $calibrators,
        'correctors' => $correctors
    ];
}
