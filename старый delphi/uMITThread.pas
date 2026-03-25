unit uMITThread;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, System.SyncObjs, System.Types,
  WinApi.Windows,
  Vcl.Graphics, Vcl.Buttons, Vcl.StdCtrls, Vcl.ExtCtrls,
  CPDrv, ComponentUSB,
  uDefinitions, uDeviceThread;

type
  TMITThread = class(TDeviceThread)
  private
    FValidVerification: Boolean;
    FIsVerificDateChecked: Boolean;
    FAnswer: AnsiString;
    FTemperatures: array[1..3] of TTemperatures;

    FTemperatureCelsiusLabel: TLabel;
    FTemperatureKelvinPanel: TPanel;
    FSerialNumber: string;

    procedure UpdateComPort; override;

    procedure SetComponents; override;
    procedure SetInitialValues; override;

    function GetTemperature(Index: Byte): TTemperatures;
    function Communicate: Boolean; override;

    procedure ParseAnswer;
    procedure DisplayTemperature(Index: Byte);
    procedure DisplayNothingSync(Index: Byte); overload;
    procedure DisplayNothingSync; overload; override;

    procedure ClearAnswer;
    procedure OnComboboxClick(Sender: TObject);
  public
    property Temperatures[Index: Byte]: TTemperatures read GetTemperature;
    property SerialNumber: string read FSerialNumber;
  end;

implementation

uses
  uSettings, uMain;

{ uMITThread }

procedure TMITThread.SetComponents;
begin
  FTimeout := 4000;
  FDeviceName := 'МИТ';
  FSerialNumber := EmptyStr;

  FConnectionStateLabel := fMain.lMITConnectionState;
  FButton := fMain.bMITConnect;
  FButton.Caption := 'Переподключиться';
  FButton.OnClick := OnButtonClick;

  FBitButton := fSettings.bbCheckConnectionMIT;
  FBitButton.OnClick := OnBitButtonClick;

  FComPort := fSettings.cpdMIT;

  FComboBox := fSettings.cbbMITPorts;
  FComboBox.OnClick := OnComboboxClick;

  FComPort.EnumComPorts(FComboBox.Items);
  UpdateComPort;
  FBitButton.Enabled := FComboBox.Text <> string.Empty;
end;

procedure TMITThread.SetInitialValues;
begin
  FIsVerificDateChecked := False;
end;

procedure TMITThread.UpdateComPort;
begin
  if Assigned(FComboBox) then
  begin
    FComPort.Disconnect;
    FComboBox.ItemIndex := FComboBox.Items.IndexOf(ConfigParams.MITPort);
    if FComboBox.ItemIndex <> -1 then
    begin
      FComboBox.Text := ConfigParams.MITPort;
      FComPort.PortName := ConfigParams.MITPort;
    end
    else
      FComPort.PortName := EmptyStr;
  end;
end;

function TMITThread.GetTemperature(Index: Byte): TTemperatures;
begin
  Result := FTemperatures[Index];
end;

procedure TMITThread.ClearAnswer;
var
  LastPosBAndSpace: Word;
begin
  LastPosBAndSpace := Pos('B' + Char(VK_SPACE), FAnswer);
  while LastPosBAndSpace > 0 do
  begin
    Delete(FAnswer, 1, LastPosBAndSpace + 1);
    LastPosBAndSpace := Pos('B' + Char(VK_SPACE), FAnswer);
  end;
end;

function TMITThread.Communicate: Boolean;
var
  Color: TColor;
  StartTime: Cardinal;
begin
  StartTime := GetTickCount;

  while FComPort.Connected and ((GetTickCount - StartTime) < FTimeout) do
  begin
    while FComPort.CountRX > 0 do
    begin
      SetLength(FAnswer, Length(FAnswer) + FComPort.CountRX);
      FComPort.ReadData(@FAnswer[Length(FAnswer) - FComPort.CountRX + 1], FComPort.CountRX);
    end;

//    Yield;
    Sleep(1);

    if FAnswer <> string.Empty then
    begin
      ParseAnswer;
      Break;
    end;
  end;

  if (GetTickCount - StartTime) >= FTimeout then
  begin
    ShowConnectionButton(True);
    HandleCheckConnectionFailed;
  end;
end;

procedure TMITThread.ParseAnswer;

  function HandleVerificationInformation(SerialNumber: string): Boolean;
  var
    LogMessage: string;
  begin
    GetVerificDateDifference(SerialNumber, FValidVerification, LogMessage);

    if LogMessage <> string.Empty then
    begin
      Synchronize(procedure begin ChangeStatusBar(FDeviceName + ' ' + LogMessage); end);
      SendToBothLogsSync(Format('%s %s', [FDeviceName, LogMessage]), clRed);
    end;

    if not FValidVerification then
      StopObtainingData;

    Result := FValidVerification;
  end;

const
  MIT_NULL_DATA: Extended = -1.000000E+06;
var
  Strings: TArray<string>;
  AnswerString, TemperatureValue: string;
  MITLabelIndex: Integer;
  TemperatureFloat: Extended;
begin
  if not (FIsVerificDateChecked or IsSettingsOpened) then
  begin
    FSerialNumber := GetMITSerial;

    if FSerialNumber.IsEmpty then
    begin
      SendToBothLogsSync('МИТ не привязан к стенду. Обратитесь к технологу', clRed);
      StopObtainingData;
      Exit;
    end
    else
      FIsVerificDateChecked := HandleVerificationInformation(FSerialNumber);

    if not FIsVerificDateChecked then
      Exit;
  end;

  if (Length(FAnswer) = 0) or not ContainsText(FAnswer, 'B' + Char(VK_SPACE)) then
    Exit;

  {$IFDEF DEBUG}
    SendToRichEditSync(Format('[%s] <-- %s', [FDeviceName, FAnswer]), clTeal);
  {$ENDIF}

  Strings := SplitString(FAnswer, 'B' + Char(VK_SPACE));
  for AnswerString in Strings do
  begin
    if IsSettingsOpened then
    begin
      ChangeBitButtonAndComboBox('Связь есть', True, clGreen);
      Break;
    end;

    TemperatureValue := CutStringOut(AnswerString, ':');

    if not TryStrToInt(LeftStr(AnswerString, 1), MITLabelIndex) or (MITLabelIndex > 4){ or (MITLabelIndex < 1)} then
      Continue;

    if TryStrToFloat(TemperatureValue, TemperatureFloat) then
    begin
      if TemperatureFloat = MIT_NULL_DATA then
      begin
        DisplayNothingSync(MITLabelIndex);
        Continue;
      end;

      SetTemperature(FTemperatures[MITLabelIndex], TemperatureFloat);
      Synchronize(procedure begin DisplayTemperature(MITLabelIndex); end);
    end;
  end;

  UpdateConnectionStateLabelSync('Связь есть', clGreen);

  ClearAnswer;
end;

procedure TMITThread.DisplayTemperature(Index: Byte);
var
  MITLabel: TLabel;
  MITPanel: TPanel;
begin
  Synchronize(procedure
  begin
    MITLabel := fMain.FindComponent(Format('lMITCelsuis%d', [Index])) as TLabel;
    MITLabel.Alignment := taRightJustify;
    MITLabel.Caption := FTemperatures[Index].CelsiusString;
    MITPanel := fMain.FindComponent(Format('pMITKelvins%d', [Index])) as TPanel;
    MITPanel.Caption := FTemperatures[Index].KelvinString;
  end);
end;

procedure TMITThread.DisplayNothingSync(Index: Byte);
var
  MITLabel: TLabel;
  MITPanel: TPanel;
begin
  Synchronize(procedure
  begin
    MITLabel := fMain.FindComponent(Format('lMITCelsuis%d', [Index])) as TLabel;
    MITLabel.Alignment := taCenter;
    MITLabel.Caption := '-';
    MITPanel := fMain.FindComponent(Format('pMITKelvins%d', [Index])) as TPanel;
    MITPanel.Caption := '-';
  end);
end;

procedure TMITThread.DisplayNothingSync;
var
  Index: Byte;
  MITLabel: TLabel;
  MITPanel: TPanel;
begin
  inherited;
  for Index := 1 to 3 do
    Synchronize(procedure
    begin
      MITLabel := fMain.FindComponent(Format('lMITCelsuis%d', [Index])) as TLabel;
      MITLabel.Alignment := taCenter;
      MITLabel.Caption := '-';
      MITPanel := fMain.FindComponent(Format('pMITKelvins%d', [Index])) as TPanel;
      MITPanel.Caption := '-';
      FTemperatures[Index].CelsiusString := EmptyStr;
      FTemperatures[Index].KelvinString := EmptyStr;
    end);
end;

procedure TMITThread.OnComboboxClick(Sender: TObject);
begin
  ConfigParams.MITPort := FComboBox.Text;
  inherited;
end;

end.
