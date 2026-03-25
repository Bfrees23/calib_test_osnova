unit uCalibratorThread;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, System.SyncObjs, System.Types, System.Math,
  System.Variants,
  WinApi.Windows,
  Vcl.Graphics, Vcl.Buttons, Vcl.StdCtrls, Vcl.ExtCtrls,
  CPDrv, ComponentUSB, MemTableEh, Data.DB,
  uDefinitions, uDeviceThread;

type
  TCalibratorState = (csTypeConfirmed, csSerialNumberConfirmed, csFileOpened, csAdjusted, csCRCError, csFailed);
  TCalibratorStates = set of TCalibratorState;

  TAdjusterState = (asUnknown, asOn, asOff);
  TAdjusterStates = set of TAdjusterState;

  TCommand = record
    Itself        : AnsiString;
    Name          : AnsiString;
    Value         : AnsiString;
    Answer        : AnsiString;
    Timeout       : Cardinal;
    IsSucceded    : Boolean;

    private procedure Clear;
  end;

  PAdjuster = ^TAdjuster;
  TAdjuster = packed record
    StatusBit                     : Byte;
    MainBlockSetPoint             : Single;
    MainBlock                     : Single;
    TopSecureZone                 : Single;
    BottomSecureZone              : Single;
    MainBlockPowerValue           : SmallInt;
    TopPower                      : SmallInt;
    BottomPower                   : SmallInt;
    DeviceTemperature             : SmallInt;
    CompensatorTemperature        : SmallInt;
    VoltageSupply                 : SmallInt;
    StabilisationSeconds          : Byte;
    StabilisationMinutes          : Byte;
    StabilisationHours            : Byte;
    ErrorCode                     : Word;
    BlockingParameters            : Word;
  end;

  PRegulatorParameters = ^TRegulatorParameters;
  TRegulatorParameters = packed record
    SetPoint                      : Single;
    Plateau                       : Single;
    Speed                         : Single;
    CRC                           : Byte;
  end;

  TCalibratorThread = class(TDeviceThread)
  private
    FIndex                        : Byte;
    FValidVerification            : Boolean;
    FIsVerificDateChecked         : Boolean;
    FComponentUSB                 : TComponentUSB;
    FCommand                      : TCommand;
    FAnswer                       : AnsiString;

    FCommands                     : TMemTableEh;
    FTemperature                  : TTemperatures;
    FDeviceProcedure              : TDeviceProcedure;
    FCalibratorStates             : TCalibratorStates;
    FAdjusterState                : TAdjusterState;
    FTimeAdjusted                 : string;

    FTemperatureCelsiusPanel      : TPanel;
    FTemperatureKelvinPanel       : TPanel;
    FAccuracyPanel                : TPanel;

    FSetPoint                     : Extended;
    FMIT_M90Accuracy              : Extended;
    FIsReadyToBeginToCalibrate    : Boolean;

    File76ByteArray               : array[0..22] of Byte;
    RegulatorParametersByteArray  : array[0..12] of Byte;
    FRegulatorParametersPointer   : PRegulatorParameters;
    FAdjusterPointer: PAdjuster;
    FDeviceName: string;

    procedure UpdateComPort; override;
    procedure SetComponents; override;

    function Communicate: Boolean; override;

    function CalcCRC16(Data: AnsiString): Word;
    function CalcCRC8(P: PByte; Size: Cardinal): Byte;

    procedure ParseAnswer;
    procedure DisplayTemperatureSync;
    procedure DisplayNothingSync; override;
    procedure DisplayAccuracy;
    procedure UpdateCalibratorStateLabelSync;

    procedure SwitchProcedureTo(aDeviceProcedure: TDeviceProcedure);
    procedure MarkCommandSucceeded(IsSucceeded: Boolean);
    procedure NextCommand;
    procedure PrepareCommand;
    procedure SetInitialValues; override;

    procedure OnComboboxClick(Sender: TObject); override;

    function CheckConnectionPipeline: Boolean;
    function ObtainDataPipeline: Boolean;
    function CalibrationPipeline: Boolean;

    function AreAttemptsEnded: Boolean;
    function IsCalibratorAdjusted: Boolean;
    function IsFileOpened: Boolean;
    function IsMitTemperatureNull: Boolean;
    function IsTypeConfirmed: Boolean;

    function ConfirmType: Boolean;
    function HandleSerialNumber: Boolean;
    function HandleFileMessage: Boolean;
    function Read76File: Boolean;
    function Read0File: Boolean;
    function ReadCurrentTemperature: Boolean;
    function PrepareToWrite76File: Boolean;
    function Read63File: Boolean;
    function PrepareToWrite63File: Boolean;
    function CheckCRCInAnswer(Answer: AnsiString;
      out TempStringArray: TArray<string>): Boolean;

    procedure ClearAnswer;
    procedure FreeComponents;
  public
    constructor Create(Index: Byte);

    procedure OnChangeCalibrationTemperature(Temperature: Extended);
    procedure OnTurnOffAdjuster;

    procedure StartObtainingData; override;
    procedure StopObtainingData; override;

    property DeviceName: string read FDeviceName;
    property SerialNumber: string read FSerialNumber;
    property IsReadyToBeginToCalibrate: Boolean read FIsReadyToBeginToCalibrate;
  end;

implementation

uses
  uSettings, uMain, uData, uMITThread;

{ TCommand }

procedure TCommand.Clear;
begin
  Itself := string.Empty;
  Name := string.Empty;
  Value := string.Empty;
  Answer := string.Empty;
  Timeout := 0;
  IsSucceded := False;
end;


{ uCalibratorThread }

constructor TCalibratorThread.Create(Index: Byte);
begin
  FIndex := Index;
  inherited Create;
end;

procedure TCalibratorThread.OnChangeCalibrationTemperature(Temperature: Extended);
begin
  SwitchProcedureTo(dpPrepareToCalibration);
  FSetPoint := Temperature;
  SendToBothLogsSync(Format('У %s будет установлена температура %s', [FDeviceName, FSetPoint.ToString]));
end;

procedure TCalibratorThread.OnTurnOffAdjuster;
begin
//  SwitchProcedureTo(dpPrepareToCalibration);
//  FSetPoint := Temperature;
//  SendToBothLogsSync(Format('У %s будет установлена температура %s', [FDeviceName, FSetPoint.ToString]));
end;

function TCalibratorThread.CalcCRC8(P: PByte; Size: Cardinal): Byte;
var
  CRC: Cardinal;
begin
  CRC := $00;
  while Size > 0 do
  begin
    CRC := CRC + P^;
    Inc(P);
    Dec(Size);
  end;
  Result := Byte(not CRC);
end;

function TCalibratorThread.CalcCRC16(Data: AnsiString): Word;
var
  BitIndex: Byte;
  DataChar: AnsiChar;
begin
  if Data = string.Empty then
    Exit;

  Result := $FFFF;
  for DataChar in Data do
  begin
    Result := Ord(DataChar) xor Result;
    for BitIndex := 0 to 7 do
      if (Result and 1) = 1 then
      begin
        Result := Result shr 1;
        Result := Result xor 40961;
      end
      else
        Result := Result shr 1;
  end;
end;

procedure TCalibratorThread.SetComponents;
begin
  fMain.ChangeCalibrationTemperatureEventArray[FIndex] := OnChangeCalibrationTemperature;

  FTimeout := 2000;
  FCommands := TMemTableEh.Create(fMain);

  FGroupBox := TGroupBox(fMain.FindComponent(Format('gbCalibrator%d', [FIndex])));
  FStateLabel := TLabel(fMain.FindComponent(Format('lCalibratorState%d', [FIndex])));
  FConnectionStateLabel := TLabel(fMain.FindComponent(Format('lCalibratorConnectionState%d', [FIndex])));
  FTemperatureCelsiusPanel := TPanel(fMain.FindComponent(Format('pM90TemperatureCelcius%d', [FIndex])));
  FTemperatureKelvinPanel := TPanel(fMain.FindComponent(Format('pM90TemperatureKelvin%d', [FIndex])));
  FAccuracyPanel := TPanel(fMain.FindComponent(Format('pM90Accuracy%d', [FIndex])));

  FButton := TButton(fMain.FindComponent(Format('bConnectCalibrator%d', [FIndex])));
  FButton.Caption := 'Переподключиться';
  FButton.OnClick := OnButtonClick;

  FBitButton := TBitBtn(fSettings.FindComponent(Format('bbCheckConnectionCalibrator%d', [FIndex])));
  FBitButton.OnClick := OnBitButtonClick;

  FComPort := TCommPortDriver(fSettings.FindComponent(Format('cpdCalibrator%d', [FIndex])));;

  FComboBox := TComboBox(fSettings.FindComponent(Format('cbbCalibrator%dPorts', [FIndex])));;
  FComboBox.OnClick := OnComboboxClick;

  FComPort.EnumComPorts(FComboBox.Items);
  UpdateComPort;
  FBitButton.Enabled := FComboBox.Text <> string.Empty;
end;

procedure TCalibratorThread.UpdateComPort;
begin
  if Assigned(FComboBox) then
  begin
    FComPort.Disconnect;
    FComboBox.ItemIndex := FComboBox.Items.IndexOf(ConfigParams.CalibratorPortNameArray[FIndex - 1]);
    if FComboBox.ItemIndex <> -1 then
    begin
      FComboBox.Text := ConfigParams.CalibratorPortNameArray[FIndex - 1];
      FComPort.PortName := ConfigParams.CalibratorPortNameArray[FIndex - 1];
    end
    else
      FComPort.PortName := string.Empty;
  end;
end;

procedure TCalibratorThread.SetInitialValues;
begin
  FDeviceName := Format('М90 №%d', [FIndex]);
  FSerialNumber := string.Empty;
  FIsVerificDateChecked := False;
  UpdateGroupBoxCaptionSynch(FDeviceName);
end;

procedure TCalibratorThread.StartObtainingData;
begin
  inherited;
  SwitchProcedureTo(dpCheckConnection);
end;

procedure TCalibratorThread.StopObtainingData;
begin
  inherited;
end;

procedure TCalibratorThread.OnComboboxClick(Sender: TObject);
begin
  ConfigParams.CalibratorPortNameArray[FIndex - 1] := FComboBox.Text;
  inherited;
end;

procedure TCalibratorThread.FreeComponents;
begin
  inherited;
  FreeAndNil(FCommands);
end;

function TCalibratorThread.Communicate: Boolean;
var
  Color: TColor;
  StartTime: Cardinal;
  StringArray: TArray<string>;
  LogMessage: string;
begin
  PrepareCommand;
  ClearAnswer;
  Result := False;

  if FCommand.Itself = string.Empty then
    Exit;

  Result := FComPort.SendData(@FCommand.Itself[1], Length(FCommand.Itself)) = Length(FCommand.Itself);

  if Result then
    Color := clMaroon
  else
    Color := clRed;

  if Result then
  begin
    StartTime := GetTickCount;

    LogMessage := Format('[%s] --> %s (%s)', [FDeviceName, LeftStr(FCommand.Itself, Length(FCommand.Itself) - 1), FCommand.Name]);
    SendToLogSync(LogMessage);

    {$IFDEF DEBUG}
      SendToRichEditSync(LogMessage, Color + clTeal);
    {$ENDIF}

    if FSendingAttempt > 1 then
      SendToBothLogsSync(Format('[%s] %d-я отправка команды "%s"', [FDeviceName, FSendingAttempt, FCommand.Name]));

    Inc(FSendingAttempt);

    while FComPort.Connected and ((GetTickCount - StartTime) <= FTimeout) do
    begin
      while FComPort.CountRX > 0 do
      begin
        SetLength(FAnswer, Length(FAnswer) + FComPort.CountRX);
        FComPort.ReadData(@FAnswer[Length(FAnswer) - FComPort.CountRX + 1], FComPort.CountRX);
      end;

      if (FAnswer <> string.Empty) and CheckCRCInAnswer(FAnswer, StringArray) then
      begin
        FCommand.Answer := StringArray[1];
        ParseAnswer;
        ResetCommandAttemptCount;
        Break;
      end;
    end;
  end
  else
    SendToBothLogsSync(Format('[%s] ОШИБКА отправки команды "%s"', [FDeviceName, FCommand.Name]), clRed);

  if AreAttemptsEnded then
    HandleCheckConnectionFailed;
//    if csCRCError in FCalibratorStates then
//      SendToBothLogsSync(Format('[%s] %s - Ошибка CRC', [FDeviceName, FAnswer]), clRed);
  if not IsSettingsOpened then
    Sleep(FCommand.Timeout);
  Yield;
end;

procedure TCalibratorThread.ClearAnswer;
begin
  SetLength(FAnswer, 0);
end;

procedure TCalibratorThread.PrepareCommand;
begin
  FCommand.Itself := FCommands.FieldByName('Command').AsString;

  if ContainsText(FCommand.Itself, 'var') and (FCommand.Value <> string.Empty) then
  begin
    FCommand.Itself := ReplaceText(FCommand.Itself, 'var', FCommand.Value);
    FCommand.Value := string.Empty;
  end;

  FCommand.Timeout := FCommands.FieldByName('Timeout').AsInteger;
  FCommand.IsSucceded := FCommands.FieldByName('Succeeded').AsBoolean;
  FCommand.Name := FCommands.FieldByName('CommandName').AsString;
  FCommand.Itself := Format('%s%d%s', [FCommand.Itself, CalcCRC16(CutStringOut(FCommand.Itself, ':')), Char(VK_RETURN)]);
end;

procedure TCalibratorThread.MarkCommandSucceeded(IsSucceeded: Boolean);
begin
  FCommands.Edit;
  FCommands.FieldByName('Succeeded').AsBoolean := IsSucceeded;
  FCommands.Post;
end;

procedure TCalibratorThread.NextCommand;
var
  IsLastCommand: Boolean;
begin
  IsLastCommand := FCommands.RecNo = FCommands.RecordCount;
  case FDeviceProcedure of
    dpCheckConnection:
      if not (csSerialNumberConfirmed in FCalibratorStates) then
      begin
        if FCommand.IsSucceded then
          FCommands.Next;
      end
      else
      begin
        SwitchProcedureTo(dpObtainData);
      end;
    dpObtainData:
      if IsLastCommand then
        FCommands.First
      else
        FCommands.Next;
    dpPrepareToCalibration:
      if IsLastCommand then
        begin
          SendToBothLogsSync(Format('Параметры калибровки %s успешно заданы', [FDeviceName]), clGreen);
          SwitchProcedureTo(dpObtainData);
        end
      else
        if FCommand.IsSucceded then
          FCommands.Next;
  end;
end;

function TCalibratorThread.CheckCRCInAnswer(Answer: AnsiString; out TempStringArray: TArray<string>): Boolean;
var
  AnswerNoCRC: AnsiString;
  i: Byte;
begin
  Result := False;
  TempStringArray := SplitString(RightStr(Answer, Length(Answer) - 2), ';');

  if Length(TempStringArray) < 2then
    Exit;

  AnswerNoCRC := string.Empty;
  for i := Low(TempStringArray) to High(TempStringArray) - 1 do
    AnswerNoCRC := AnswerNoCRC + TempStringArray[i] + ';';
  AnswerNoCRC := AnswerNoCRC + CalcCRC16(AnswerNoCRC).ToString;
  Result := AnswerNoCRC = Trim(RightStr(Answer, Length(Answer) - 2));
end;

procedure TCalibratorThread.ParseAnswer;
var
  LogMessage: string;
  IsSucceeded: Boolean;
begin
  if ContainsText(FAnswer, Char(VK_RETURN)) then
  begin
    LogMessage := Format('[%s] <-- %s (%s)', [FDeviceName, LeftStr(FAnswer, Length(FAnswer) - 1), FCommand.Name]);
    SendToLogSync(LogMessage);

    {$IFDEF DEBUG}
      SendToRichEditSync(LogMessage, clGreen + clTeal);
    {$ENDIF}

    FAnswer := CutStringOut(FAnswer, '!', Char(VK_RETURN));
    if not (csCRCError in FCalibratorStates) then
    begin
      case FDeviceProcedure of
        dpCheckConnection:
          IsSucceeded := CheckConnectionPipeline;
        dpObtainData:
          IsSucceeded := ObtainDataPipeline;
        dpPrepareToCalibration:
          IsSucceeded := CalibrationPipeline;
      end;

      if IsSucceeded then
      begin
        begin
          MarkCommandSucceeded(True);
          ResetCommandAttemptCount;
          NextCommand;
        end;
      end;

      UpdateConnectionStateLabelSync('Связь есть', clGreen);
    end
    else
    if AreAttemptsEnded then
      SendToBothLogsSync(Format('[%s] %s - Ошибка CRC', [FDeviceName, FAnswer]), clRed);
  end;
end;

function TCalibratorThread.HandleFileMessage: Boolean;
begin
  Exclude(FCalibratorStates, csFileOpened);
  Result := FCommand.Answer = '$0';
  if Result then
    Include(FCalibratorStates, csFileOpened)
  else
  if AreAttemptsEnded then
      SendToBothLogsSync(Format('[%s] %s ОШИБКА!', [FDeviceName, FCommand.Name]));
end;

function TCalibratorThread.AreAttemptsEnded: Boolean;
begin
  Result := FSendingAttempt > 2;
end;

function TCalibratorThread.IsFileOpened: Boolean;
begin
  Result := csFileOpened in FCalibratorStates;
end;

function TCalibratorThread.IsCalibratorAdjusted: Boolean;
begin
  Result := csAdjusted in FCalibratorStates;
end;

function TCalibratorThread.IsTypeConfirmed: Boolean;
begin
  Result := csTypeConfirmed in FCalibratorStates;
end;

function TCalibratorThread.ConfirmType: Boolean;
begin
  if FCommand.Answer = '64' then
  begin
    SendToBothLogsSync(Format('[%s] Тип прибора успешно подтверждён', [FDeviceName]), clGreen);
    Include(FCalibratorStates, csTypeConfirmed);
    Result := True;
  end
  else
  if AreAttemptsEnded then
    SendToBothLogsSync(Format('[%s] Тип прибора не подтверждён. Обратитесь к технологу', [FDeviceName]), clRed);
end;

function TCalibratorThread.Read63File: Boolean;
begin
  try
    Result := True;
    HexToBin(PWideChar(FCommand.Answer), RegulatorParametersByteArray[0], Length(FCommand.Answer) div 2);
    FRegulatorParametersPointer := @RegulatorParametersByteArray;
    PrepareToWrite63File;
  except
    Result := False;
  end;
end;

function TCalibratorThread.PrepareToWrite63File: Boolean;
var
  CRC: Byte;
begin
  try
    FRegulatorParametersPointer^.SetPoint := FSetPoint;
    FRegulatorParametersPointer^.Plateau := 0;
    FRegulatorParametersPointer^.Speed := 0;
    FRegulatorParametersPointer^.CRC := CalcCRC8(@RegulatorParametersByteArray, SizeOf(RegulatorParametersByteArray) - 1);

    FCommand.Value := ByteArrayToHexString(RegulatorParametersByteArray);
  except
    Result := False;
  end;
end;

function TCalibratorThread.Read76File: Boolean;
begin
  try
    Result := True;

    HexToBin(PWideChar(FCommand.Answer), File76ByteArray[0], Length(FCommand.Answer) div 2);

    if (File76ByteArray[Low(File76ByteArray)] and 1) = 1 then
      FAdjusterState := asOn
    else
      FAdjusterState := asOff;

    if FDeviceProcedure = dpPrepareToCalibration then
      Result := PrepareToWrite76File;

    UpdateCalibratorStateLabelSync;
  except
    Result := False;
  end;
end;

function TCalibratorThread.PrepareToWrite76File: Boolean;
begin
  try
    File76ByteArray[Low(File76ByteArray)] := File76ByteArray[Low(File76ByteArray)] or 1;
    File76ByteArray[High(File76ByteArray)] := CalcCRC8(@File76ByteArray, Length(File76ByteArray) - 1);

    FCommand.Value := ByteArrayToHexString(File76ByteArray);

    Result := True;
    FAdjusterState := asOn;
  except
    Result := False;
  end;
end;

function TCalibratorThread.ReadCurrentTemperature: Boolean;
var
  TemperatureFloat: Extended;
begin
  try
    if TryStrToFloat(FCommand.Answer, TemperatureFloat) then
    begin
      SetTemperature(FTemperature, TemperatureFloat);
      DisplayTemperatureSync;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function TCalibratorThread.Read0File: Boolean;
var
  ByteArray: array[0..35] of Byte;
  MITTemp: Extended;
  Adjuster: TAdjuster;
  StabilityTime: TDateTime;
  IsStable: Boolean;
begin
  try
    HexToBin(PWideChar(FCommand.Answer), ByteArray[0], Length(ByteArray));

    FAdjusterPointer := @ByteArray;
    Adjuster := FAdjusterPointer^;

    UpdateGroupBoxCaptionSynch(Format('%s Уставка: %.1f°С', [FDeviceName, Adjuster.MainBlockSetPoint]));

    MITTemp := fMain.MITThread.Temperatures[FIndex].Celsius;
    FMIT_M90Accuracy := ((FTemperature.Celsius - MITTemp) / MITTemp) * 100;

    DisplayAccuracy;

    IsStable := (Adjuster.StabilisationSeconds > 0) or (Adjuster.StabilisationMinutes > 0) or (Adjuster.StabilisationHours > 0);
    if IsStable then
    begin
      Include(FCalibratorStates, csAdjusted);
      StabilityTime := EncodeTime(Adjuster.StabilisationHours, Adjuster.StabilisationMinutes, Adjuster.StabilisationSeconds, 0);
      FTimeAdjusted := FormatDateTime('hh:mm:ss', StabilityTime, FormatSettings);
//      FTimeAdjusted := Format('%.2d:%.2d:%.2d', [StabilisationHours, StabilisationMinutes, StabilisationSeconds]);
      SendToBothLogs(Format('%s вошла в режим', [FDeviceName]), clGreen);
    end
    else
    begin
      Exclude(FCalibratorStates, csAdjusted);
      FTimeAdjusted := string.Empty;
    end;

    UpdateCalibratorStateLabelSync;
    Result := True;
  except
    Result := False;
  end;
end;

function TCalibratorThread.HandleSerialNumber: Boolean;

  function HandleVerificationInformation(SerialNumber: string): Boolean;
  var
    LogMessage: string;
  begin
    GetVerificDateDifference(SerialNumber, FValidVerification, LogMessage);

    if not LogMessage.IsEmpty then
    begin
      Synchronize(procedure begin ChangeStatusBar(FDeviceName + ' ' + LogMessage); end);
      SendToBothLogsSync(Format('%s %s', [FDeviceName, LogMessage]), clRed);
    end;

    if not FValidVerification then
      StopObtainingData;

    Result := FValidVerification;
  end;

begin
  FSerialNumber := dmData.FDC.ExecSQLScalar('SELECT SERIAL FROM EQUIPMENT WHERE IDENTIFICATION_STR CONTAINING :IDENTIFICATION_STR', [FAnswer]);
  if not FSerialNumber.IsEmpty then
  begin
    SendToBothLogsSync(Format('[%s] Серийный номер М90: %s', [FDeviceName, FSerialNumber]), clGreen);

    FDeviceName := Format('M90 №%s', [FSerialNumber]);
    UpdateGroupBoxCaptionSynch(FDeviceName);

    Include(FCalibratorStates, csSerialNumberConfirmed);
    Result := True;

    if not FIsVerificDateChecked and not IsSettingsOpened then
      Result := HandleVerificationInformation(FSerialNumber);

    if IsSettingsOpened then
    begin
      ChangeBitButtonAndComboBox(FSerialNumber, True, clGreen);
      Result := False;
    end;
  end
  else
  if AreAttemptsEnded then
  begin
    SendToBothLogsSync(Format('[%s] Серийный номер M90 не подтверждён. Обратитесь к технологу', [FDeviceName]), clRed);
    if IsSettingsOpened then
      ChangeBitButtonAndComboBox('Серийный номер???', True, clRed);
  end;
end;

function TCalibratorThread.CheckConnectionPipeline: Boolean;
begin
  if FCommand.Name = 'Чтение типа прибора' then
    Result := ConfirmType
  else
  if FCommand.Name = 'Открытие файла из FLASH' then
    Result := HandleFileMessage
  else
  if IsTypeConfirmed and (FCommand.Name = 'Чтение серийника') then
    Result := HandleSerialNumber;
end;

function TCalibratorThread.ObtainDataPipeline: Boolean;
begin
  if FCommand.Name = 'Открытие файла из FLASH' then
    Result := HandleFileMessage
  else
  if IsFileOpened and (FCommand.Name = 'Чтение температуры текущей') then
    Result := ReadCurrentTemperature
  else
  if FCommand.Name = 'Переход к 76 файлу' then
    Result := HandleFileMessage
  else
  if IsFileOpened and (FCommand.Name = 'Чтение 76 файла') then
    Result := Read76File
  else
  if FCommand.Name = 'Открытие файла из RAM' then
    Result := HandleFileMessage
  else
  if FCommand.Name = 'Переход к 0 файлу' then
    Result := HandleFileMessage
  else
  if IsFileOpened and (FCommand.Name = 'Чтение 0 файла') then
    Result := Read0File;
end;

function TCalibratorThread.CalibrationPipeline: Boolean;
begin
  if FCommand.Name = 'Открытие файла из FLASH' then
    Result := HandleFileMessage
  else
  if FCommand.Name = 'Переход к 63 файлу' then
    Result := HandleFileMessage
  else
  if IsFileOpened and (FCommand.Name = 'Чтение 63 файла') then
    Result := Read63File
  else
  if IsFileOpened and (FCommand.Name = 'Запись 63 файла') then
    Result := HandleFileMessage
  else
  if FCommand.Name = 'Переход к 76 файлу' then
    Result := HandleFileMessage
  else
  if IsFileOpened and (FCommand.Name = 'Чтение 76 файла') then
    Result := Read76File
  else
  if IsFileOpened and (FCommand.Name = 'Запись 76 файла') then
    Result := HandleFileMessage
  else
  if FCommand.Name = 'Актуализация данных' then
    Result := HandleFileMessage;
end;

procedure TCalibratorThread.SwitchProcedureTo(aDeviceProcedure: TDeviceProcedure);
var
  MemTableLoadOptionsEh: TMemTableLoadOptionsEh;

  procedure SetAllFieldsToFalse;
  begin
    FCommands.First;
    while not FCommands.Eof do
    begin
      MarkCommandSucceeded(False);
      FCommands.Next;
    end;
    FCommands.First;
  end;

begin
  MemTableLoadOptionsEh := [tloUseCachedUpdatesEh, tloDisregardFilterEh, tloOpenOnLoad];
  ResetCommandAttemptCount;
  FDeviceProcedure := aDeviceProcedure;

  case FDeviceProcedure of
    dpCheckConnection:
      begin
        FIsReadyToBeginToCalibrate := False;
        dmData.mteM90CheckConnectionCommands.First;
//        FCommands.LoadFromMemTableEh(dmData.mteM90CheckConnectionCommands, -1, lmCopy, MemTableLoadOptionsEh);
        FCommands.LoadFromDataSet(dmData.mteM90CheckConnectionCommands, -1, lmCopy, False);
//        SetAllFieldsToFalse;
        FCalibratorStates := [];
        FAdjusterState := asOff;

        {$IFDEF DEBUG}
          SendToBothLogsSync(Format('[%s] --> Процедура проверки связи (dpCheckConnection)', [FDeviceName]));
        {$ENDIF}
      end;
    dpObtainData:
      begin
        if IsTypeConfirmed then
        begin
          dmData.mteM90ObtainDataCommands.First;
//          FCommands.LoadFromMemTableEh(dmData.mteM90ObtainDataCommands, -1, lmCopy, MemTableLoadOptionsEh);
          FCommands.LoadFromDataSet(dmData.mteM90ObtainDataCommands, -1, lmCopy, False);
          FIsReadyToBeginToCalibrate := True;

          {$IFDEF DEBUG}
            SendToBothLogsSync(Format('[%s] --> Процедура сбора информации (dpObtainData)', [FDeviceName]));
          {$ENDIF}

        end;
      end;
    dpPrepareToCalibration:
      begin
        dmData.mteM90PrepareToCalibrationCommands.First;
//        FCommands.LoadFromMemTableEh(dmData.mteM90PrepareToCalibrationCommands, -1, lmCopy, MemTableLoadOptionsEh);
        FCommands.LoadFromDataSet(dmData.mteM90PrepareToCalibrationCommands, -1, lmCopy, False);

        {$IFDEF DEBUG}
          SendToBothLogsSync(Format('[%s] --> Процедура подготовки к калибровке (dpPrepareToCalibration)', [FDeviceName]));
        {$ENDIF}

      end;
    dpTurnOffRegulator:
      begin
//        mteM90PrepareToCalibrationCommands.First;
//        FCommands.LoadFromDataSet(mteM90PrepareToCalibrationCommands, -1, lmCopy, False);
      end;
  end;
  FCommands.Refresh;
end;

procedure TCalibratorThread.DisplayTemperatureSync;
begin
  Synchronize(procedure
  begin
    FTemperatureCelsiusPanel.Caption := FTemperature.CelsiusString;
    FTemperatureKelvinPanel.Caption := FTemperature.KelvinString;
  end);
end;

procedure TCalibratorThread.DisplayNothingSync;
begin
  inherited;
  Synchronize(procedure
  begin
    FAccuracyPanel.Caption := '-';
    FTemperature.CelsiusString := '-';
    FTemperature.KelvinString := '-';
  end);
  DisplayTemperatureSync;
end;

procedure TCalibratorThread.UpdateCalibratorStateLabelSync;
var
  Color: TColor;
  MessageText: string;
begin
  Synchronize(procedure
  begin
    Color := clBlack;
    if not IsCalibratorAdjusted then
      case FAdjusterState of
        asUnknown:
        begin
          Color := clRed;
          MessageText := 'Неизвестно';
        end;
        asOff:
        begin
          Color := clRed;
          MessageText := 'Выключен';
        end;
        asOn:
        begin
          Color := clBlue;
          MessageText := 'Включен';
        end;
      end
    else
    begin
      Color := clGreen;
      MessageText := Format('В режиме (%s)', [FTimeAdjusted]);
    end;

    FStateLabel.Font.Color := Color;
    FStateLabel.Caption := Format('Статус КТ: %s', [MessageText]);
  end);
end;

function TCalibratorThread.IsMitTemperatureNull: Boolean;
begin
  Result := not (FTemperature.CelsiusString <> '-') and not (fMain.MITThread.Temperatures[FIndex].CelsiusString.IsEmpty);
end;

procedure TCalibratorThread.DisplayAccuracy;
begin
  Synchronize(procedure
    begin
      FAccuracyPanel.Font.Color := clBlack;

      if IsMitTemperatureNull then
      begin
        FAccuracyPanel.Caption := '-';
    //    FIsReadyToBeginToCalibrate := False;
      end
      else
      begin
        if CompareValue(Abs(FMIT_M90Accuracy), ConfigParams.MIT_M90ErrorMargin, 0.01) = LessThanValue then
        begin
          FAccuracyPanel.Font.Color := clGreen;
          if IsCalibratorAdjusted {and not FIsReadyToBeginToCalibrate} then
          begin
    //        FIsReadyToBeginToCalibrate := True;
            SendToBothLogsSync(Format('Разница между МИТ и %s меньше %s', [FDeviceName, FormatFloat('0.0', ConfigParams.MIT_M90ErrorMargin)]));
          end;
        end
        else
        begin
          FAccuracyPanel.Font.Color := clRed;
    //      FIsReadyToBeginToCalibrate := False;
        end;

        FAccuracyPanel.Caption := FormatFloat('0.000', FMIT_M90Accuracy) + '%';
      end;
    end);
end;

end.
