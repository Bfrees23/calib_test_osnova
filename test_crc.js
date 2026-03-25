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

// Тестируем команду ':' (проверка типа)
const cmdWithoutColon = '';
const crc = calcCRC16(cmdWithoutColon);
console.log('Команда ":" без двоеточия = пустая строка');
console.log('CRC для пустой строки:', crc);
console.log('Формат команды: :' + cmdWithoutColon + crc + '\\r');

// Тестируем команду '!' (серийный номер)
const cmd2 = '!';
const crc2 = calcCRC16(cmd2);
console.log('\nКоманда "!":');
console.log('CRC:', crc2);
console.log('Формат команды: :' + cmd2 + crc2 + '\\r');

// Тестируем команду 'T' (температура)
const cmd3 = 'T';
const crc3 = calcCRC16(cmd3);
console.log('\nКоманда "T":');
console.log('CRC:', crc3);
console.log('Формат команды: :' + cmd3 + crc3 + '\\r');

// Тестируем команду '!F' (открыть FLASH)
const cmd4 = '!F';
const crc4 = calcCRC16(cmd4);
console.log('\nКоманда "!F":');
console.log('CRC:', crc4);
console.log('Формат команды: :' + cmd4 + crc4 + '\\r');

// Тестируем ответ "!64;56789\r" (пример ответа на проверку типа)
const answerData = '64;';
const answerCRC = calcCRC16(answerData);
console.log('\nОтвет "!64;' + answerCRC + '\\r":');
console.log('Данные для CRC: "' + answerData + '"');
console.log('CRC:', answerCRC);
console.log('Полный ответ: !64;' + answerCRC + '\\r');
