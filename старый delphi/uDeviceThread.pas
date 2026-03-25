unit uDeviceThread;

interface

uses
  Winapi.Windows,
  System.Classes, System.SyncObjs, System.SysUtils, System.StrUtils,
  VCl.StdCtrls, Vcl.Graphics, Vcl.Buttons,
  ComponentUSB, CPDrv, MemTableEh;

type
  TDeviceProcedure = (dpCheckConnection, dpObtainData, dpPrepareToCalibration, dpTurnOffRegulator);

  TDeviceThread = class (TThread)
  protected
    FDeviceName             : string;
    FLastWorkingPort        : string;
    FLastPortHandle         : THandle;
    FSerialNumber           : string;
    FComponentUSB           : TComponentUSB;
    FComPort                : TCommPortDriver;
    FStartEvent             : TEvent;
    FTimeout                : Cardinal;

    FSendingAttempt         : Word;
    FBigCycleAttempt        : Word;

    FStateLabel             : TLabel;
    FConnectionStateLabel   : TLabel;
    FButton                 : TButton;
    FGroupBox               : TGroupBox;
    FBitButton              : TBitBtn;
    FComboBox               : TComboBox;

    FDeviceProcedure        : TDeviceProcedure;

    procedure OnUSBArrival(Sender: TObject);
    procedure OnUSBRemove(Sender: TObject);

    procedure Execute; override;

    procedure FreeComponents; virtual;
    procedure SetComponents; virtual; abstract;
    procedure SetInitialValues; virtual; abstract;
    procedure DisplayNothingSync; virtual;
    procedure UpdateComPort; virtual; abstract;

    procedure ResetCommandAttemptCount;

    procedure SendToLogSync(LogMessage: string);
    procedure SendToRichEditSync(LogMessage: string; Color: TColor = clBlack);
    procedure SendToBothLogsSync(LogMessage: string; Color: TColor = clBlack);
    procedure UpdateConnectionStateLabelSync(Text: string = string.Empty; Color: TColor = clBlack); virtual;
    procedure UpdateGroupBoxCaptionSynch(Text: string);
    procedure ChangeBitButtonAndComboBox(Text: string; AreComponentsEnabled: Boolean; Color: TColor = clBlack);
    procedure ShowConnectionButton(IsVisible: Boolean);
    procedure HandleCheckConnectionFailed;
    procedure HandleError(ErrorMessage: string);

    procedure OnComboboxClick(Sender: TObject); virtual;
    procedure OnButtonClick(Sender: TObject);
    procedure OnBitButtonClick(Sender: TObject);

    function TryConnectPort: Boolean; virtual;
    function Communicate: Boolean; virtual; abstract;
  public
    constructor Create;
    destructor Destroy;

    procedure StartObtainingData; virtual;
    procedure StopObtainingData; virtual;
  end;

implementation

uses
  uDefinitions, uSettings;

constructor TDeviceThread.Create;
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FStartEvent := TEvent.Create(nil, True, False, '');

  FComponentUSB := TComponentUSB.Create(nil);
  FComponentUSB.OnUSBArrival := OnUSBArrival;
  FComponentUSB.OnUSBRemove := OnUSBRemove;

  SetComponents;
  StartObtainingData;
  DeviceThreads.Add(Self);
end;

procedure TDeviceThread.HandleError(ErrorMessage: string);
begin
  ChangeBitButtonAndComboBox('Проверить связь', True);
  SendToBothLogsSync(Format('[%s] Ошибка! %s', [FDeviceName, ErrorMessage]), clRed);
end;

function TDeviceThread.TryConnectPort: Boolean;
begin
  if not FComPort.PortName.IsEmpty and FComPort.Connect then
  begin
    FLastWorkingPort := FComPort.PortName;
    FLastPortHandle := FComPort.Handle;
    FStartEvent.SetEvent;
    Exit;
  end
  else
    FConnectionStateLabel.Caption := ('Не выбран COM порт');

  SendToBothLogsSync(Format('[%s] Не удалось открыть порт %s', [FDeviceName, FComPort.PortName]));
end;

procedure TDeviceThread.StopObtainingData;
begin
  FComPort.FlushBuffers(True, True);
  FComPort.Disconnect;
  DisplayNothingSync;
  if IsSettingsOpened then
  begin
    ShowConnectionButton(False);
    ChangeBitButtonAndComboBox('Проверить связь', True);
    UpdateConnectionStateLabelSync;
  end
  else
    UpdateConnectionStateLabelSync('Нет связи', clRed);
  FStartEvent.ResetEvent;
end;

procedure TDeviceThread.StartObtainingData;
begin
  SetInitialValues;
  TryConnectPort;
end;

destructor TDeviceThread.Destroy;
begin
  DeviceThreads.Remove(Self);
  inherited;
end;

procedure TDeviceThread.DisplayNothingSync;
begin
  Synchronize(procedure begin FStateLabel.Caption := string.Empty; end);
end;

procedure TDeviceThread.Execute;
begin
  try
    try
      while not Terminated do
      begin
        FStartEvent.WaitFor;
        Communicate;
      end;
    except
      on E: Exception do
        HandleError(E.Message);
    end;
  finally
    FreeComponents;
  end;
end;

procedure TDeviceThread.FreeComponents;
begin
  FreeAndNil(FStartEvent);
  FreeAndNil(FComponentUSB);
end;

procedure TDeviceThread.SendToBothLogsSync(LogMessage: string; Color: TColor);
begin
  Synchronize(procedure begin SendToBothLogs(LogMessage, Color); end);
end;

procedure TDeviceThread.SendToLogSync(LogMessage: string);
begin
  Synchronize(procedure begin SendToLog(LogMessage); end);
end;

procedure TDeviceThread.SendToRichEditSync(LogMessage: string; Color: TColor);
begin
  Synchronize(procedure begin SendToRichEdit(LogMessage, Color); end);
end;

procedure TDeviceThread.UpdateConnectionStateLabelSync(Text: string; Color: TColor);
begin
  Synchronize(procedure
  begin
    if Text = string.Empty then
      FConnectionStateLabel.Caption := Text
    else
    begin
      FConnectionStateLabel.Caption := Format('Статус соединения %s: (%s):%s%s', [FDeviceName, FComPort.PortName, sLineBreak, Text]);
      FConnectionStateLabel.Font.Color := Color;
    end;
  end);
end;

procedure TDeviceThread.UpdateGroupBoxCaptionSynch(Text: string);
begin
  if Assigned(FGroupBox) then
    Synchronize(procedure begin FGroupBox.Caption := Text; end);
end;

procedure TDeviceThread.ChangeBitButtonAndComboBox(Text: string; AreComponentsEnabled: Boolean; Color: TColor);
begin
  if Assigned(FBitButton) then
    Synchronize(procedure
    begin
      begin
        FBitButton.Font.Color := Color;
        FBitButton.Caption := Text;
        FBitButton.Enabled := AreComponentsEnabled;
        FComboBox.Enabled := AreComponentsEnabled;
      end;
    end);
end;

procedure TDeviceThread.OnBitButtonClick(Sender: TObject);
begin
  ChangeBitButtonAndComboBox('Проверка...', False);
  StartObtainingData;
end;

procedure TDeviceThread.OnButtonClick(Sender: TObject);
begin
  ShowConnectionButton(False);
  StartObtainingData;
end;

procedure TDeviceThread.OnComboboxClick(Sender: TObject);
begin
  fSettings.CheckPortDuplicates(Sender);
  UpdateComPort;
  ChangeBitButtonAndComboBox('Проверить связь', True)
end;

procedure TDeviceThread.OnUSBArrival(Sender: TObject);
begin
  FComPort.EnumComPorts(FComboBox.Items);
  FComPort.EnumComPorts(FComboBox.Items);
  if FComboBox.Items.IndexOf(FLastWorkingPort) <> - 1 then
    ConfigParams.MITPort := FLastWorkingPort;
end;

procedure TDeviceThread.OnUSBRemove(Sender: TObject);
begin
  FComPort.EnumComPorts(FComboBox.Items);
  if FComboBox.Items.IndexOf(FLastWorkingPort) = - 1 then
  begin
    StopObtainingData;
    CloseHandle(FLastPortHandle);
  end;
end;

procedure TDeviceThread.ResetCommandAttemptCount;
begin
  FSendingAttempt := 0;
  FBigCycleAttempt := 0;
end;

procedure TDeviceThread.ShowConnectionButton(IsVisible: Boolean);
begin
  if Assigned (FButton) then
    Synchronize(procedure begin FButton.Visible := IsVisible; end);
end;

procedure TDeviceThread.HandleCheckConnectionFailed;
begin
  if IsSettingsOpened then
    ChangeBitButtonAndComboBox('Нет связи', True, clRed);
  UpdateConnectionStateLabelSync('Нет связи', clRed);
  StopObtainingData;
end;

end.
