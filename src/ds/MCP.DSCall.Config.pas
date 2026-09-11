// Raul Pavanelli/Claude - 10/09/2026
// Leitura da configuracao externa MCP.DSCall.json.
// Diferente do MCP.DBLink (conexao unica), aqui a configuracao e um ARRAY de
// servidores DataSnap: o array e a allowlist — nenhum host fora dele e
// alcancavel pelas tools, o que atende a exigencia de travar o host.
// Se o arquivo nao existir, gera um esqueleto com os servidores de DEV.
unit MCP.DSCall.Config;

interface

type
  TDSServerConfig = record
    Name        : String;
    Description : String;
    Host        : String;
    Port        : Integer;
    HttpPort    : Integer;   // 0 => derivado como '8' + Port (regra do DS.Config.pas)
    User        : String;
    Password    : String;
    Environment : String;    // rotulo livre: DEV / HOMOLOG / PROD
    AllowWrite  : Boolean;   // False => ds_call recusa invocar neste servidor
    IsDefault   : Boolean;
  end;

  TMCPOptions = record
    TimeoutMS : Integer;
    SqlLogMax : Integer;
  end;

  TMCPDSCallConfig = record
    Servers : TArray<TDSServerConfig>;
    MCP     : TMCPOptions;
  end;

function  ConfigFileName: String;
procedure SaveDefaultConfig(const AFile: String);
function  LoadConfig: TMCPDSCallConfig;

// Resolve o servidor pelo nome (case-insensitive). Nome vazio devolve o marcado
// como default ou, na ausencia dele, o primeiro do array.
function  FindServer(const AConfig: TMCPDSCallConfig; const AName: String; out AServer: TDSServerConfig): Boolean;

// Porta HTTP efetiva: a configurada, ou '8' + porta TCP quando vier zerada.
function  HttpPortDe(const AServer: TDSServerConfig): Integer;

// Nomes cadastrados, para compor mensagens de erro uteis.
function  NomesServidores(const AConfig: TMCPDSCallConfig): String;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.JSON;

const
  DEFAULT_JSON =
    '{'                                            + sLineBreak +
    '  "servers": ['                               + sLineBreak +
    '    {'                                        + sLineBreak +
    '      "name": "MD007",'                       + sLineBreak +
    '      "description": "MATRIZ - DEV local",'   + sLineBreak +
    '      "host": "127.0.0.1",'                   + sLineBreak +
    '      "port": 211,'                           + sLineBreak +
    '      "http_port": 0,'                        + sLineBreak +
    '      "user": "ADMIN",'                       + sLineBreak +
    '      "password": "ADMIN;DEV;DSConnection",'  + sLineBreak +
    '      "environment": "DEV",'                  + sLineBreak +
    '      "allow_write": true,'                   + sLineBreak +
    '      "default": true'                        + sLineBreak +
    '    },'                                       + sLineBreak +
    '    {'                                        + sLineBreak +
    '      "name": "MD029",'                       + sLineBreak +
    '      "description": "LOJAS - DEV local",'    + sLineBreak +
    '      "host": "127.0.0.1",'                   + sLineBreak +
    '      "port": 229,'                           + sLineBreak +
    '      "http_port": 0,'                        + sLineBreak +
    '      "user": "ADMIN",'                       + sLineBreak +
    '      "password": "ADMIN;DEV;DSConnection",'  + sLineBreak +
    '      "environment": "DEV",'                  + sLineBreak +
    '      "allow_write": false,'                  + sLineBreak +
    '      "default": false'                       + sLineBreak +
    '    }'                                        + sLineBreak +
    '  ],'                                         + sLineBreak +
    '  "mcp": {'                                   + sLineBreak +
    '    "timeout_ms": 30000,'                     + sLineBreak +
    '    "sql_log_max": 20'                        + sLineBreak +
    '  }'                                          + sLineBreak +
    '}'                                            + sLineBreak;

function ConfigFileName: String;
begin
  Result := ChangeFileExt(ParamStr(0), '.json');
end;

procedure SaveDefaultConfig(const AFile: String);
var
  Texto: TStringStream;
begin
  Texto := TStringStream.Create(DEFAULT_JSON, TEncoding.UTF8);
  try
    Texto.SaveToFile(AFile);
  finally
    Texto.Free;
  end;
end;

function HttpPortDe(const AServer: TDSServerConfig): Integer;
begin
  if AServer.HttpPort > 0 then
    Exit(AServer.HttpPort);

  // Regra do IGERP (DS.Config.pas): PortHTTP := '8' + PortTCP
  Result := StrToIntDef('8' + AServer.Port.ToString, 0);
end;

function FindServer(const AConfig: TMCPDSCallConfig; const AName: String; out AServer: TDSServerConfig): Boolean;
var
  Servidor: TDSServerConfig;
begin
  Result := False;

  if Length(AConfig.Servers) = 0 then
    Exit;

  if AName.Trim <> '' then
  begin
    for Servidor in AConfig.Servers do
      if SameText(Servidor.Name, AName.Trim) then
      begin
        AServer := Servidor;
        Exit(True);
      end;

    Exit;
  end;

  for Servidor in AConfig.Servers do
    if Servidor.IsDefault then
    begin
      AServer := Servidor;
      Exit(True);
    end;

  AServer := AConfig.Servers[0];
  Result  := True;
end;

function NomesServidores(const AConfig: TMCPDSCallConfig): String;
var
  Servidor: TDSServerConfig;
begin
  Result := '';

  for Servidor in AConfig.Servers do
  begin
    if Result <> '' then
      Result := Result + ', ';

    Result := Result + Servidor.Name;
  end;
end;

function LoadConfig: TMCPDSCallConfig;
var
  sArquivo : String;
  sJSON    : String;
  Raiz     : TJSONObject;
  Lista    : TJSONArray;
  Item     : TJSONValue;
  Opcoes   : TJSONObject;
  Servidor : TDSServerConfig;
  iIndice  : Integer;
begin
  SetLength(Result.Servers, 0);
  Result.MCP.TimeoutMS := 30000;
  Result.MCP.SqlLogMax := 20;

  sArquivo := ConfigFileName;

  // Primeira utilizacao: gera o arquivo ja com os servidores de DEV e aborta
  // para o operador conferir.
  if not TFile.Exists(sArquivo) then
  begin
    SaveDefaultConfig(sArquivo);
    raise Exception.CreateFmt(
      'Arquivo de configuracao gerado em %s com os servidores MD007 e MD029. Confira os parametros e execute novamente.',
      [sArquivo]);
  end;

  sJSON := TFile.ReadAllText(sArquivo, TEncoding.UTF8);

  Raiz := TJSONObject.ParseJSONValue(sJSON) as TJSONObject;
  if Raiz = nil then
    raise Exception.Create('Falha ao parsear MCP.DSCall.json');

  try
    Lista := Raiz.GetValue('servers') as TJSONArray;
    if (Lista = nil) or (Lista.Count = 0) then
      raise Exception.Create('MCP.DSCall.json nao tem nenhum servidor em "servers".');

    SetLength(Result.Servers, Lista.Count);
    iIndice := 0;

    for Item in Lista do
    begin
      if not (Item is TJSONObject) then
        Continue;

      Servidor.Name        := TJSONObject(Item).GetValue<String>('name', '');
      Servidor.Description := TJSONObject(Item).GetValue<String>('description', '');
      Servidor.Host        := TJSONObject(Item).GetValue<String>('host', '127.0.0.1');
      Servidor.Port        := TJSONObject(Item).GetValue<Integer>('port', 0);
      Servidor.HttpPort    := TJSONObject(Item).GetValue<Integer>('http_port', 0);
      Servidor.User        := TJSONObject(Item).GetValue<String>('user', 'ADMIN');
      Servidor.Password    := TJSONObject(Item).GetValue<String>('password', '');
      Servidor.Environment := TJSONObject(Item).GetValue<String>('environment', '');
      Servidor.AllowWrite  := TJSONObject(Item).GetValue<Boolean>('allow_write', False);
      Servidor.IsDefault   := TJSONObject(Item).GetValue<Boolean>('default', False);

      if Servidor.Name.Trim = '' then
        raise Exception.Create('Ha um servidor sem "name" no MCP.DSCall.json — o nome e a chave usada pelas tools.');

      if Servidor.Port <= 0 then
        raise Exception.CreateFmt('Servidor %s esta sem "port" valida no MCP.DSCall.json.', [Servidor.Name]);

      Result.Servers[iIndice] := Servidor;
      Inc(iIndice);
    end;

    SetLength(Result.Servers, iIndice);

    Opcoes := Raiz.GetValue('mcp') as TJSONObject;
    if Assigned(Opcoes) then
    begin
      Result.MCP.TimeoutMS := Opcoes.GetValue<Integer>('timeout_ms',  30000);
      Result.MCP.SqlLogMax := Opcoes.GetValue<Integer>('sql_log_max', 20);
    end;
  finally
    Raiz.Free;
  end;
end;

end.
