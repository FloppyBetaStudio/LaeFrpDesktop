unit FormMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, StdCtrls, Grids, BCMaterialDesignButton, fpjson, jsonparser, IniFiles,
  opensslsockets, Types, LCLIntf, FileUtil, process, UTF8Process;

type

  { TMainForm }

  TMainForm = class(TForm)
    BCMaterialDesignButton1: TBCMaterialDesignButton;
    BCMaterialDesignButton2: TBCMaterialDesignButton;
    BCMaterialDesignButton3: TBCMaterialDesignButton;
    BCMaterialDesignButton4: TBCMaterialDesignButton;
    BCMaterialDesignButton5: TBCMaterialDesignButton;
    BCMaterialDesignButton6: TBCMaterialDesignButton;
    BCMaterialDesignButton7: TBCMaterialDesignButton;
    BCMaterialDesignButton8: TBCMaterialDesignButton;
    BCMaterialDesignButtonSaveAPIKey: TBCMaterialDesignButton;
    Button1: TButton;
    Button2: TButton;
    ButtonMyTunnelListRefresh: TButton;
    ButtonNT_Create: TButton;
    ButtonServerListRefresh: TButton;
    ComboBoxNT_server: TComboBox;
    ComboBoxNT_protocol: TComboBox;
    EditNT_SpecialParameter: TEdit;
    EditNT_LocalAddress: TEdit;
    EditNT_Name: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    LabelAccountInfo: TLabel;
    LabeledEditAPIKey: TLabeledEdit;
    MainPageControl: TPageControl;
    MemoServiceLog: TMemo;
    Panel1: TPanel;
    PanelHideMyTunnels: TPanel;
    ShapeSelectBar: TShape;
    SheetMyInfo: TTabSheet;
    SheetServerList: TTabSheet;
    SheetMyTunnels: TTabSheet;
    StringGrid1: TStringGrid;
    SheetNewTunnel: TTabSheet;
    StringGrid2: TStringGrid;
    SheetServiceStatus: TTabSheet;
    TimerSelectBarMove: TTimer;
    TimerServicePipe: TTimer;
    procedure BCMaterialDesignButton1Click(Sender: TObject);
    procedure BCMaterialDesignButton2Click(Sender: TObject);
    procedure BCMaterialDesignButton3Click(Sender: TObject);
    procedure BCMaterialDesignButton4Click(Sender: TObject);
    procedure BCMaterialDesignButton5Click(Sender: TObject);
    procedure BCMaterialDesignButton6Click(Sender: TObject);
    procedure BCMaterialDesignButton7Click(Sender: TObject);
    procedure BCMaterialDesignButton8Click(Sender: TObject);
    procedure BCMaterialDesignButtonSaveAPIKeyClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ButtonMyTunnelListRefreshClick(Sender: TObject);
    procedure ButtonNT_CreateClick(Sender: TObject);
    procedure ButtonServerListRefreshClick(Sender: TObject);
    procedure ComboBoxNT_protocolChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Label4Click(Sender: TObject);
    procedure LabeledEditAPIKeyChange(Sender: TObject);

    function httpSendGet(uriPath: string): string;
    procedure MainPageControlChange(Sender: TObject);
    procedure MainPageControlChanging(Sender: TObject; var AllowChange: boolean);
    procedure PanelHideMyTunnelsClick(Sender: TObject);
    procedure SheetNewTunnelContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: boolean);
    procedure TimerSelectBarMoveTimer(Sender: TObject);
    procedure TimerServicePipeTimer(Sender: TObject);

    procedure UIChangeMenuSelected(TargetButton: TBCMaterialDesignButton);
  private

  public

  end;

  TFrpProcessThread = class(TThread)
  private

  public
    ProcessObject: TProcessUTF8;
    TunnelName: string;

    constructor Create(configFilePath: string);
    destructor Destroy; override;

    procedure Execute; override;


  end;

var
  MainForm: TMainForm;
  fileConfig: TIniFile;
  apiKey: string;
  NT_ServerList_array: TJSONArray;
  TunnelsArray: TJSONArray;
  FrpThreadArray: array of TFrpProcessThread;


  UI_SelectedItemTop: integer;

const
  urlBackend = 'https://api.lae.yistars.net/api';
  productName = 'FBSFS/LaeFrpDesktop';
  productVersion = 'b2';

//文件在本程序目录下的相对路径(不包含第一个斜杠)
  {$ifdef Win64}
  fileFRPC = 'frpc.exe';
  {$elseif defined(Linux)}
  fileFRPC = 'frpc';
  {$endif}

implementation

{$R *.lfm}

{ TMainForm }

function UnicodeToChinese(sStr: string): string;
var
  index: integer;
  temp, top, last: string;
begin
  index := 1;
  while index >= 0 do
  begin
    index := Pos('\u', sStr) - 1;
    Result := '';
    if index < 0 then         //非 unicode编码不转换 ,自动过滤
    begin
      last := sStr;
      Result := Result + last;
      Exit;
    end;
    top := Copy(sStr, 1, index);
    // 取出 编码字符前的 非 unic 编码的字符，如数字
    temp := Copy(sStr, index + 1, 6); // 取出编码，包括 \u,如\u4e3f
    Delete(temp, 1, 2);
    Delete(sStr, 1, index + 6);
    Result := Result + top + widechar(StrToInt('$' + temp));
  end;
end;

function RandLettersASCII(len: shortint): string;
var
  tmp: string;
  i: shortint;
begin
  tmp := '';
  for i := 1 to len do
  begin
    tmp := tmp + Chr(Random(26) + 97);//ASCII表中的26个小写的拉丁字母
  end;
  Exit(tmp);
end;

function RandInt(minVal: integer; maxVal: integer): integer;
begin
  exit(Random(maxVal - minVal) + minVal);
end;

procedure ServiceWriteLog(info: string);
begin
  MainForm.MemoServiceLog.Append(info);
end;

//封装一份用来向接口发送GHET请求的函数，返回response的文本内容
//若状态码不正确或其它问题，则直接弹出提示并终止程序
function TMainForm.httpSendGet(uriPath: string): string;
var
  tmpClient: TFPHTTPClient;
  tmpStream: TStringStream;
begin
  tmpClient := TFPHTTPClient.Create(nil);
  tmpClient.AddHeader('authorization', 'Bearer ' + apiKey);
  tmpClient.AddHeader('user-agent', productName + productVersion);
  tmpStream := TStringStream.Create();
  tmpClient.HTTPMethod('GET', urlBackend + uriPath, tmpStream, [200, 401, 403, 400]);
  if tmpClient.ResponseStatusCode <> 200 then;
  begin
    MessageDlg('发生错误',
      '向后端接口发送get请求时发生错误，请尝试重启应用程序，原因:' +
      tmpClient.ResponseStatusText+LineEnding+
      '若重启后仍未得到解决，请尝试：检查网络连接、重新填写cookie',
      mtError,
      [mbYes], '');
    Halt;
  end;
  //ShowMessage(tmpStream.DataString);
  if (tmpClient.ResponseStatusCode = 200) then
    exit(UnicodeToChinese(tmpStream.DataString))
  else if (tmpClient.ResponseStatusCode = 400) then
  begin
    MessageDlg('发生错误',
      '后端返回400错误，我觉得你可能是没好好填参数',
      mtError,
      [mbYes], '');
  end;

end;

procedure TMainForm.MainPageControlChange(Sender: TObject);
begin

end;

procedure TMainForm.MainPageControlChanging(Sender: TObject; var AllowChange: boolean);
begin
  if MainPageControl.ActivePageIndex <> 3 then
  begin
    NT_ServerList_array.Free;
  end;
end;

procedure TMainForm.PanelHideMyTunnelsClick(Sender: TObject);
begin

end;

procedure TMainForm.SheetNewTunnelContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: boolean);
begin

end;

procedure TMainForm.TimerSelectBarMoveTimer(Sender: TObject);
begin
  if ShapeSelectBar.Top < UI_SelectedItemTop then
    ShapeSelectBar.Top := ShapeSelectBar.Top + 4;
  if ShapeSelectBar.Top > UI_SelectedItemTop then
    ShapeSelectBar.Top := ShapeSelectBar.Top - 4;
  if ShapeSelectBar.Top = UI_SelectedItemTop then TimerSelectBarMove.Interval := 0;
end;

procedure TMainForm.TimerServicePipeTimer(Sender: TObject);
var
  i: byte;
  bufferStrList: TStringList;
  encoder: TEncoding;
begin
  encoder := TEncoding.ANSI;
  if Length(FrpThreadArray) < 1 then exit;
  for i := 0 to length(FrpThreadArray) - 1 do
  begin
    //定时遍历所有数组，若有没读入的字节则读入所有内容并写入日志
    if FrpThreadArray[i].ProcessObject.Output.NumBytesAvailable > 0 then
      //ServiceWriteLog(FrpThreadArray[i].TunnelName+'>>'+FrpThreadArray[i].ProcessObject.Output.ReadAnsiString);
    begin
      (*FrpThreadArray[i].ProcessObject.Output.ReadBuffer(bufferStr, FrpThreadArray[i].ProcessObject.Output.NumBytesAvailable);
      ServiceWriteLog(FrpThreadArray[i].TunnelName+'>>'+bufferStr);*)
      bufferStrList := TStringList.Create();
      bufferStrList.LoadFromStream(FrpThreadArray[i].ProcessObject.Output, encoder);
      ServiceWriteLog(FrpThreadArray[i].TunnelName + '>>' + bufferStrList.GetText);

    end;
  end;
end;


procedure TMainForm.BCMaterialDesignButton1Click(Sender: TObject);
begin
  UIChangeMenuSelected(BCMaterialDesignButton1);
  MainPageControl.ActivePageIndex := 0;
end;

procedure TMainForm.BCMaterialDesignButton2Click(Sender: TObject);
begin
  if apiKey = '' then
  begin
    ShowMessage('请先设置Token再使用');
    exit;
  end;

  UIChangeMenuSelected(BCMaterialDesignButton2);
  MainPageControl.ActivePageIndex := 1;
end;

procedure TMainForm.BCMaterialDesignButton3Click(Sender: TObject);
begin
  if apiKey = '' then
  begin
    ShowMessage('请先设置Token再使用');
    exit;
  end;

  UIChangeMenuSelected(BCMaterialDesignButton3);

  Randomize;
  //为创建隧道的隧道名称填入值
  EditNT_Name.Text := RandLettersASCII(8);

  MainPageControl.ActivePageIndex := 2;
end;

procedure TMainForm.BCMaterialDesignButton4Click(Sender: TObject);
begin
  MainPageControl.ActivePageIndex := 3;

  //获取服务器信息对象
  NT_ServerList_array := (GetJSON(httpSendGet('/modules/frp/servers')) as
    TJSONObject).Arrays['data'];

end;

procedure TMainForm.BCMaterialDesignButton5Click(Sender: TObject);
var
  fileConfig: TFileStream;
  strConfig: string;
  i: byte;
  hostData: TJSONObject;
  strResponse: string;
begin
  if (StringGrid2.Row = 0) or (StringGrid2.Row >= StringGrid2.RowCount) then
  begin
    ShowMessage('请选择一个有效的隧道');
    exit;
  end;

  //ShowMessage(StringGrid2.Cells[0, StringGrid2.Row]);对应的隧道名称
  if (StringGrid2.Cells[2, StringGrid2.Row] <> '未开启') then
  begin
    ShowMessage('这个隧道似乎已经启用映射了');
    exit;
  end;


  //提取ID并获取配置信息
  for i := 0 to TunnelsArray.Count - 1 do
  begin
    if TunnelsArray.Objects[i].Strings['name'] = StringGrid2.Cells[0,
      StringGrid2.Row] then
    begin
      //在一堆隧道中找到了正确的名称，则获取ID，并发送请求获取信息并保存
      strResponse := (httpSendGet('/modules/frp/hosts/' +
        IntToStr(TunnelsArray.Objects[i].Integers['id'])));
      hostData := (GetJSON(strResponse) as TJSONObject).Objects['data'];

      //读取server和client的信息并拼接
      strConfig := hostData.Objects['config'].Strings['server'] +
        LineEnding + hostData.Objects['config'].Strings['client'];
      //strConfig := StringReplace(strConfig, '\n', LineEnding, [rfReplaceAll]);

      //防止重复名称的配置文件
      DeleteFile('temp' + PathDelim + StringGrid2.Cells[0, StringGrid2.Row] + '.ini');
      fileConfig := TFileStream.Create(Application.Location + 'temp' +
        PathDelim + StringGrid2.Cells[0, StringGrid2.Row] + '.ini', fmCreate);
      fileConfig.Position := 0;

      //写入配置信息
      fileConfig.Write(strConfig[1], Length(strConfig));
      fileConfig.Flush;
      fileConfig.Free;



      //我帮你刷新
      ButtonMyTunnelListRefreshClick(nil);
    end;
  end;

end;

procedure TMainForm.BCMaterialDesignButton6Click(Sender: TObject);
begin
  if (StringGrid2.Row = 0) or (StringGrid2.Row >= StringGrid2.RowCount) then
  begin
    ShowMessage('请选择一个有效的隧道');
    exit;
  end;
  //ShowMessage(StringGrid2.Cells[0, StringGrid2.Row]);对应的隧道名称
  if (StringGrid2.Cells[2, StringGrid2.Row] = '未开启') then
  begin
    ShowMessage('将要被取消映射的隧道于本机的状态不应该为未开启');
    exit;
  end;

  //只需要删除文件
  DeleteFile('temp' + PathDelim + StringGrid2.Cells[0, StringGrid2.Row] + '.ini');
  //我帮你刷新
  ButtonMyTunnelListRefreshClick(nil);
end;

procedure TMainForm.BCMaterialDesignButton7Click(Sender: TObject);
var
  httpClient: TFPHTTPClient;
  i: byte;
begin
  if (StringGrid2.Row = 0) or (StringGrid2.Row >= StringGrid2.RowCount) then
  begin
    ShowMessage('请选择一个有效的隧道');
    exit;
  end;
  //ShowMessage(StringGrid2.Cells[0, StringGrid2.Row]);对应的隧道名称

  //获取删除所需的hostid
  for i := 0 to TunnelsArray.Count - 1 do
  begin
    if TunnelsArray.Objects[i].Strings['name'] = StringGrid2.Cells[0,
      StringGrid2.Row] then
    begin
      //在一堆隧道中找到了正确的名称，则获取ID，并发送请求删除

      httpClient := TFPHTTPClient.Create(nil);
      httpClient.AddHeader('authorization', 'Bearer ' + apiKey);
      httpClient.AddHeader('user-agent', productName + productVersion);
      httpClient.Delete(urlBackend + '/modules/frp/hosts/' + IntToStr(
        TunnelsArray.Objects[i].Integers['id']));

      //我帮你刷新
      ButtonMyTunnelListRefreshClick(nil);
    end;
  end;

end;

procedure TMainForm.BCMaterialDesignButton8Click(Sender: TObject);
begin
  UIChangeMenuSelected(BCMaterialDesignButton8);
  MainPageControl.ActivePageIndex := 4;
end;

procedure TMainForm.BCMaterialDesignButtonSaveAPIKeyClick(Sender: TObject);
begin
  BCMaterialDesignButtonSaveAPIKey.Enabled := False;
  fileConfig.WriteString('auth', 'token', LabeledEditAPIKey.Text);
  apiKey := LabeledEditAPIKey.Text;
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
  configFileList: TStringList;
  i: byte;
begin
  if FileExists(fileFRPC) = False then
  begin
    ShowMessage('没有找到frp的可执行文件，请检查你下载并解压的软件是否完整');
    Application.Terminate;
  end;

  //启用

  ConfigFileList := FindAllFiles(Application.Location + 'temp', '*.ini', False);

  if (configFileList.Count = 0) then
  begin
    ShowMessage('你好像还没有启用任何隧道');
    exit;
  end;
  SetLength(FrpThreadArray, configFileList.Count);
  for i := 0 to configFileList.Count - 1 do
  begin
    //一股脑创建、启动就好了
    FrpThreadArray[i] := TFrpProcessThread.Create(configFileList[i]);
    FrpThreadArray[i].Execute;
  end;
  PanelHideMyTunnels.Visible := True;
  TimerServicePipe.Interval := 500;
  ServiceWriteLog('已启动FRP映射服务');
  Button1.Enabled := False;
  Button2.Enabled := True;

end;

procedure TMainForm.Button2Click(Sender: TObject);
var
  configFileList: TStringList;
  i: byte;
begin
  ConfigFileList := FindAllFiles(Application.Location + 'temp', '*.ini', False);
  if (configFileList.Count = 0) then
  begin
    exit;
  end;
  //停用
  TimerServicePipe.Interval := 0;
  for i := 0 to Length(FrpThreadArray) - 1 do
  begin
    FrpThreadArray[i].Free;

  end;
  SetLength(FrpThreadArray, 0);
  PanelHideMyTunnels.Visible := False;

  ServiceWriteLog('已停用FRP映射服务');
  Button2.Enabled := False;
  Button1.Enabled := True;
end;



procedure TMainForm.ButtonMyTunnelListRefreshClick(Sender: TObject);
var

  i: byte;
  ii: byte;
  strStatus: string;
  TempConfigFileList: TStringList;
begin
  StringGrid2.RowCount := 1;
  TunnelsArray := (GetJSON(httpSendGet('/modules/frp/hosts')) as
    TJSONObject).Arrays['data'];


  //为后续清除不必要配置文件的精彩剧情做铺垫
  TempConfigFileList := FindAllFiles(Application.Location + 'temp', '*.ini', False);
  //若没有隧道却存在隧道文件，则这个隧道文件一定不合理
  if (TunnelsArray.Count = 0) and (TempConfigFileList.Count > 0) then
  begin
    for i := 0 to TempConfigFileList.Count - 1 do
    begin
      DeleteFile(TempConfigFileList[i]);
    end;
  end;
  if TunnelsArray.Count = 0 then exit;

  //填入信息
  for i := 0 to TunnelsArray.Count - 1 do
  begin
    strStatus := '未开启';
    if FileExists(Application.Location + 'temp' + PathDelim +
      TunnelsArray.Objects[i].Strings['name'] + '.ini') then
      strStatus := '已启用';
    StringGrid2.InsertRowWithValues(1, [TunnelsArray.Objects[i].Strings['name'],
      TunnelsArray.Objects[i].Strings['protocol'] + '://' +
      TunnelsArray.Objects[i].Objects['server'].Strings['server_address'] +
      ':' + IntToStr(TunnelsArray.Objects[i].Integers['remote_port']),
      strStatus, TunnelsArray.Objects[i].Strings['created_at']]);

  end;

  //判断是否有不存在隧道的配置文件
  TempConfigFileList := FindAllFiles(Application.Location + 'temp', '*.ini', False);
  if TempConfigFileList.Count > 0 then
  begin
    //如果发现已有配置文件，则挨个掐头(路径)去尾(后缀)并判断是否存在
    for i := 0 to TempConfigFileList.Count - 1 do
    begin
      TempConfigFileList[i] :=
        StringReplace(TempConfigFileList[i], Application.Location +
        'temp' + PathDelim, '', []);
      TempConfigFileList[i] :=
        StringReplace(TempConfigFileList[i], '.ini', '', []);
      for ii := 0 to TunnelsArray.Count - 1 do
      begin
        if TunnelsArray.Objects[ii].Strings['name'] = TempConfigFileList[i] then
          Break;

        //如果**有多次循环**最后一次也没判断出来隧道存在，说明隧道不存在，则删除文件
        //另外，如果没有隧道存在却有隧道配置文件，则这个配置文件一定不应该存在
        //b2修正：如果只有一个隧道，而且配置文件的名称与该隧道的名称不同，则删除
        if ((ii = TunnelsArray.Count - 1) and (ii > 0)) or
          ((TunnelsArray.Count = 1) and
          (TunnelsArray.Objects[ii].Strings['name'] <> TempConfigFileList[i])) then
          DeleteFile(Application.Location + 'temp' + PathDelim +
            TempConfigFileList[i] + '.ini');
      end;
    end;

  end;
end;

procedure TMainForm.ButtonNT_CreateClick(Sender: TObject);
var
  httpClient: TFPHTTPClient;
  tmpJSON: TJSONObject;
  i: byte;
  httpResponse: string;
begin

  tmpJSON := TJSONObject.Create();

  //在这个case中将会生成创建隧道时所需的json参数
  case ComboBoxNT_protocol.ItemIndex of
    -1: Exit;
    0: begin
      //HTTP
      tmpJSON.Add('custom_domain', EditNT_SpecialParameter.Text);
      tmpJSON.Add('local_address', EditNT_LocalAddress.Text);
      tmpJSON.Add('name', EditNT_Name.Text);
      tmpJSON.Add('protocol', 'http');

      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if (ComboBoxNT_server.Text = NT_ServerList_array.Objects[i].Strings['name']) then
        begin
          tmpJSON.Add('server_id', NT_ServerList_array.Objects[i].Integers['id']);
          break;
        end;
      end;

    end;
    1: begin
      //HTTPS
      tmpJSON.Add('custom_domain', EditNT_SpecialParameter.Text);
      tmpJSON.Add('local_address', EditNT_LocalAddress.Text);
      tmpJSON.Add('name', EditNT_Name.Text);
      tmpJSON.Add('protocol', 'https');

      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if (ComboBoxNT_server.Text = NT_ServerList_array.Objects[i].Strings['name']) then
        begin
          tmpJSON.Add('server_id', NT_ServerList_array.Objects[i].Integers['id']);
          break;
        end;
      end;
    end;
    2: begin
      //raw TCP
      tmpJSON.Add('local_address', EditNT_LocalAddress.Text);
      tmpJSON.Add('name', EditNT_Name.Text);
      tmpJSON.Add('protocol', 'tcp');

      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if (ComboBoxNT_server.Text = NT_ServerList_array.Objects[i].Strings['name']) then
        begin
          tmpJSON.Add('server_id', NT_ServerList_array.Objects[i].Integers['id']);
          //判断端口
          if EditNT_SpecialParameter.Text <> '' then
          begin//用户填写了远程端口，则直接填入
            tmpJSON.Add('remote_port', StrToInt(EditNT_SpecialParameter.Text));
          end
          else
          begin//用户没有填写端口，则根据定义域随机生成
            tmpJSON.Add('remote_port',
              RandInt(NT_ServerList_array.Objects[i].Integers['min_port'],
              NT_ServerList_array.Objects[i].Integers['max_port']));
          end;

          break;
        end;
      end;
    end;
    3: begin
      //raw UDP
      tmpJSON.Add('local_address', EditNT_LocalAddress.Text);
      tmpJSON.Add('name', EditNT_Name.Text);
      tmpJSON.Add('protocol', 'udp');

      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if (ComboBoxNT_server.Text = NT_ServerList_array.Objects[i].Strings['name']) then
        begin
          tmpJSON.Add('server_id', NT_ServerList_array.Objects[i].Integers['id']);
          //判断端口
          if EditNT_SpecialParameter.Text <> '' then
          begin//用户填写了远程端口，则直接填入
            tmpJSON.Add('remote_port', StrToInt(EditNT_SpecialParameter.Text));
          end
          else
          begin//用户没有填写端口，则根据定义域随机生成
            tmpJSON.Add('remote_port',
              RandInt(NT_ServerList_array.Objects[i].Integers['min_port'],
              NT_ServerList_array.Objects[i].Integers['max_port']));
          end;

          break;
        end;
      end;
    end;
  end;

  httpClient := TFPHTTPClient.Create(nil);
  httpClient.AddHeader('authorization', 'Bearer ' + apiKey);
  httpClient.AddHeader('user-agent', productName + productVersion);
  httpClient.AddHeader('Content-Type', 'application/json; charset=UTF-8');
  httpClient.AddHeader('Accept', 'application/json');

  //ShowMessage(tmpJSON.FormatJSON());
  //发送请求部分可以复用，请求结果用ShowMessage简要描述也能复用
  httpClient.RequestBody := TRawByteStringStream.Create(tmpJSON.AsJSON);
  httpResponse := httpClient.Post(urlBackend + '/modules/frp/hosts');
  case httpClient.ResponseStatusCode of
    400: begin
      ShowMessage('隧道创建失败:');
      ShowMessage(UnicodeToChinese(httpResponse));
    end;
    401: ShowMessage('账户验证失败');
    200: ShowMessage('成功');
  end;
end;

procedure TMainForm.ButtonServerListRefreshClick(Sender: TObject);
var
  tmpResponseJSONObj: TJSONObject;
  tmpServerListArrayObj: TJSONArray;
  i: integer;//用于计数
begin
  StringGrid1.RowCount := 1;//清除表中数据
  //StringGrid1.InsertRowWithValues(1, ['a', '1']);
  tmpResponseJSONObj := GetJSON(httpSendGet('/servers')) as TJSONObject;
  tmpServerListArrayObj := tmpResponseJSONObj.Arrays['data'];
  for i := 0 to tmpServerListArrayObj.Count - 1 do
  begin
    //ShowMessage(tmpServerListArrayObj.Objects[i].Strings['name']);
    if (tmpServerListArrayObj.Objects[i].Objects['module'].Strings['id'] = 'frp') then
      StringGrid1.InsertRowWithValues(1,
        [tmpServerListArrayObj.Objects[i].Strings['name'],
        tmpServerListArrayObj.Objects[i].Strings['status']]);

  end;

end;

procedure TMainForm.ComboBoxNT_protocolChange(Sender: TObject);
var
  i: byte;//计数
begin
  ComboBoxNT_server.Items.Clear;
  case ComboBoxNT_protocol.ItemIndex of
    0: begin
      EditNT_SpecialParameter.TextHint := '域名';
      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if NT_ServerList_array.Objects[i].Integers['allow_http'] = 0 then Continue;
        ComboBoxNT_server.Items.Append(NT_ServerList_array.Objects[i].Strings['name']);
      end;
    end;
    1: begin
      EditNT_SpecialParameter.TextHint := '域名';
      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if NT_ServerList_array.Objects[i].Integers['allow_https'] = 0 then Continue;
        ComboBoxNT_server.Items.Append(NT_ServerList_array.Objects[i].Strings['name']);
      end;
    end;
    2: begin
      EditNT_SpecialParameter.TextHint := '端口号(启动生成，请留空)';
      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if NT_ServerList_array.Objects[i].Integers['allow_tcp'] = 0 then Continue;
        ComboBoxNT_server.Items.Append(NT_ServerList_array.Objects[i].Strings['name']);
      end;
    end;
    3: begin
      EditNT_SpecialParameter.TextHint := '端口号(启动生成，请留空)';
      for i := 0 to NT_ServerList_array.Count - 1 do
      begin
        if NT_ServerList_array.Objects[i].Integers['allow_udp'] = 0 then Continue;
        ComboBoxNT_server.Items.Append(NT_ServerList_array.Objects[i].Strings['name']);
      end;
    end;
  end;
  EditNT_SpecialParameter.Text := '';
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Button2.Enabled then
  begin
    Button2Click(nil);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainPageControl.ActivePageIndex := 0;
  UI_SelectedItemTop := BCMaterialDesignButton1.Top;
  Caption := productName + ' ' + productVersion;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  responseJSON: TJSONObject;
  responseStr: string;
begin
  Visible := True;
  fileConfig := TIniFile.Create('config.ini');
  //DeleteDirectory('temp', False);
  CreateDir('temp');
  LabeledEditAPIKey.Text := fileConfig.ReadString('auth', 'token', '');
  apiKey := LabeledEditAPIKey.Text;



  if (apiKey = '') then exit;
  //若没有登录账户则跳过获取部分步骤

  //DONE：展示账户信息
  responseStr := httpSendGet('/users');
  responseJSON := (GetJSON(responseStr, False) as TJSONObject).Objects['data'];
  LabelAccountInfo.Caption := Utf8ToAnsi('账户' + Utf8ToAnsi(
    responseJSON.Strings['name']) + '的信息' + LineEnding +
    '用户余额：' + Utf8ToAnsi(responseJSON.Strings['balance']) +
    LineEnding + '用户Drops：' + Utf8ToAnsi(responseJSON.Strings['drops']));

end;

procedure TMainForm.Label4Click(Sender: TObject);
begin
  OpenURL('https://auth.laecloud.com/');
end;

procedure TMainForm.LabeledEditAPIKeyChange(Sender: TObject);
begin
  BCMaterialDesignButtonSaveAPIKey.Enabled := True;
end;

constructor TFrpProcessThread.Create(configFilePath: string);
begin
  ProcessObject := TProcessUTF8.Create(nil);
  ProcessObject.Options := [poNoConsole, poUsePipes];
  ProcessObject.Executable := Application.Location + fileFRPC;
  ProcessObject.Parameters.Append('-c');
  //使用相对路径，因为担心使用绝对路径会导致不兼容含有空格的路径
  ProcessObject.Parameters.Append(StringReplace(configFilePath,
    Application.Location, '.' + PathDelim, []));
  TunnelName := StringReplace(configFilePath, Application.Location +
    'temp' + PathDelim, '', []);
  TunnelName := StringReplace(TunnelName, '.ini', '', []);

end;

destructor TFrpProcessThread.Destroy();
begin
  ProcessObject.Terminate(0);
end;

procedure TFrpProcessThread.Execute();
begin
  ProcessObject.Execute;
end;

procedure TMainForm.UIChangeMenuSelected(TargetButton: TBCMaterialDesignButton);
begin
  //UI_SelectedItemTop:=8+(ItemID*40);死的计算方法太该死了，不能适配其它的DPI
  UI_SelectedItemTop := TargetButton.Top;
  TimerSelectBarMove.Interval := 1;
end;

end.
