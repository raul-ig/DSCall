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
  end;

  // API REST (MD030, MD033, MD048...). Mesma filosofia do array de servidores:
  // o que esta aqui e a allowlist, e nada fora dela e alcancavel.
  TRestApiConfig = record
    Name        : String;
    Description : String;
    BaseUrl     : String;
    // none | basic | bearer | jwt-hs256
    Auth        : String;
    User        : String;
    Password    : String;
    Token       : String;   // auth=bearer: token fixo
    Secret      : String;   // auth=jwt-hs256: chave de assinatura
    Issuer      : String;   // auth=jwt-hs256: claim iss
    Subject     : String;   // auth=jwt-hs256: claim sub
    Environment : String;
    AllowWrite  : Boolean;
    HealthPath  : String;   // rota leve para o teste de conexao do rest_apis
    TimeoutSec  : Integer;
  end;

  TMCPOptions = record
    TimeoutMS : Integer;
    SqlLogMax : Integer;
  end;

  TMCPDSCallConfig = record
    Servers : TArray<TDSServerConfig>;
    Apis    : TArray<TRestApiConfig>;
    MCP     : TMCPOptions;
  end;

function  ConfigFileName: String;
procedure SaveDefaultConfig(const AFile: String);
function  LoadConfig: TMCPDSCallConfig;

// Resolve o servidor pelo nome (case-insensitive). NAO existe servidor padrao:
// nome vazio devolve False de proposito. Assumir um alvo por omissao foi
// considerado perigoso demais — o protocolo e identico em DEV e producao, e um
// engano so apareceria depois do efeito.
function  FindServer(const AConfig: TMCPDSCallConfig; const AName: String; out AServer: TDSServerConfig): Boolean;

// Porta HTTP efetiva: a configurada, ou '8' + porta TCP quando vier zerada.
function  HttpPortDe(const AServer: TDSServerConfig): Integer;

// Nomes cadastrados, para compor mensagens de erro uteis.
function  NomesServidores(const AConfig: TMCPDSCallConfig): String;

// Resolve a API REST pelo nome (case-insensitive). Como nos servidores, nao ha
// padrao: nome vazio devolve False.
function  FindApi(const AConfig: TMCPDSCallConfig; const AName: String; out AApi: TRestApiConfig): Boolean;
function  NomesApis(const AConfig: TMCPDSCallConfig): String;

// URL completa juntando BaseUrl e rota, sem barra dupla nem barra faltando.
function  UrlDe(const AApi: TRestApiConfig; const ARota: String): String;

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
    '      "allow_write": true'                    + sLineBreak +
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
    '      "allow_write": false'                   + sLineBreak +
    '    }'                                        + sLineBreak +
    '  ],'                                         + sLineBreak +
    '  "apis": ['                                  + sLineBreak +
    '    {'                                        + sLineBreak +
    '      "name": "MD030",'                       + sLineBreak +
    '      "description": "API REST - DEV local",' + sLineBreak +
    '      "base_url": "http://127.0.0.1:8030/",'  + sLineBreak +
    '      "auth": "basic",'                       + sLineBreak +
    '      "user": "ADMIN",'                       + sLineBreak +
    '      "password": "",'                        + sLineBreak +
    '      "environment": "DEV",'                  + sLineBreak +
    '      "allow_write": true,'                   + sLineBreak +
    '      "health_path": "",'                     + sLineBreak +
    '      "timeout_sec": 30'                      + sLineBreak +
    '    },'                                       + sLineBreak +
    '    {'                                        + sLineBreak +
    '      "name": "MD033",'                       + sLineBreak +
    '      "description": "API REST - DEV local",' + sLineBreak +
    '      "base_url": "https://127.0.0.1:8033/",' + sLineBreak +
    '      "auth": "bearer",'                      + sLineBreak +
    '      "token": "",'                           + sLineBreak +
    '      "environment": "DEV",'                  + sLineBreak +
    '      "allow_write": true,'                   + sLineBreak +
    '      "health_path": "",'                     + sLineBreak +
    '      "timeout_sec": 30'                      + sLineBreak +
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

  // Sem nome nao ha o que resolver: a escolha e sempre explicita.
  if AName.Trim = '' then
    Exit;

  for Servidor in AConfig.Servers do
    if SameText(Servidor.Name, AName.Trim) then
    begin
      AServer := Servidor;
      Exit(True);
    end;
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

function FindApi(const AConfig: TMCPDSCallConfig; const AName: String; out AApi: TRestApiConfig): Boolean;
var
  Api: TRestApiConfig;
begin
  Result := False;

  // Sem nome nao ha o que resolver: a escolha e sempre explicita.
  if AName.Trim = '' then
    Exit;

  for Api in AConfig.Apis do
    if SameText(Api.Name, AName.Trim) then
    begin
      AApi := Api;
      Exit(True);
    end;
end;

function NomesApis(const AConfig: TMCPDSCallConfig): String;
var
  Api: TRestApiConfig;
begin
  Result := '';

  for Api in AConfig.Apis do
  begin
    if Result <> '' then
      Result := Result + ', ';

    Result := Result + Api.Name;
  end;

  if Result = '' then
    Result := '(nenhuma cadastrada em "apis")';
end;

function UrlDe(const AApi: TRestApiConfig; const ARota: String): String;
var
  sRota: String;
begin
  Result := AApi.BaseUrl.Trim;
  sRota  := ARota.Trim;

  // Barra dupla ou barra faltando quebram rota em varios servidores; resolver
  // aqui evita que cada chamador tenha de lembrar disso.
  while Result.EndsWith('/') do
    Result := Result.Substring(0, Result.Length - 1);

  if sRota = '' then
    Exit(Result + '/');

  while sRota.StartsWith('/') do
    sRota := sRota.Substring(1);

  Result := Result + '/' + sRota;
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
  Api      : TRestApiConfig;
  iIndice  : Integer;
begin
  SetLength(Result.Servers, 0);
  SetLength(Result.Apis, 0);
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

      if Servidor.Name.Trim = '' then
        raise Exception.Create('Ha um servidor sem "name" no MCP.DSCall.json — o nome e a chave usada pelas tools.');

      if Servidor.Port <= 0 then
        raise Exception.CreateFmt('Servidor %s esta sem "port" valida no MCP.DSCall.json.', [Servidor.Name]);

      Result.Servers[iIndice] := Servidor;
      Inc(iIndice);
    end;

    SetLength(Result.Servers, iIndice);

    // "apis" e opcional: um config so com servidores DataSnap continua valido.
    Lista := Raiz.GetValue('apis') as TJSONArray;
    if Assigned(Lista) then
    begin
      SetLength(Result.Apis, Lista.Count);
      iIndice := 0;

      for Item in Lista do
      begin
        if not (Item is TJSONObject) then
          Continue;

        Api.Name        := TJSONObject(Item).GetValue<String>('name', '');
        Api.Description := TJSONObject(Item).GetValue<String>('description', '');
        Api.BaseUrl     := TJSONObject(Item).GetValue<String>('base_url', '');
        Api.Auth        := TJSONObject(Item).GetValue<String>('auth', 'none').Trim.ToLower;
        Api.User        := TJSONObject(Item).GetValue<String>('user', '');
        Api.Password    := TJSONObject(Item).GetValue<String>('password', '');
        Api.Token       := TJSONObject(Item).GetValue<String>('token', '');
        Api.Secret      := TJSONObject(Item).GetValue<String>('secret', '');
        Api.Issuer      := TJSONObject(Item).GetValue<String>('issuer', 'MCP.DSCall');
        Api.Subject     := TJSONObject(Item).GetValue<String>('subject', '');
        Api.Environment := TJSONObject(Item).GetValue<String>('environment', '');
        Api.AllowWrite  := TJSONObject(Item).GetValue<Boolean>('allow_write', False);
        Api.HealthPath  := TJSONObject(Item).GetValue<String>('health_path', '');
        Api.TimeoutSec  := TJSONObject(Item).GetValue<Integer>('timeout_sec', 30);

        if Api.Name.Trim = '' then
          raise Exception.Create('Ha uma API sem "name" no MCP.DSCall.json — o nome e a chave usada pelas tools.');

        if Api.BaseUrl.Trim = '' then
          raise Exception.CreateFmt('API %s esta sem "base_url" no MCP.DSCall.json.', [Api.Name]);

        Result.Apis[iIndice] := Api;
        Inc(iIndice);
      end;

      SetLength(Result.Apis, iIndice);
    end;

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
