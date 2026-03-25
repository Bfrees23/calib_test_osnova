unit uCorrectorThread;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, System.SyncObjs, System.Types, System.Math,
  System.IniFiles, System.IOUtils, System.DateUtils,
  WinApi.Windows,
  Vcl.Graphics, Vcl.Buttons, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Forms,
  CPDrv, ComponentUSB, MemTableEh,
  LKGUtils,
  uDefinitions, uAppUtils, uDeviceThread;

type
  TCommandFunction = (cfRead03 = $03, cfRead04 = $04, cfWrite10 = $10, cfRead11 = $11, cfReadWrite17 = $17);

  TLocksStates = record
    Data            : Byte;
    Calib           : Boolean;
    ProviderOPT     : Boolean;
    FactoryOPT      : Boolean;
    ProviderRS485   : Boolean;
    FactoryRS485    : Boolean;
  end;

  TLKGParams = record
    MoveIndex       : Byte;
    LKGString       : ShortString;
    LKGBytes        : TBytes;
    DT              : Integer;
    SN              : UInt64;
    OCTLKG          : Integer;
    CryptLKG        : Integer;
    CryptLKGBytes   : TBytes;
  end;

  PEPassport = ^TEPassport;
  TEPassport = packed record
    Name            : array[0..19] of AnsiChar;
    Version         : array[0..11] of AnsiChar;
    SerialNumber    : array[0..19] of AnsiChar;
    MapVersion      : Word;
    CRC             : Word;
  end;

  TCommandParams = record
  public
    Define          : string;
    Name            : string;
    DataType        : string;
    FloatFormat     : string;
    FirstReg        : Word;
    RegAmount       : Word;
    ReadFunc        : Byte;
    WriteFunc       : Byte;

  private
    procedure MakeCommandParams(aDefine, aName, aDataType: string;
      aFirstReg: Word = 0;
      aRegAmount: Word = 0;
      aFloatFormat: string = string.Empty;
      aReadFunc: Byte = 0;
      aWriteFunc: Byte = 0);
  end;

  TCorrectorProcedure = (cpCheckConnection, cpObtainData, cpIdle);

  TCorrectorThread = class(TDeviceThread)
  private
    FIndex                        : Byte;
    FComponentUSB                 : TComponentUSB;
    FAnswer                       : TBytes;
    FEPassPort                    : TEPassport;
    FPEPassport                   : PEPassport;

    FCommandParams                : TCommandParams;
    FCurrentCommand               : TBytes;
    FCurrentCommandFunction       : Byte;
    FLKGParams                    : TLKGParams;

    FSendingAttempt               : Byte;
    FBigCycleAttempt              : Byte;
    FCorrectorProcedure           : TCorrectorProcedure;

    FcbbBaudRate                  : TComboBox;
    FcbbByteSize                  : TComboBox;
    FcbbParity                    : TComboBox;
    FcbbStopBits                  : TComboBox;

    FRegistersMap                 : TIniFile;

    procedure SetComponents; override;
    procedure UpdateComPort;

    function Communicate: Boolean; override;

    procedure ParseAnswer;

    procedure SwitchProcedureTo(aCorrectorProcedure: TCorrectorProcedure);
    procedure SetInitialValues; override;

    procedure OnComboboxClick(Sender: TObject); override;

    function CheckConnectionPipeline: Boolean;

    function AreAttemptsEnded: Boolean;

    procedure BuildCommand(CommandFunction: TCommandFunction; FirstRegister: Word = 0;
      RegistersAmount: Word = 0; Data: TBytes = []; OptionalWriteRegister: Word = 0; OptionalWriteRegisterAmount: Word = 0);
    procedure InitializeLKG;

    function CheckMapFile(MapVersion: Word): Boolean;
    function GetCommandParamsByDefine(Define: string): Boolean;
    function ExtractDateTime(Data: PByte): TDateTime;
    function ConvertAnswerData: string;
    function SendLKG: Boolean;
    function ObtainDataPipeline: Boolean;

    procedure ClearAnswer;
    procedure ClearCurrentCommand;
    procedure HandleError;
    procedure SelectMenu(MenuNumber: Word; MenuName: string);
    procedure FreeComponents;

    procedure DisplayNothingSync; override;
  public
    constructor Create(Index: Byte);

    procedure StartObtainingData; override;
    procedure StopObtainingData; override;
  end;

var
  CorrectorAddress: Byte = $01;

  ErrorMessagesArray: array[1..12] of string = ('Принятый код функции не может быть обработан',
                                                'Адрес данных, указанный в запросе, недоступен',
                                                'Значение, содержащееся в поле данных запроса, является недопустимой величиной',
                                                'Не удалось записать, ошибка EEPROM',
                                                'Доступ закрыт, замок закрыт',
                                                'Регистр только для записи',
                                                'Регистр только для чтения',
                                                'Ошибка CRC архивной записи',
                                                'Запрошенная архивная запись отсутствует',
                                                'Ошибка чтения данных с Flash',
                                                'Ошибка записи. Недопустимое значение ЛКГ',
                                                'Ошибка опроса датчика');

implementation

uses
  uSettings, uMain, uData, uMITThread, uCalibratorThread;

{ TCommandParams }

procedure TCommandParams.MakeCommandParams(aDefine, aName,
  aDataType: string; aFirstReg, aRegAmount: Word; aFloatFormat: string;
  aReadFunc, aWriteFunc: Byte);
begin
  Define := aDefine;
  Name := aName;
  DataType := aDataType;
  FloatFormat := aFloatFormat;
  FirstReg := aFirstReg;
  RegAmount := aRegAmount;
  ReadFunc := aReadFunc;
  WriteFunc := aWriteFunc;
end;

{ uCalibratorThread }

constructor TCorrectorThread.Create(Index: Byte);
begin
  FIndex := Index;
  inherited Create;
end;

procedure TCorrectorThread.DisplayNothingSync;
begin
  inherited;
end;

procedure TCorrectorThread.BuildCommand(CommandFunction: TCommandFunction; FirstRegister, RegistersAmount: Word;
Data: TBytes; OptionalWriteRegister, OptionalWriteRegisterAmount: Word);

  procedure AddCRCTo(var Command: TBytes); inline;
  begin
    Command := Command + WordToBytesArray(CalcCRC16(@Command[0], Length(Command)), True);
  end;

begin
  FCurrentCommand := [CorrectorAddress] + [Ord(CommandFunction)];
  FCurrentCommand := FCurrentCommand + WordToBytesArray(FirstRegister) + WordToBytesArray(RegistersAmount);

  case CommandFunction of
    cfWrite10: FCurrentCommand := FCurrentCommand + [RegistersAmount * 2] + Data;
    cfRead11: FCurrentCommand := [CorrectorAddress] + [Ord(CommandFunction)];
    cfReadWrite17:
      begin
        FCurrentCommand := FCurrentCommand + WordToBytesArray(OptionalWriteRegister) + WordToBytesArray(OptionalWriteRegisterAmount);
        FCurrentCommand := FCurrentCommand + [OptionalWriteRegisterAmount * 2] + Data;
      end;
  end;
  AddCRCTo(FCurrentCommand);
end;

function TCorrectorThread.GetCommandParamsByDefine(Define: string): Boolean;
var
  MaxItemsAmount, i, j: Byte;
  PartitionName, CommandRegister, TempRegister: string;
  SectionList: TStringList;

  procedure ClearCommandParams;
  begin
    FCommandParams.Define := EmptyStr;
    FCommandParams.Name := EmptyStr;
    FCommandParams.DataType := EmptyStr;
    FCommandParams.FloatFormat := EmptyStr;
    FCommandParams.FirstReg := 0;
    FCommandParams.RegAmount := 0;
    FCommandParams.ReadFunc := 0;
    FCommandParams.WriteFunc := 0;
  end;

begin
  ClearCommandParams;
  if not Assigned(FRegistersMap) or (FEPassPort.MapVersion = 0) then
    Exit;

  try
    SectionList := TStringList.Create;

    FRegistersMap.ReadSection('Partiton', SectionList);
    MaxItemsAmount := CutStringOut(SectionList.Strings[SectionList.Count - 1], 'Item').ToInteger;
    CommandRegister := FRegistersMap.ReadString('Defines', Define, string.Empty);
    SectionList.Clear;

    for i := 0 to MaxItemsAmount do
    begin
      j := 0;
      PartitionName := Format('Partiton%dParam%d', [i, j]);

      while FRegistersMap.SectionExists(PartitionName) do
      begin
        TempRegister := FRegistersMap.ReadString(PartitionName, 'Register', string.Empty);
        if TempRegister = CommandRegister then
        begin
          FRegistersMap.ReadSectionValues(PartitionName, SectionList);
          FCommandParams.FirstReg := ('$' + CutStringOut(CommandRegister, '0x')).ToInteger;
          Break;
        end;
        Inc(j);
        PartitionName := Format('Partiton%dParam%d', [i, j]);
      end;

      if TempRegister = CommandRegister then
        Break;
    end;

    FCommandParams.Define := Define;
    Result := SectionList.Count > 0;
    if Result then
      with FCommandParams do
      begin
        for i := 0 to SectionList.Count - 1 do
          if ContainsText(SectionList.Strings[i], 'Name') then
            Name := CutStringOut(SectionList.Strings[i], '=')
          else
          if ContainsText(SectionList.Strings[i], 'TypeData') then
            DataType := CutStringOut(SectionList.Strings[i], '=')
          else
          if ContainsText(SectionList.Strings[i], 'CountReg') then
            RegAmount := CutStringOut(SectionList.Strings[i], '=').ToInteger
          else
          if ContainsText(SectionList.Strings[i], 'ReadFunc') then
            ReadFunc := ('$' + CutStringOut(SectionList.Strings[i], '0x')).ToInteger
          else
          if ContainsText(SectionList.Strings[i], 'WriteFunc') then
            WriteFunc := ('$' + CutStringOut(SectionList.Strings[i], '0x')).ToInteger;
      end
    else
      HandleError;

  finally
    SectionList.Free;
  end;
end;

procedure TCorrectorThread.HandleError;
begin
  case FCorrectorProcedure of
    cpCheckConnection: BuildCommand(cfRead11);
    cpIdle: ClearCurrentCommand;
  end;
end;

procedure TCorrectorThread.SetComponents;
begin
  FTimeout := 2000;

  FGroupBox := fMain.FindComponent(Format('gbCorrector%d', [FIndex])) as TGroupBox;
  FStateLabel := fMain.FindComponent(Format('lCorrectorState%d', [FIndex])) as TLabel;
  FConnectionStateLabel := fMain.FindComponent(Format('lCorrectorConnectionState%d', [FIndex])) as TLabel;

  FButton := fMain.FindComponent(Format('bCheckConnectionCorrector%d', [FIndex])) as TButton;
  FButton.OnClick := OnButtonClick;

  FComPort := fSettings.FindComponent(Format('cpdCorrector%d', [FIndex])) as TCommPortDriver;

  FComboBox := fSettings.FindComponent(Format('cbbCorrector%dPorts', [FIndex])) as TComboBox;
  FComboBox.OnClick := OnComboboxClick;

  FcbbBaudRate := fSettings.cbbCorrectorsBaudRate;
  FcbbByteSize := fSettings.cbbCorrectorsByteSize;
  FcbbParity := fSettings.cbbCorrectorsParity;
  FcbbStopBits := fSettings.cbbCorrectorsStopBits;

  FComPort.EnumComPorts(FComboBox.Items);
  UpdateComPort;
end;

procedure TCorrectorThread.UpdateComPort;
begin
  if Assigned(FComboBox) then
  begin
    FComPort.Disconnect;
    FComboBox.ItemIndex := FComboBox.Items.IndexOf(ConfigParams.CorrectorPortNameArray[FIndex - 1]);
    if FComboBox.ItemIndex <> -1 then
    begin
      FComboBox.Text := ConfigParams.CorrectorPortNameArray[FIndex - 1];
      FComPort.PortName := ConfigParams.CorrectorPortNameArray[FIndex - 1];
      FComPort.BaudRateValue := ConfigParams.CorrectorSettings.BaudRate.ToInteger;
      FComPort.DataBits := TDataBits(FcbbByteSize.Items.IndexOf(ConfigParams.CorrectorSettings.ByteSize));
      FComPort.Parity := TParity(FcbbParity.Items.IndexOf(ConfigParams.CorrectorSettings.Parity));
      FComPort.StopBits := TStopBits(FcbbStopBits.Items.IndexOf(ConfigParams.CorrectorSettings.StopBits));
    end
    else
      FComPort.PortName := EmptyStr;
  end;
end;

procedure TCorrectorThread.SetInitialValues;
begin
  FDeviceName := Format('Корректор №%d', [FIndex]);
  FSerialNumber := EmptyStr;
  UpdateGroupBoxCaptionSynch(FDeviceName);
  ResetCommandAttemptCount;
end;

procedure TCorrectorThread.StartObtainingData;
begin
  inherited;
  SwitchProcedureTo(cpCheckConnection);
end;

procedure TCorrectorThread.StopObtainingData;
begin
  inherited;
end;

procedure TCorrectorThread.ClearCurrentCommand;
begin
  SetLength(FCurrentCommand, 0);
end;

procedure TCorrectorThread.ClearAnswer;
begin
  SetLength(FAnswer, 0);
end;

procedure TCorrectorThread.OnComboboxClick(Sender: TObject);
begin
  ConfigParams.CorrectorPortNameArray[FIndex - 1] := FComboBox.Text;
  inherited;
end;

procedure TCorrectorThread.FreeComponents;
begin
  inherited;
  FreeAndNil(FRegistersMap);
end;

function TCorrectorThread.Communicate: Boolean;
var
  Color: TColor;
  StartTime: Cardinal;
begin
  ClearAnswer;
  Result := FComPort.SendData(@FCurrentCommand[0], Length(FCurrentCommand)) = Length(FCurrentCommand);
  Inc(FSendingAttempt);

  if Result then
    Color := clMaroon
  else
    Color := clRed;

  FCurrentCommandFunction := FCurrentCommand[1];
  SendToRichEditSync(Format('[%s] --> %s', [FDeviceName, FCommandParams.Name]), Color);
  SendToLogSync(Format('[%s] --> %s (%s)', [FDeviceName, FCommandParams.Name, BytesToHexString(FCurrentCommand)]));

  if Result then
  begin
    StartTime := GetTickCount;
    while FComPort.Connected and ((GetTickCount - StartTime) < FTimeout) do
    begin
      while FComPort.CountRX > 0 do
      begin
        SetLength(FAnswer, Length(FAnswer) + FComPort.CountRX);
        FComPort.ReadData(@FAnswer[Length(FAnswer) - FComPort.CountRX], FComPort.CountRX);
      end;

      Yield;

      if CheckCRC16(FAnswer) then
      begin
        ParseAnswer;
        ResetCommandAttemptCount;
        Exit;
      end;
    end;
  end;

  if AreAttemptsEnded then
    HandleCheckConnectionFailed;
end;

function TCorrectorThread.CheckMapFile(MapVersion: Word): Boolean;
begin
  var MapPath: string := Format('%sRegisterMapFile_v%d.ini', [ConfigParams.CorrectorMapsPath, MapVersion]);
  Result := FileExists(MapPath);

  if not Result then
  begin
    Synchronize(procedure
    begin
      SendToBothLogsSync(Format('Не удаётся найти RegisterMapFile_v%d.ini', [MapVersion]));
    end);
    Exit;
  end;

  FRegistersMap := TIniFile.Create(MapPath);
  var MapVersionINI: Word := FRegistersMap.ReadInteger('Partiton', 'MapVersion', 0);

  if MapVersionINI <> MapVersion then
    ShowMessageFmt('В файле RegisterMapFile_v%d.ini версия не соответствует версии в названии файла (%d). Возможно некорректный вывод информации',
      [MapVersion, MapVersionINI]);
end;

function TCorrectorThread.AreAttemptsEnded: Boolean;
begin
  Result := FSendingAttempt > 2;
end;

procedure TCorrectorThread.ParseAnswer;
var
  AnswerForLog: string;
begin
  if Length(FAnswer) < 4 then
      Exit;

  if (Length(FAnswer) > 2) and (FCurrentCommandFunction or $80 = FAnswer[1]) then
    SendToBothLogsSync(ErrorMessagesArray[FAnswer[2]]);

  AnswerForLog := ConvertAnswerData;

  SendToRichEditSync(Format('[%s] <-- %s: %s', [FDeviceName, FCommandParams.Name, AnswerForLog]), clGreen);
  SendToLogSync(Format('[%s] <-- %s: %s (%s)'#9'CRC OK', [FDeviceName, FCommandParams.Name, AnswerForLog, BytesToHexString(FAnswer)]));

  var IsSucceeded: Boolean;
  case FCorrectorProcedure of
    cpCheckConnection:
      IsSucceeded := CheckConnectionPipeline;
    cpObtainData:
      IsSucceeded := ObtainDataPipeline;
  end;
end;

function TCorrectorThread.CheckConnectionPipeline: Boolean;

  procedure ParseElevenCommandAnswer;
  begin
    FPEPassport := @FAnswer[3];
    FEPassPort := FPEPassport^;

    if not CheckMapFile(FPEPassport^.MapVersion) then
      Exit;

    FDeviceName := Format('%s №%s', [FEPassPort.Name, FEPassPort.SerialNumber]);
    UpdateGroupBoxCaptionSynch(Format('%s (%s)', [FDeviceName, FEPassPort.Version]));
  end;

begin
  if FCurrentCommandFunction = $11 then
  begin
    ParseElevenCommandAnswer;
    Result := GetCommandParamsByDefine('REG_DATETIME');
    if Result then
      BuildCommand(TCommandFunction(FCommandParams.ReadFunc), FCommandParams.FirstReg, FCommandParams.RegAmount);
  end
  else
  if FCommandParams.Define = 'REG_DATETIME' then
  begin
    FLKGParams.DT := StrToInt(AnsiString(FormatDateTime('ddmmyyyy', (ExtractDateTime(@FAnswer[3])))));
    FLKGParams.MoveIndex := FormatDateTime('mm', (ExtractDateTime(@FAnswer[3]))).ToInteger;
    Result := GetCommandParamsByDefine('REG_SERIAL');
    if Result then
      BuildCommand(TCommandFunction(FCommandParams.ReadFunc), FCommandParams.FirstReg, FCommandParams.RegAmount);
  end
  else
  if FCommandParams.Define = 'REG_SERIAL' then
  begin
    FLKGParams.SN := ('$' + RightStr(PInt64(@FAnswer[3])^.ToHexString, 8)).ToInteger;
    InitializeLKG;
    Result := GetCommandParamsByDefine('REG_INIT_LKG');
    if Result then
      BuildCommand(TCommandFunction(FCommandParams.WriteFunc), FCommandParams.FirstReg, FCommandParams.RegAmount, FLKGParams.LKGBytes + FLKGParams.CryptLKGBytes);
  end
  else
  if FCommandParams.Define = 'REG_INIT_LKG' then
  begin
    SendToBothLogs(Format('[%s] <-- Инициализация ЛКГ прошла успешно', [FDeviceName]), ClGreen);
    SwitchProcedureTo(cpObtainData);
    Result := True;
    FButton.Enabled := True;
  end;
end;

function TCorrectorThread.ObtainDataPipeline: Boolean;
begin
  with FCommandParams do
    if Define = 'REG_LKG' then
      SelectMenu(302, 'Версия прошивки')
    else
    if (Define = 'REG_SEL_MENU') and ContainsText(Name, '"Версия прошивки"') then
      SelectMenu(303, 'Что-то ещё')
    else
    if (Define = 'REG_SEL_MENU') and ContainsText(Name, '"Что-то ещё"') then
      SwitchProcedureTo(cpIdle);
end;

procedure TCorrectorThread.SelectMenu(MenuNumber: Word; MenuName: string);
begin
  with FCommandParams do
  begin
    MakeCommandParams('REG_SEL_MENU', Format('Отображение меню "%s"', [MenuName]), string.Empty, $233, 1);
    BuildCommand(cfWrite10, FirstReg, RegAmount, FormDataToBytes(@MenuNumber, SizeOf(Word)));
  end;
end;

procedure TCorrectorThread.SwitchProcedureTo(aCorrectorProcedure: TCorrectorProcedure);
begin
  ResetCommandAttemptCount;
  ClearCurrentCommand;
  FCorrectorProcedure := aCorrectorProcedure;
  with dmData do
    case FCorrectorProcedure of
      cpCheckConnection:
        begin
          FCommandParams.Name := 'Электронный паспорт устройства';
          BuildCommand(cfRead11);
        end;
      cpObtainData:
        begin
          SendLKG;
        end;
      cpIdle: FStartEvent.ResetEvent;
    end;
end;

procedure TCorrectorThread.InitializeLKG;

  function ShiftLKG(LKG: string; Index: Byte): Integer;
  var
    TempString: string;
  begin
    TempString := RightStr(LKG, LKG.Length - Index + 1) + LeftStr(LKG, Index - 1);
    TempString := LeftStr(TempString, 8);
    Result := ('$' + TempString).ToInteger;
  end;

begin
  with FLKGParams do
  begin
    if not TryGetDongleLKGSerial(LKGString, LKGBytes) then
      Exit;

    OCTLKG := ShiftLKG(LKGString, MoveIndex);
    CryptLKG := SN xor DT xor OCTLKG;
    CryptLKGBytes := FormDataToBytes(@CryptLKG, SizeOf(Integer));
  end;
end;

function TCorrectorThread.SendLKG: Boolean;
begin
  with FCommandParams do
  try
    Result := GetCommandParamsByDefine('REG_LKG');
    if Result then
      BuildCommand(TCommandFunction(WriteFunc), FirstReg, RegAmount, FLKGParams.CryptLKGBytes);
  except
    on E: Exception do
      SendToBothLogsSync('Неудачная отправка ЛКГ', clRed);
  end;
end;

function TCorrectorThread.ExtractDateTime(Data: PByte): TDateTime;
begin
  Result := UnixToDateTime((PInt64(Data))^);
end;

function TCorrectorThread.ConvertAnswerData: string;
begin
  if Length(FAnswer) < 4 then
    Exit;

  if FCurrentCommandFunction = $10 then
    Result := 'OK'
  else
  if FCommandParams.DataType = EmptyStr then
    Result := EmptyStr
  else
  if FCommandParams.DataType = 'Char' then
    Result := AnsiString(PAnsiChar(@FAnswer[3]))
  else
  if FCommandParams.DataType = 'Uint64' then
    Result := PUint64(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Uint32' then
    Result := PCardinal(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Uint16' then
    Result := PWord(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Int16' then
    Result := PSmallint(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Uint8' then
    Result := PByte(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Double' then
    Result := FormatFloat(FCommandParams.FloatFormat, PDouble(@FAnswer[3])^)
  else
  if FCommandParams.DataType = 'Float' then
    Result := FormatFloat(FCommandParams.FloatFormat, PSingle(@FAnswer[3])^)
  else
  if FCommandParams.DataType = 'TDate' then
    Result := PDate(@FAnswer[3])^.ToString
  else
  if FCommandParams.DataType = 'Time64_t' then
    Result := ExtractDateTime(@FAnswer[3]).ToString
end;


end.
