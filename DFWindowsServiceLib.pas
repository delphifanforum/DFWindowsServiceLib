unit DFWindowsServiceLib;

interface

uses
  Winapi.Windows, System.SysUtils;

type
  TDFWindowsService = class
  private
    FName: string;
    FDisplayName: string;
    FDescription: string;
    FStatus: DWORD;
    FStartupType: DWORD;
  public
    property Name: string read FName write FName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Description: string read FDescription write FDescription;
    property Status: DWORD read FStatus write FStatus;
    property StartupType: DWORD read FStartupType write FStartupType;

    procedure Start;
    procedure Stop;
    procedure Pause;
    procedure Resume;
    procedure Restart;
  end;

  TDFWindowsServiceManager = class
  public
    function GetServices: TStringList;
    function GetServiceStatus(const ServiceName: string): DWORD;
    procedure InstallService(const ServiceName, DisplayName, Description, ExecutablePath: string);
    procedure UninstallService(const ServiceName: string);
    procedure ChangeServiceConfiguration(const ServiceName: string; const StartupType: DWORD);
  end;

  TDFWindowsServiceInstaller = class
  public
    procedure InstallService(const ServiceName, DisplayName, Description, ExecutablePath: string);
    procedure UninstallService(const ServiceName: string);
  end;

implementation

{ TDFWindowsService }

procedure TDFWindowsService.Start;
var
  ServiceHandle: SC_HANDLE;
  ServiceStatus: TServiceStatus;
begin
  ServiceHandle := OpenService(SCManager, PChar(Name), SERVICE_START);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not StartService(ServiceHandle, 0, nil) then
      RaiseLastOSError;
 if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
      RaiseLastOSError;
    while ServiceStatus.dwCurrentState = SERVICE_START_PENDING do
    begin
      Sleep(ServiceStatus.dwWaitHint);
      if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
        RaiseLastOSError;
    end;
    Status := ServiceStatus.dwCurrentState;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsService.Stop;
var
  ServiceHandle: SC_HANDLE;
  ServiceStatus: TServiceStatus;
begin
  ServiceHandle := OpenService(SCManager, PChar(Name), SERVICE_STOP);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not ControlService(ServiceHandle, SERVICE_CONTROL_STOP, ServiceStatus) then
      RaiseLastOSError;
    if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
      RaiseLastOSError;
    while ServiceStatus.dwCurrentState = SERVICE_STOP_PENDING do
    begin
      Sleep(ServiceStatus.dwWaitHint);
      if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
        RaiseLastOSError;
    end;
    Status := ServiceStatus.dwCurrentState;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsService.Pause;
var
  ServiceHandle: SC_HANDLE;
  ServiceStatus: TServiceStatus;
begin
  ServiceHandle := OpenService(SCManager, PChar(Name), SERVICE_PAUSE_CONTINUE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not ControlService(ServiceHandle, SERVICE_CONTROL_PAUSE, ServiceStatus) then
      RaiseLastOSError;
    if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
      RaiseLastOSError;
    while ServiceStatus.dwCurrentState = SERVICE_PAUSE_PENDING do
    begin
      Sleep(ServiceStatus.dwWaitHint);
      if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
        RaiseLastOSError;
    end;
    Status := ServiceStatus.dwCurrentState;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsService.Resume;
var
  ServiceHandle: SC_HANDLE;
  ServiceStatus: TServiceStatus;
begin
  ServiceHandle := OpenService(SCManager, PChar(Name), SERVICE_PAUSE_CONTINUE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not ControlService(ServiceHandle, SERVICE_CONTROL_CONTINUE, ServiceStatus) then
      RaiseLastOSError;
    if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
      RaiseLastOSError;
    while ServiceStatus.dwCurrentState = SERVICE_CONTINUE_PENDING do
    begin
      Sleep(ServiceStatus.dwWaitHint);
      if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
        RaiseLastOSError;
    end;
    Status := ServiceStatus.dwCurrentState;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsService.Restart;
begin
  Stop;
  Start;
end;

{ TDFWindowsServiceManager }

function TDFWindowsServiceManager.GetServices: TStringList;
var
  ServiceHandle: SC_HANDLE;
  ServiceEnum: TEnumServiceStatus;
  BytesNeeded, ServicesReturned, ResumeHandle: DWORD;
begin
  Result := TStringList.Create;
  ServiceHandle := OpenSCManager(nil, nil, SC_MANAGER_ENUMERATE_SERVICE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    ResumeHandle := 0;
    repeat
      if not EnumServicesStatus(ServiceHandle, SERVICE_WIN32, SERVICE_STATE_ALL, ServiceEnum, SizeOf(ServiceEnum), BytesNeeded, ServicesReturned, ResumeHandle) then
        RaiseLastOSError;
      if ServicesReturned > 0 then
      begin
        for var i := 0 to ServicesReturned - 1 do
          Result.Add(ServiceEnum[i].lpServiceName);
      end;
    until (ServicesReturned = 0) or (ResumeHandle = 0);
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

function TDFWindowsServiceManager.GetServiceStatus(const ServiceName: string): DWORD;
var
  ServiceHandle: SC_HANDLE;
  ServiceStatus: TServiceStatus;
begin
  ServiceHandle := OpenService(SCManager, PChar(ServiceName), SERVICE_QUERY_STATUS);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not QueryServiceStatus(ServiceHandle, ServiceStatus) then
      RaiseLastOSError;
    Result := ServiceStatus.dwCurrentState;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsServiceManager.InstallService(const ServiceName, DisplayName, Description, ExecutablePath: string);
var
  ServiceHandle: SC_HANDLE;
begin
  ServiceHandle := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    ServiceHandle := CreateService(ServiceHandle, PChar(ServiceName), PChar(DisplayName), SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL, PChar(ExecutablePath), nil, nil, nil, nil, nil);
    if ServiceHandle = 0 then
      RaiseLastOSError;
    try
      ChangeServiceConfig2(ServiceHandle, SERVICE_CONFIG_DESCRIPTION, @Description);
    finally
      CloseServiceHandle(ServiceHandle);
    end;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsServiceManager.UninstallService(const ServiceName: string);
var
  ServiceHandle: SC_HANDLE;
begin
  ServiceHandle := OpenService(SCManager, PChar(ServiceName), SERVICE_STOP or DELETE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not DeleteService(ServiceHandle) then
      RaiseLastOSError;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsServiceManager.ChangeServiceConfiguration(const ServiceName: string; const StartupType: DWORD);
var
  ServiceHandle: SC_HANDLE;
begin
  ServiceHandle := OpenService(SCManager, PChar(ServiceName), SERVICE_CHANGE_CONFIG);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not ChangeServiceConfig(ServiceHandle, SERVICE_NO_CHANGE, StartupType, SERVICE_NO_CHANGE, nil, nil, nil, nil, nil, nil, nil) then
      RaiseLastOSError;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

{ TDFWindowsServiceInstaller }

procedure TDFWindowsServiceInstaller.InstallService(const ServiceName, DisplayName, Description, ExecutablePath: string);
var
  ServiceHandle: SC_HANDLE;
begin
  ServiceHandle := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    ServiceHandle := CreateService(ServiceHandle, PChar(ServiceName), PChar(DisplayName), SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL, PChar(ExecutablePath), nil, nil, nil, nil, nil);
    if ServiceHandle = 0 then
      RaiseLastOSError;
    try
      ChangeServiceConfig2(ServiceHandle, SERVICE_CONFIG_DESCRIPTION, @Description);
    finally
      CloseServiceHandle(ServiceHandle);
    end;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

procedure TDFWindowsServiceInstaller.UninstallService(const ServiceName: string);
var
  ServiceHandle: SC_HANDLE;
begin
  ServiceHandle := OpenService(SCManager, PChar(ServiceName), SERVICE_STOP or DELETE);
  if ServiceHandle = 0 then
    RaiseLastOSError;
  try
    if not DeleteService(ServiceHandle) then
      RaiseLastOSError;
  finally
    CloseServiceHandle(ServiceHandle);
  end;
end;

end.
