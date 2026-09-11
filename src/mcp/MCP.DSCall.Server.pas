// Raul Pavanelli/Claude - 10/09/2026
// Servidor MCP: loop de mensagens, JSON-RPC 2.0 e dispatch para o registro
// de tools.
//
// Nao conhece DataSnap nem nenhuma tool concreta — recebe transporte e registro
// prontos (DIP). Acrescentar uma tool nao toca em nada aqui.
unit MCP.DSCall.Server;

interface

uses
  System.JSON,
  MCP.DSCall.Registro,
  MCP.DSCall.Transporte;

type
  TMCPServer = class
  private
    FTransporte : IMCPTransporte;
    FRegistro   : TMCPRegistroTools;
    FNome       : String;
    FTitulo     : String;
    FVersao     : String;
    FEncerrar   : Boolean;

    function ClonarId(const AId: TJSONValue): TJSONValue;

    function Resultado (const AId: TJSONValue; const APayload: TJSONValue): TJSONObject;
    function Erro      (const AId: TJSONValue; const ACodigo: Integer; const AMensagem: String): TJSONObject;
    function TextoTool (const AId: TJSONValue; const ATexto: String): TJSONObject;
    function ErroTool  (const AId: TJSONValue; const AMensagem: String): TJSONObject;

    function Inicializar(const AId: TJSONValue): TJSONObject;
    function ListarTools(const AId: TJSONValue): TJSONObject;
    function ChamarTool (const AId: TJSONValue; const AParams: TJSONObject): TJSONObject;
    function Despachar  (const ARequisicao: TJSONObject): TJSONObject;
    // Envolve o dispatch: uma excecao nao tratada aqui derrubaria o loop e o
    // cliente ficaria esperando para sempre.
    function DespacharSeguro(const ARequisicao: TJSONObject): TJSONObject;

    procedure ValidarRegistro;
  public
    constructor Create(const ATransporte: IMCPTransporte; const ARegistro: TMCPRegistroTools;
                       const ANome, ATitulo, AVersao: String);
    procedure Executar;
  end;

const
  PROTOCOL_VERSION = '2024-11-05';

implementation

uses
  System.SysUtils,
  MCP.DSCall.Protocolo;

{ TMCPServer }

constructor TMCPServer.Create(const ATransporte: IMCPTransporte; const ARegistro: TMCPRegistroTools;
  const ANome, ATitulo, AVersao: String);
begin
  inherited Create;
  FTransporte := ATransporte;
  FRegistro   := ARegistro;
  FNome       := ANome;
  FTitulo     := ATitulo;
  FVersao     := AVersao;
  FEncerrar   := False;
end;

function TMCPServer.ClonarId(const AId: TJSONValue): TJSONValue;
begin
  if AId = nil then
    Result := TJSONNull.Create
  else
    Result := AId.Clone as TJSONValue;
end;

function TMCPServer.Resultado(const AId: TJSONValue; const APayload: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  Result.AddPair('id', ClonarId(AId));
  Result.AddPair('result', APayload);
end;

function TMCPServer.Erro(const AId: TJSONValue; const ACodigo: Integer; const AMensagem: String): TJSONObject;
var
  Detalhe: TJSONObject;
begin
  Detalhe := TJSONObject.Create;
  Detalhe.AddPair('code',    TJSONNumber.Create(ACodigo));
  Detalhe.AddPair('message', AMensagem);

  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  Result.AddPair('id', ClonarId(AId));
  Result.AddPair('error', Detalhe);
end;

function TMCPServer.TextoTool(const AId: TJSONValue; const ATexto: String): TJSONObject;
var
  Payload : TJSONObject;
  Conteudo: TJSONArray;
  Item    : TJSONObject;
begin
  Item := TJSONObject.Create;
  Item.AddPair('type', 'text');
  Item.AddPair('text', ATexto);

  Conteudo := TJSONArray.Create;
  Conteudo.AddElement(Item);

  Payload := TJSONObject.Create;
  Payload.AddPair('content', Conteudo);

  Result := Resultado(AId, Payload);
end;

function TMCPServer.ErroTool(const AId: TJSONValue; const AMensagem: String): TJSONObject;
var
  Payload : TJSONObject;
  Conteudo: TJSONArray;
  Item    : TJSONObject;
begin
  Item := TJSONObject.Create;
  Item.AddPair('type', 'text');
  Item.AddPair('text', AMensagem);

  Conteudo := TJSONArray.Create;
  Conteudo.AddElement(Item);

  Payload := TJSONObject.Create;
  Payload.AddPair('content', Conteudo);
  Payload.AddPair('isError', TJSONBool.Create(True));

  Result := Resultado(AId, Payload);
end;

function TMCPServer.Inicializar(const AId: TJSONValue): TJSONObject;
var
  Payload      : TJSONObject;
  Capacidades  : TJSONObject;
  InfoServidor : TJSONObject;
begin
  Capacidades := TJSONObject.Create;
  Capacidades.AddPair('tools', TJSONObject.Create);

  InfoServidor := TJSONObject.Create;
  InfoServidor.AddPair('name',    FNome);
  InfoServidor.AddPair('title',   FTitulo);
  InfoServidor.AddPair('version', FVersao);

  Payload := TJSONObject.Create;
  Payload.AddPair('protocolVersion', PROTOCOL_VERSION);
  Payload.AddPair('capabilities',    Capacidades);
  Payload.AddPair('serverInfo',      InfoServidor);

  Result := Resultado(AId, Payload);
end;

function TMCPServer.ListarTools(const AId: TJSONValue): TJSONObject;
begin
  Result := Resultado(AId, FRegistro.ListaJSON);
end;

function TMCPServer.ChamarTool(const AId: TJSONValue; const AParams: TJSONObject): TJSONObject;
var
  sNome     : String;
  Tool      : IMCPTool;
  Argumentos: TJSONValue;
  Args      : TJSONObject;
begin
  if AParams = nil then
    Exit(Erro(AId, -32602, 'Missing params'));

  sNome := AParams.GetValue<String>('name', '');
  if sNome = '' then
    Exit(Erro(AId, -32602, 'Missing tool name'));

  if not FRegistro.Localizar(sNome, Tool) then
    Exit(Erro(AId, -32602, 'Unknown tool: ' + sNome));

  // "arguments" e opcional: tools sem parametro obrigatorio podem vir sem ele.
  Argumentos := AParams.GetValue('arguments');

  if Argumentos is TJSONObject then
    Args := TJSONObject(Argumentos)
  else
    Args := nil;

  try
    Result := TextoTool(AId, Tool.Executar(Args));
  except
    on E: Exception do
      Result := ErroTool(AId, E.ClassName + ': ' + E.Message);
  end;
end;

function TMCPServer.Despachar(const ARequisicao: TJSONObject): TJSONObject;
var
  sMetodo   : String;
  Id        : TJSONValue;
  ValParams : TJSONValue;
  Params    : TJSONObject;
begin
  sMetodo   := ARequisicao.GetValue<String>('method', '');
  Id        := ARequisicao.GetValue('id');
  ValParams := ARequisicao.GetValue('params');

  if ValParams is TJSONObject then
    Params := TJSONObject(ValParams)
  else
    Params := nil;

  // Notificacoes (sem id) nao respondem.
  if Id = nil then
    Exit(nil);

  if sMetodo = 'initialize' then Exit(Inicializar(Id));
  if sMetodo = 'tools/list' then Exit(ListarTools(Id));
  if sMetodo = 'tools/call' then Exit(ChamarTool(Id, Params));
  if sMetodo = 'ping'       then Exit(Resultado(Id, TJSONObject.Create));

  Result := Erro(Id, -32601, 'Method not found: ' + sMetodo);
end;

function TMCPServer.DespacharSeguro(const ARequisicao: TJSONObject): TJSONObject;
begin
  try
    Result := Despachar(ARequisicao);
  except
    on E: Exception do
    begin
      FTransporte.Log('Erro de dispatch: ' + E.ClassName + ': ' + E.Message);
      Result := Erro(ARequisicao.GetValue('id'), -32603, 'Internal error: ' + E.Message);
    end;
  end;
end;

procedure TMCPServer.ValidarRegistro;
var
  Lista: TJSONObject;
begin
  // Sem tool nenhuma o MCP sobe e o cliente simplesmente nao ve nada — falha
  // silenciosa que ja aconteceu por outro motivo. Avisar sempre.
  if FRegistro.Contagem = 0 then
  begin
    FTransporte.Log('ATENCAO: nenhuma tool registrada — o cliente nao vera nada.');
    Exit;
  end;

  // Exercita a montagem do schema no startup: um defeito em qualquer schema
  // aparece agora, no log, e nao na primeira chamada de tools/list.
  Lista := FRegistro.ListaJSON;
  try
    FTransporte.Log(Format('%d tools registradas', [FRegistro.Contagem]));
  finally
    Lista.Free;
  end;
end;

procedure TMCPServer.Executar;
var
  sLinha      : String;
  bEof        : Boolean;
  Analisado   : TJSONValue;
  Requisicao  : TJSONObject;
  Resposta    : TJSONObject;
begin
  FTransporte.Log('MCP server iniciado (protocolo ' + PROTOCOL_VERSION + ')');
  ValidarRegistro;

  while not FEncerrar do
  begin
    sLinha := FTransporte.LerLinha(bEof);

    if bEof then
      Break;

    if sLinha = '' then
      Continue;

    try
      Analisado := TJSONObject.ParseJSONValue(sLinha);
    except
      on E: Exception do
      begin
        FTransporte.Log('Erro de parse JSON: ' + E.Message);
        Continue;
      end;
    end;

    if not (Analisado is TJSONObject) then
    begin
      Analisado.Free;
      FTransporte.Log('Mensagem JSON ignorada (nao e objeto)');
      Continue;
    end;

    Requisicao := TJSONObject(Analisado);
    try
      Resposta := DespacharSeguro(Requisicao);

      if Resposta <> nil then
      try
        FTransporte.EscreverLinha(Resposta.ToJSON);
      finally
        Resposta.Free;
      end;
    finally
      Requisicao.Free;
    end;
  end;

  FTransporte.Log('MCP server encerrando');
end;

end.
