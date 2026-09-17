// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_call — executa uma rota de API REST.
unit MCP.DSCall.Tool.RestCall;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest;

type
  TToolRestCall = class(TMCPToolBase)
  private
    FRest: IRestClient;
    function ArgValor(const AArgs: TJSONObject; const ANome: String): TJSONValue;
  public
    constructor Create(const ARest: IRestClient);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  System.SysUtils,
  MCP.DSCall.Convencoes;

{ TToolRestCall }

constructor TToolRestCall.Create(const ARest: IRestClient);
begin
  inherited Create;
  FRest := ARest;
end;

function TToolRestCall.Nome: String;
begin
  Result := 'rest_call';
end;

function TToolRestCall.Descricao: String;
begin
  Result :=
    'EXECUTA uma rota de API REST cadastrada em "apis" no MCP.DSCall.json. ' +
    'A rota e o caminho depois da base_url: para http://127.0.0.1:8030/TSM0747A/InserirPreLancamentos ' +
    'com base_url http://127.0.0.1:8030/, a rota e "TSM0747A/InserirPreLancamentos". ' +
    'A autenticacao (basic/bearer/jwt) e aplicada automaticamente conforme o config — nao monte header ' +
    'Authorization a mao. ' +
    'ANTES DE CHAMAR: consulte rest_catalog_get para saber o verbo, os parametros e principalmente o ' +
    'EFEITO da rota. Se ela nao estiver catalogada, confirme com o usuario o que ela faz e cadastre com ' +
    'rest_catalog_set — depois de chamar com sucesso, volte la e marque status "validado". ' +
    'Retorno: verbo e URL na 1a linha, codigo HTTP na 2a, e o corpo cru da resposta apos "--- RESPOSTA ---". ' +
    'Recusado quando a API tem allow_write=false, para QUALQUER verbo.' +
    REST_CONFIRMACAO;
end;

function TToolRestCall.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('api', 'Nome da API no MCP.DSCall.json (ex MD030). Use rest_apis para ver as cadastradas.', True)
    .Texto('rota', 'Caminho apos a base_url, sem barra inicial (ex "TSM0747A/InserirPreLancamentos").', True)
    .Texto('verbo', 'GET, POST, PUT ou DELETE. Default GET. Confira no catalogo antes de supor.')
    .Objeto('query', 'Parametros de query string, por nome (ex {"codemp":"MTZ"}).')
    .Objeto('body', 'Corpo JSON da requisicao, para POST/PUT.')
    .Objeto('headers', 'Headers adicionais. NAO inclua Authorization: e montado pelo config.')
    .Build;
end;

function TToolRestCall.ArgValor(const AArgs: TJSONObject; const ANome: String): TJSONValue;
begin
  Result := nil;

  if AArgs = nil then
    Exit;

  Result := AArgs.GetValue(ANome);
end;

function TToolRestCall.Executar(const AArgs: TJSONObject): String;
var
  sApi  : String;
  sRota : String;
begin
  sApi  := ArgTexto(AArgs, 'api');
  sRota := ArgTexto(AArgs, 'rota');

  if sApi.Trim = '' then
    Exit('ERRO: parametro "api" e obrigatorio. Use rest_apis para ver as cadastradas.');

  if sRota.Trim = '' then
    Exit('ERRO: parametro "rota" e obrigatorio.');

  Result := FRest.Chamar(
    sApi,
    sRota,
    ArgTexto(AArgs, 'verbo'),
    ArgObjeto(AArgs, 'query'),
    ArgObjeto(AArgs, 'headers'),
    ArgValor(AArgs, 'body'));
end;

end.
