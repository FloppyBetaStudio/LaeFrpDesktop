unit unitFormLogin;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpserver, Forms, Controls, Graphics, Dialogs, StdCtrls,
  LCLIntf;

type


  TLoginWebServerThread = class(TThread)
  private
    tmpServer: TFPHttpServer;
    procedure httpHandler(Sender: TObject;
      Var ARequest: TFPHTTPConnectionRequest;
      Var AResponse : TFPHTTPConnectionResponse);
  public
    destructor Destroy; override;

    procedure Execute; override;


  end;

  { TFormLogin }
  TFormLogin = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  private
    threadLoginServer: TLoginWebServerThread;
  public
  procedure logWrite(logText: string);
  end;



var
  FormLogin: TFormLogin;

implementation
uses FormMain;

procedure TFormLogin.Button1Click(Sender: TObject);
begin
  Button1.Enabled:=false;
  threadLoginServer:=TLoginWebServerThread.Create(false);
  Button2.Enabled:=true;
  logWrite('服务端线程已启动');
end;

procedure TFormLogin.Button2Click(Sender: TObject);
begin
  logWrite('打开网页');
  OpenURL('https://api.laecloud.com?callback='+'http://'+threadLoginServer.tmpServer.HostName+':'+IntToStr(threadLoginServer.tmpServer.Port));
end;

procedure TFormLogin.Button3Click(Sender: TObject);
begin
  Halt(114514);
end;

procedure TFormLogin.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Halt(114514);
end;


procedure TFormLogin.logWrite(logText: string);
begin
  Memo1.Append(logText);
end;
{$R *.lfm}

procedure TLoginWebServerThread.Execute();
begin
  FreeOnTerminate:=true;
  tmpServer:=TFPHttpServer.Create(nil);
  tmpServer.ServerBanner:='LaeFrpDesktopLogin '+productVersion;
  tmpServer.Port:=11451;
  tmpServer.HostName:='localhost';
  tmpServer.UseSSL:=false;
  tmpServer.OnRequest:=@httpHandler;
  tmpServer.Active:=true;
end;

destructor TLoginWebServerThread.Destroy();
begin
  tmpServer.Active:=false;
  FreeAndNil(tmpServer);
end;

procedure TLoginWebServerThread.httpHandler(Sender: TObject;
      Var ARequest: TFPHTTPConnectionRequest;
      Var AResponse : TFPHTTPConnectionResponse);
begin
  //测试服务端可用
  //AResponse.Content:='HelloWorld';
  if(ARequest.QueryFields.Values['token'] = '')then begin
    AResponse.Content:='Token not available';
    exit;
  end;
  MainForm.LabeledEditAPIKey.Text:=ARequest.QueryFields.Values['token'];
  MainForm.BCMaterialDesignButtonSaveAPIKeyClick(nil);
  AResponse.Content:='Success';
  FormLogin.Button2.Enabled:=false;
  FormLogin.logWrite('获取到token，请关闭本窗口，数据已保存。请重启本软件');
end;

end.

