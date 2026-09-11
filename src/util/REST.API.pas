(*----------------------------------------------------------------------------------------------------------------------
Irmãos Gonçalves Comércio e Indústria LTDA

Classe de conexão com servidor REST API

Autor: Eduardo Rodrigues Pêgo

Data: 18/08/2021
----------------------------------------------------------------------------------------------------------------------*)
unit REST.API;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.JSON,
  System.Classes,
  System.Generics.Collections,
  System.DateUtils,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.NetEncoding,
  System.Net.Mime;

{$SCOPEDENUMS ON} // Controla como os valores do tipo de enumeração serão usados

type
  TRESTAPI = class;

  TBody = class
  private
    FAPI: TRESTAPI;
    FStream: TStringStream;
    FMPFData: TMultipartFormData;
  public
    constructor Create(API: TRESTAPI);
    destructor Destroy; override;
    property API: TRESTAPI read FAPI;
    function Value(vContent: TJSONValue): TRESTAPI; overload;
    function Value(vContent: TStream): TRESTAPI; overload;
    function Value(vContent: TMultipartFormData): TRESTAPI; overload;
    function ToStream: TStringStream;
    function ToBytes: TBytes;
    function Clear: TRESTAPI;
  end;

  TResponseStatus = (Sucess, Error, Unknown);

  IContentResponse = interface
    ['{87731921-68B8-43B4-92E8-20EEDC5DFAB8}']
    function Content: TStringStream;
  end;

  TContentResponse = class(TInterfacedObject, IContentResponse)
  protected
    FContent: TStringStream;
  public
    class function New(sConteudo: String): IContentResponse; overload;
    class function New(ssConteudo: TStream): IContentResponse; overload;
    class function New(ssConteudo: TStream; Encoding: TEncoding): IContentResponse; overload;
    function Content: TStringStream;
    destructor Destroy; override;
  end;

  THeaders = class
  private
    FAPI: TRESTAPI;
    FHeaders: TNetHeaders;
  public
    constructor Create(API: TRESTAPI);
    property API: TRESTAPI read FAPI;
    property ToHeaders: TNetHeaders read FHeaders;
    function Value(oJSON: TJSONObject): TRESTAPI;
    function FindValue(sKey: String): Boolean;
    function GetStr(sKey: String): String;
    function Clear: TRESTAPI;
  end;

  TResponse = class
  private
    FStatusCode: Integer;
    FStatus: TResponseStatus;
    FAPI: TRESTAPI;
    FContent: IContentResponse;
    FJSON: TJSONValue;
    FHeaders: THeaders;
  protected
    function Value(AResponse: IHTTPResponse): TResponse;
  public
    constructor Create(API: TRESTAPI);
    destructor Destroy; override;
    property API: TRESTAPI read FAPI;
    property StatusCode: Integer read FStatusCode;
    property Status: TResponseStatus read FStatus;
    property Headers: THeaders read FHeaders;
    function ToString: String; override;
    function ToJSON: TJSONValue;
    function ToJSONObject: TJSONObject;
    function ToJSONArray: TJSONArray;
    function ToStream: TStringStream;
  end;

  TQuery = class
  private
    FAPI: TRESTAPI;
    FQuery: TArray<TPair<String, String>>;
    procedure InternalAdd(sKey, sValue: String);
  public
    constructor Create(API: TRESTAPI);
    property API: TRESTAPI read FAPI;
    function Value(oJSON: TJSONObject): TRESTAPI;
    function ToString: String; override;
    function Clear: TRESTAPI;
  end;

  TParams = class(TQuery)
  public
    function ToString: String; override;
  end;

  IAuth = interface
    ['{698EAF44-E2C5-4734-B164-3C84F98140DF}']
    function Get: String;
  end;

  TAuthBasic = class(TInterfacedObject, IAuth)
  private
    FToken: String;
    function Get: String;
  public
    class function New(const User: String; const Pass: String = ''): IAuth;
  end;

  TAuthBearer = class(TInterfacedObject, IAuth)
  private
    FToken: String;
    FMethod: TFunc<String>;
    function Get: String;
  public
    class function New(const Token: String): IAuth; overload;
    class function New(const Method: TFunc<String>): IAuth; overload;
  end;

  TRESTMethod = (None, GET, POST, PUT, DELETE);

  IAPILog = interface
    ['{185972D5-367B-4C6E-A7EF-754A1DFD8184}']
    procedure OnRequest(Method: TRESTMethod; URI: String; Headers: TNetHeaders; Body: TBody);
    procedure OnResponse(Method: TRESTMethod; URI: String; Headers: TNetHeaders; Body: TResponse);
  end;

  TRESTAPI = class
  private type
    TResponseClass = class of TResponse;
  private
    Client: TNetHTTPClient;
    Request: TNetHTTPRequest;
    FHost: String;
    FRoute: String;
    FQuery: TQuery;
    FParams: TParams;
    FHeaders: THeaders;
    FBody: TBody;
    FMethod: TRESTMethod;
    FResponse: TResponse;
    FAuth: IAuth;
    FEncoding: TEncoding;
    function GetURI: String;
  protected
    ResponseClass: TResponseClass;
    function InternalExecute: TRESTAPI; virtual;
    procedure PrepareAuth;
    procedure PrepareResponse(AResponse: IHTTPResponse); virtual;
    procedure ValidaCertificado(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    class procedure EnableLOG(ALog: IAPILog);
    class function LOG: IAPILog;
    function Host: String; overload; virtual;
    function Host(sHost: String): TRESTAPI; overload; virtual;
    function Route: String; overload; virtual;
    function Route(sRoute: String): TRESTAPI; overload; virtual;
    function Timeout: Single; overload; virtual;
    function Timeout(Value: Single): TRESTAPI; overload; virtual;
    property URI: String read GetURI;
    function Query: TQuery; overload; virtual;
    function Query(Value: TJSONObject): TRESTAPI; overload; virtual;
    function Params: TParams; overload; virtual;
    function Params(Value: TJSONObject): TRESTAPI; overload; virtual;
    function Authorization(Value: IAuth): TRESTAPI; overload;
    function Authorization: IAuth; overload;
    function Certificate(Password: String; PFX: TBytes): TRESTAPI;
    function Headers: THeaders; overload; virtual;
    function Headers(Value: TJSONObject): TRESTAPI; overload; virtual;
    function Encoding(Response: TEncoding): TRESTAPI;
    function Body: TBody; overload; virtual;
    function Body(Value: TJSONValue): TRESTAPI; overload; virtual;
    function Body(Value: TStream): TRESTAPI; overload; virtual;
    function Body(Value: TMultipartFormData): TRESTAPI; overload; virtual;
    function Method: TRESTMethod; overload; virtual;
    function Method(Value: TRESTMethod): TRESTAPI; overload; virtual;
    property Response: TResponse read FResponse;
    function GET: TRESTAPI; overload; virtual;
    function POST: TRESTAPI; overload; virtual;
    function PUT: TRESTAPI; overload; virtual;
    function DELETE: TRESTAPI; overload; virtual;
  end;

implementation

var
  FLOG: IAPILog;

{ TRESTAPI }

constructor TRESTAPI.Create;
begin
  Client := TNetHTTPClient.Create(nil);
  Request := TNetHTTPRequest.Create(nil);
  Request.Client := Client;
  FQuery := TQuery.Create(Self);
  FParams := TParams.Create(Self);
  FHeaders := THeaders.Create(Self);
  FBody := TBody.Create(Self);
  FEncoding := TEncoding.Default;
  ResponseClass := TResponse;
  Client.OnValidateServerCertificate := ValidaCertificado;
  Client.SynchronizeEvents  := False;
  Client.Asynchronous       := False;
  Request.SynchronizeEvents := False;
  Request.Asynchronous      := False;
end;

class procedure TRESTAPI.EnableLOG(ALog: IAPILog);
begin
  FLOG := ALog;
end;

class function TRESTAPI.LOG: IAPILog;
begin
  Result := FLOG;
end;

function TRESTAPI.Host: String;
begin
  Result := FHost;
end;

function TRESTAPI.Host(sHost: String): TRESTAPI;
begin
  Result := Self;
  FHost := sHost;
end;

function TRESTAPI.Route: String;
begin
  Result := FRoute;
end;

function TRESTAPI.Route(sRoute: String): TRESTAPI;
begin
  Result := Self;
  FRoute := sRoute;
end;

function TRESTAPI.Timeout(Value: Single): TRESTAPI;
var
  iValue: Integer;
begin
  Result := Self;
  iValue := Trunc(Value * MSecsPerSec);

  if iValue <= 0 then
    raise Exception.Create('Informe um timeout maior que zero!');

  Client.ConnectionTimeout  := iValue;
  Client.ResponseTimeout    := iValue;
  Request.ConnectionTimeout := iValue;
  Request.ResponseTimeout   := iValue;
end;

function TRESTAPI.Timeout: Single;
begin
  Result := Client.ResponseTimeout div MSecsPerSec;
end;

function TRESTAPI.Query: TQuery;
begin
  Result := FQuery;
end;

function TRESTAPI.Query(Value: TJSONObject): TRESTAPI;
begin
  Result := Self;
  FQuery.Value(Value);
end;

function TRESTAPI.Params: TParams;
begin
  Result := FParams;
end;

function TRESTAPI.Params(Value: TJSONObject): TRESTAPI;
begin
  Result := Self;
  FParams.Value(Value);
end;

function TRESTAPI.Authorization(Value: IAuth): TRESTAPI;
begin
  FAuth := Value;
  Result := Self;
end;

function TRESTAPI.Authorization: IAuth;
begin
  Result := FAuth;
end;

function TRESTAPI.Certificate(Password: String; PFX: TBytes): TRESTAPI;
begin
  Result := Self;
  Request.ClientCertificatePassword := Password;
  Request.ClientCertificateStream := TStringStream.Create(PFX);
end;

function TRESTAPI.Headers: THeaders;
begin
  Result := FHeaders;
end;

function TRESTAPI.Headers(Value: TJSONObject): TRESTAPI;
begin
  Result := Self;
  FHeaders.Value(Value);
end;

function TRESTAPI.Body: TBody;
begin
  Result := FBody;
end;

function TRESTAPI.Body(Value: TJSONValue): TRESTAPI;
begin
  Result := Self;
  FBody.Value(Value);
end;

function TRESTAPI.Body(Value: TStream): TRESTAPI;
begin
  Result := Self;
  FBody.Value(Value);
end;

function TRESTAPI.Body(Value: TMultipartFormData): TRESTAPI;
var
  Headers: TNetHeaders;
  Item: TNameValuePair;
begin
  Result := Self;

  // Remove o Content-Type do cabeçalho pois em MPFD ele deve calcular automaticamente
  Headers := [];
  for Item in FHeaders.ToHeaders do
    if Item.Name <> 'Content-Type' then
      Headers := Headers + [Item];
  FHeaders.FHeaders := Headers;

  FBody.Value(Value);
end;

function TRESTAPI.Method: TRESTMethod;
begin
  Result := FMethod;
end;

function TRESTAPI.Method(Value: TRESTMethod): TRESTAPI;
begin
  Result := Self;
  FMethod := Value;
end;

function TRESTAPI.GetURI: String;
  procedure AdicionarURL(var sURL: String; const sAdd: String);
  var
    sTemp: String;
  begin
    sTemp := sAdd.Trim;
    if sTemp.StartsWith('/') then
      sTemp := Copy(sTemp, 2);
    if sTemp.IsEmpty then
      Exit;
    if sURL.IsEmpty then
      sURL := sTemp
    else
    if not sURL.EndsWith('/') then
      sURL := sURL +'/'+ sTemp;
    if sURL.EndsWith('/') then
      sURL := Copy(sURL, 1, Pred(Length(Result)));
  end;
begin
  Result := EmptyStr;
  AdicionarURL(Result, FHost);
  AdicionarURL(Result, FRoute);
  AdicionarURL(Result, FParams.ToString);
  Result := Result + FQuery.ToString;
  Result := TURI.Create(Result).Encode;
end;

function TRESTAPI.GET: TRESTAPI;
begin
  Result := Method(TRESTMethod.GET).InternalExecute;
end;

function TRESTAPI.POST: TRESTAPI;
begin
  Result := Method(TRESTMethod.POST).InternalExecute;
end;

function TRESTAPI.PUT: TRESTAPI;
begin
  Result := Method(TRESTMethod.PUT).InternalExecute;
end;

function TRESTAPI.DELETE: TRESTAPI;
begin
  Result := Method(TRESTMethod.DELETE).InternalExecute;
end;

function TRESTAPI.InternalExecute: TRESTAPI;
begin
  Result := Self;

  if FMethod = TRESTMethod.None then
    raise Exception.Create('Informe o tipo de Método!');

  if not Assigned(ResponseClass) then
    raise Exception.Create('Informe o tipo de response!');

  if Assigned(FResponse) then
    FreeAndNil(FResponse);

  PrepareAuth;

  FResponse := ResponseClass.Create(Self);
  try
    if Assigned(FLOG) then
      FLOG.OnRequest(FMethod, URI, FHeaders.ToHeaders, FBody);

    case FMethod of
      TRESTMethod.GET: PrepareResponse(Request.Get(URI, nil, FHeaders.ToHeaders));
      TRESTMethod.POST:
      begin
        if Assigned(FBody.FMPFData) then
          PrepareResponse(Request.Post(URI, FBody.FMPFData, nil, FHeaders.ToHeaders))
        else
          PrepareResponse(Request.Post(URI, FBody.ToStream, nil, FHeaders.ToHeaders))
      end;
      TRESTMethod.PUT:
      begin
        if Assigned(FBody.FMPFData) then
          PrepareResponse(Request.Put(URI, FBody.FMPFData, nil, FHeaders.ToHeaders))
        else
          PrepareResponse(Request.Put(URI, FBody.ToStream, nil, FHeaders.ToHeaders));
      end;
      TRESTMethod.DELETE: PrepareResponse(Request.Delete(URI, nil, FHeaders.ToHeaders));
    end;

    if Assigned(FLOG) then
      FLOG.OnResponse(FMethod, URI, FResponse.Headers.ToHeaders, FResponse);
  except on E: Exception do
    begin
      FResponse.FStatus := TResponseStatus.Unknown;
      FResponse.FStatusCode := 0;
      FResponse.FContent := TContentResponse.New(E.Message);
    end;
  end;
end;

procedure TRESTAPI.PrepareAuth;
var
  sAuth: String;
begin
  if not Assigned(FAuth) then
    Exit;

  sAuth := FAuth.Get;

  if sAuth.Trim.IsEmpty then
    Exit;

  Headers(
    TJSONObject.Create
      .AddPair('Authorization', sAuth)
  );
end;

procedure TRESTAPI.PrepareResponse(AResponse: IHTTPResponse);
begin
  FResponse.Value(AResponse);
end;

procedure TRESTAPI.ValidaCertificado(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
begin
  Accepted := True;
end;

function TRESTAPI.Encoding(Response: TEncoding): TRESTAPI;
begin
  Result := Self;
  FEncoding := Response;
end;

destructor TRESTAPI.Destroy;
begin
  if Assigned(Request.ClientCertificateStream) then
    Request.ClientCertificateStream.Free;

  FreeAndNil(Client);
  FreeAndNil(Request);
  FreeAndNil(FQuery);
  FreeAndNil(FParams);
  FreeAndNil(FHeaders);
  FreeAndNil(FBody);
  if Assigned(FResponse) then
    FreeAndNil(FResponse);
end;

{ TContentResponse }

class function TContentResponse.New(sConteudo: String): IContentResponse;
begin
  Result := TContentResponse.Create;
  TContentResponse(Result).FContent := TStringStream.Create(sConteudo);
end;

class function TContentResponse.New(ssConteudo: TStream): IContentResponse;
begin
  Result := TContentResponse.Create;
  TContentResponse(Result).FContent := TStringStream.Create;
  if Assigned(ssConteudo) then
    TContentResponse(Result).FContent.CopyFrom(ssConteudo, ssConteudo.Size);
end;

class function TContentResponse.New(ssConteudo: TStream; Encoding: TEncoding): IContentResponse;
begin
  Result := TContentResponse.Create;
  TContentResponse(Result).FContent := TStringStream.Create(EmptyStr, Encoding);
  if Assigned(ssConteudo) then
    TContentResponse(Result).FContent.CopyFrom(ssConteudo, ssConteudo.Size);
end;

function TContentResponse.Content: TStringStream;
begin
  if not Assigned(FContent) then
    FContent := TStringStream.Create;
  Result := FContent;
end;

destructor TContentResponse.Destroy;
begin
  if Assigned(FContent) then
    FreeAndNil(FContent);
end;

{ TResponse }

constructor TResponse.Create(API: TRESTAPI);
begin
  FAPI := API;
end;

function TResponse.Value(AResponse: IHTTPResponse): TResponse;
var
  Pair: TNameValuePair;
  oJSON: TJSONObject;
begin
  Result := Self;

  FStatusCode := AResponse.StatusCode;
  case StatusCode div 100 of
    1..3: FStatus := TResponseStatus.Sucess;
    4..5: FStatus := TResponseStatus.Error;
  else
    FStatus := TResponseStatus.Unknown;
  end;

  oJSON := TJSONObject.Create;
  for Pair in AResponse.Headers do
    oJSON.AddPair(Pair.Name, Pair.Value);

  FHeaders := THeaders.Create(Self.FAPI);
  FHeaders.Value(oJSON);

  FContent := TContentResponse.New(AResponse.ContentStream, FAPI.FEncoding);
end;

function TResponse.ToStream: TStringStream;
begin
  Result := FContent.Content;
  if Assigned(Result) then
    Result.Position := 0;
end;

function TResponse.ToString: String;
begin
  Result := FContent.Content.DataString;
end;

function TResponse.ToJSON: TJSONValue;
begin
  if not Assigned(FJSON) then
    FJSON := TJSONObject.ParseJSONValue(FContent.Content.DataString);
  Result := FJSON;
end;

function TResponse.ToJSONObject: TJSONObject;
begin
  Result := TJSONObject(ToJSON);
end;

function TResponse.ToJSONArray: TJSONArray;
begin
  Result := TJSONArray(ToJSON);
end;

destructor TResponse.Destroy;
begin
  if Assigned(FJSON) then
    FreeAndNil(FJSON);
  if Assigned(FHeaders) then
    FreeAndNil(FHeaders);
end;

{ TBody }

constructor TBody.Create(API: TRESTAPI);
begin
  FAPI := API;
end;

function TBody.Value(vContent: TJSONValue): TRESTAPI;
begin
  try
    Result := Clear;
    FStream := TStringStream.Create(vContent.ToJSON);
  finally
    FreeAndNil(vContent);
  end;
end;

function TBody.Value(vContent: TStream): TRESTAPI;
begin
  try
    Result := Clear;
    FStream := TStringStream.Create;
    FStream.CopyFrom(vContent, 0, vContent.Size);
    FStream.SetSize(vContent.Size);
  finally
    FreeAndNil(vContent);
  end;
end;

function TBody.Value(vContent: TMultipartFormData): TRESTAPI;
begin
  Result := Clear;
  FMPFData := vContent;
end;

function TBody.ToStream: TStringStream;
begin
  Result := FStream;
  if Assigned(Result) then
    Result.Position := 0;
end;

function TBody.ToBytes: TBytes;
var
  ss: TStream;
begin
  Result := [];
  if Assigned(FMPFData) then
    ss := FMPFData.Stream
  else
    ss := FStream;
  if not Assigned(ss) then
    Exit;
  
  ss.Position := 0;
  SetLength(Result, ss.Size);
  if ss.Size > 0 then
    ss.Read(Result[0], ss.Size);
end;

function TBody.Clear: TRESTAPI;
begin
  Result := FAPI;
  if Assigned(FStream) then
    FreeAndNil(FStream);
  if Assigned(FMPFData) then
    FreeAndNil(FMPFData);
end;

destructor TBody.Destroy;
begin
  Clear;
end;

{ THeaders }

constructor THeaders.Create(API: TRESTAPI);
begin
  FAPI := API;
  Clear;
end;

function THeaders.Value(oJSON: TJSONObject): TRESTAPI;
var
  I, J: Integer;
  bFind: Boolean;
begin
  Result := FAPI;
  try
    for I := 0 to Pred(oJSON.Count) do
    begin
      bFind := False;
      for J := 0 to Pred(Length(FHeaders)) do      
      begin
        if FHeaders[J].Name.Equals(oJSON.Pairs[I].JsonString.Value) then
        begin
          FHeaders[J].Value := oJSON.Pairs[I].JsonValue.Value;
          bFind := True;
          Break;
        end;
      end;
      if bFind or oJSON.Pairs[I].JsonValue.Value.Trim.IsEmpty or oJSON.Pairs[I].JsonString.Value.Trim.IsEmpty then
        Continue;
      SetLength(FHeaders, Succ(Length(FHeaders)));
      FHeaders[Pred(Length(FHeaders))] := TNameValuePair.Create(oJSON.Pairs[I].JsonString.Value, oJSON.Pairs[I].JsonValue.Value);
    end;
  finally
    FreeAndNil(oJSON);
  end;
end;

function THeaders.FindValue(sKey: String): Boolean;
begin
  Result := False;
  for var Item in FHeaders do
    if Item.Name = sKey then
      Exit(True);
end;

function THeaders.GetStr(sKey: String): String;
begin
  Result := EmptyStr;
  for var Item in FHeaders do
    if Item.Name = sKey then
      Exit(Item.Value);
end;

function THeaders.Clear: TRESTAPI;
begin
  Result := FAPI;
  Finalize(FHeaders);
  FHeaders := [TNameValuePair.Create('Content-Type', 'application/json')];
end;

{ TQuery }

constructor TQuery.Create(API: TRESTAPI);
begin
  FAPI := API;
  FQuery := [];
end;

procedure TQuery.InternalAdd(sKey: String; sValue: String);
var
  I: Integer;
begin
  for I := 0 to Pred(Length(FQuery)) do
  begin
    if FQuery[I].Key = sKey then
    begin
      FQuery[I].Value := sValue;
      Exit;
    end;
  end;
  SetLength(FQuery, Succ(Length(FQuery)));
  FQuery[Pred(Length(FQuery))] := TPair<String, String>.Create(sKey, sValue);
end;

function TQuery.Value(oJSON: TJSONObject): TRESTAPI;
var
  I: Integer;
  sName: String;
  sValue: String;
  J: Integer;
begin
  Result := FAPI;
  try
    for I := 0 to Pred(oJSON.Count) do
    begin
      sName := EmptyStr;
      sValue := EmptyStr;
      if oJSON.Pairs[I].JsonValue.InheritsFrom(TJSONArray) then
      begin
        sName := oJSON.Pairs[I].JsonString.Value +'[]=';
        for J := 0 to Pred(TJSONArray(oJSON.Pairs[I].JsonValue).Count) do
          sValue := sValue + IfThen(not sValue.Trim.IsEmpty, '&'+sName ) + TJSONArray(oJSON.Pairs[I].JsonValue)[J].Value;
      end
      else
      begin
        sName := oJSON.Pairs[I].JsonString.Value;
        sValue := oJSON.Pairs[I].JsonValue.Value;
      end;
      InternalAdd(sName, sValue);
    end;
  finally
    FreeAndNil(oJSON);
  end;
end;

function TQuery.ToString: String;
var
  I: Integer;
  sAux: String;
begin
  for I := 0 to Pred(Length(FQuery)) do
  begin
    if String(FQuery[I].Key).Contains('[]') then
      sAux := FQuery[I].Key + FQuery[I].Value
    else
      sAux := FQuery[I].Key +'='+ FQuery[I].Value;

    if Result.IsEmpty then
      Result := sAux
    else
      Result := Result +'&'+ sAux;
  end;

  if not Result.IsEmpty then
    Result := '?'+ Result;
end;

function TQuery.Clear: TRESTAPI;
begin
  Result := FAPI;
  FQuery := [];
end;

{ TParams }

function TParams.ToString: String;
var
  I: Integer;
begin
  Result := EmptyStr;
  for I := 0 to Pred(Length(FQuery)) do
    Result := Result +'/'+ FQuery[I].Value;
end;

{ TAuthBasic }

class function TAuthBasic.New(const User: String; const Pass: String = ''): IAuth;
begin
  Result := TAuthBasic.Create;
  TAuthBasic(Result).FToken := TNetEncoding.Base64String.Encode(User +':'+ Pass);
end;

function TAuthBasic.Get: String;
begin
  Result := 'Basic '+ FToken;
end;

{ TAuthBearer }

class function TAuthBearer.New(const Token: String): IAuth;
begin
  Result := TAuthBearer.Create;
  TAuthBearer(Result).FToken := Token;
end;

class function TAuthBearer.New(const Method: TFunc<String>): IAuth;
begin
  Result := TAuthBearer.Create;
  TAuthBearer(Result).FMethod := Method;
end;

function TAuthBearer.Get: String;
begin
  if not FToken.IsEmpty then
    Exit('Bearer '+ FToken)
  else
  if not Assigned(FMethod) then
    raise Exception.Create('Metodo de obtenção do token não informado!')
  else
    Result := 'Bearer '+ FMethod;
end;

{$WARN GARBAGE OFF}

end.
(*----------------------------------------------------------------------------------------------------------------------
[Daniel Araujo - 29/09/2021 - ISSUE:593]
  - Adiciona controle de método para uso geral e em RESTAPIThread
  - Refatoração do método InternalExecute
------------------------------------------------------------------------------------------------------------------------
[Eduardo - 15/11/2021]
Adiciona suporte a chamada de métodos com parâmetro na URL
------------------------------------------------------------------------------------------------------------------------
[Eduardo - 27/12/2021]
Adiciona classes e metodos para facilitar autenticação
------------------------------------------------------------------------------------------------------------------------
[Eduardo - 08/08/2023]
TICK:76652 - Melhoria na autenticação por Bearer e adiciona suporte a MultiPartFormData
----------------------------------------------------------------------------------------------------------------------*)
