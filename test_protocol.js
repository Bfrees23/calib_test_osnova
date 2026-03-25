/**
 * Тесты для проверки CRC и форматирования команд по протоколу ASCII UAIL
 * на основе документации "Протокол обмена с калибраторами температуры ЭЛЕМЕР-КТ"
 */

// Функция расчета CRC16 из m90-device.js
function calcCRC16(dataStr) {
    if (!dataStr || dataStr.length === 0) {
        return 0xFFFF;
    }
    
    let crc = 0xFFFF;
    for (let i = 0; i < dataStr.length; i++) {
        let byte = dataStr.charCodeAt(i);
        crc ^= byte;
        for (let j = 0; j < 8; j++) {
            if ((crc & 0x0001) === 1) {
                crc = (crc >> 1) ^ 0xA001;
            } else {
                crc = crc >> 1;
            }
        }
    }
    return crc & 0xFFFF;
}

// Функция форматирования команды
function formatCommand(deviceAddress, command, operands = []) {
    let commandStr = `${deviceAddress};${command}`;
    
    if (operands && operands.length > 0) {
        for (const operand of operands) {
            commandStr += `;${operand}`;
        }
    }
    
    commandStr += ';';
    
    const crc = calcCRC16(commandStr);
    
    return `:${commandStr}${crc}\r`;
}

console.log('=== Тесты протокола ASCII UAIL ===\n');

// Тест 1: Команда 0 - Чтение типа прибора (раздел 5.2)
console.log('Тест 1: Команда 0 - Чтение типа прибора');
const cmd0 = formatCommand(2, 0, []);
console.log(`Запрос: ${cmd0.replace(/\r/g, '\\r')}`);
console.log(`Ожидаемый формат: :2;0;<CRC>\\r`);
console.log(`Данные для CRC: "2;0;"`);
console.log(`CRC: ${calcCRC16('2;0;')}`);
console.log();

// Тест 2: Ответ на команду 0 (раздел 7.1)
console.log('Тест 2: Ответ на команду 0');
const answerData = '2;64;';
const answerCRC = calcCRC16(answerData);
console.log(`Данные ответа: "${answerData}"`);
console.log(`CRC: ${answerCRC}`);
console.log(`Полный ответ: !2;64;${answerCRC}\\r`);
console.log();

// Тест 3: Команда 40 - Открытие RAM (раздел 5.5)
console.log('Тест 3: Команда 40 - Открытие RAM (тип памяти 1)');
const cmd40 = formatCommand(2, 40, [1]);
console.log(`Запрос: ${cmd40.replace(/\r/g, '\\r')}`);
console.log(`Ожидаемый формат: :2;40;1;<CRC>\\r`);
console.log(`Данные для CRC: "2;40;1;"`);
console.log(`CRC: ${calcCRC16('2;40;1;')}`);
console.log();

// Тест 4: Команда 41 - Переход к адресу 0 (раздел 5.6)
console.log('Тест 4: Команда 41 - Переход к адресу 0');
const cmd41 = formatCommand(2, 41, [0, 0]);
console.log(`Запрос: ${cmd41.replace(/\r/g, '\\r')}`);
console.log(`Ожидаемый формат: :2;41;0;0;<CRC>\\r`);
console.log(`Данные для CRC: "2;41;0;0;"`);
console.log(`CRC: ${calcCRC16('2;41;0;0;')}`);
console.log();

// Тест 5: Команда 42 - Чтение 36 байт (раздел 5.7)
console.log('Тест 5: Команда 42 - Чтение 36 байт');
const cmd42 = formatCommand(2, 42, [36]);
console.log(`Запрос: ${cmd42.replace(/\r/g, '\\r')}`);
console.log(`Ожидаемый формат: :2;42;36;<CRC>\\r`);
console.log(`Данные для CRC: "2;42;36;"`);
console.log(`CRC: ${calcCRC16('2;42;36;')}`);
console.log();

// Тест 6: Команда 44 - Актуализация данных (раздел 5.9)
console.log('Тест 6: Команда 44 - Актуализация данных');
const cmd44 = formatCommand(2, 44, [0]);
console.log(`Запрос: ${cmd44.replace(/\r/g, '\\r')}`);
console.log(`Ожидаемый формат: :2;44;0;<CRC>\\r`);
console.log(`Данные для CRC: "2;44;0;"`);
console.log(`CRC: ${calcCRC16('2;44;0;')}`);
console.log();

// Тест 7: Проверка CRC8 для структур (раздел 6.5)
console.log('Тест 7: CRC8 для структур данных');
function calcCRC8(byteArray) {
    let crc = 0x00;
    for (let i = 0; i < byteArray.length; i++) {
        crc = (crc + byteArray[i]) & 0xFF;
    }
    return (~crc) & 0xFF;
}

// Пример структуры параметров регулятора (13 байт)
// Байты 0-3: уставка (Float), 4-7: плато (Float), 8-11: скорость (Float), 12: CRC
const testStruct = [0x00, 0x00, 0xC8, 0x42,  // Уставка 100.0 (Float)
                    0x00, 0x00, 0x00, 0x00,  // Плато 0.0
                    0x00, 0x00, 0x00, 0x00]; // Скорость 0.0
const crc8 = calcCRC8(testStruct);
testStruct.push(crc8);
console.log(`Структура параметров (12 байт): ${testStruct.slice(0, 12).map(b => b.toString(16).padStart(2, '0').toUpperCase()).join('')}`);
console.log(`CRC8: ${crc8} (0x${crc8.toString(16).toUpperCase()})`);
console.log(`Полная структура (13 байт): ${testStruct.map(b => b.toString(16).padStart(2, '0').toUpperCase()).join('')}`);
console.log();

// Тест 8: Проверка алгоритма CRC16 с примером из документации
console.log('Тест 8: Проверка CRC16 с известными данными');
// Проверяем что CRC16 совпадает с алгоритмом из документации
const testData = '2;0;';
const crc = calcCRC16(testData);
console.log(`Данные: "${testData}"`);
console.log(`CRC16: ${crc}`);
console.log(`Полином: 0xA001 (${0xA001}), Инициализация: 0xFFFF (${0xFFFF})`);
console.log();

console.log('=== Все тесты завершены ===');
