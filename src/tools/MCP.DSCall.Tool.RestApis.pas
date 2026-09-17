// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_apis — APIs REST cadastradas e teste de conexao com cada uma.
unit MCP.DSCall.Tool.RestApis;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest;

type
  TToolRestApis = class(TMCPToolBase)
  private
    FRest: IRestClient;
  public
    constructor Create(const ARest: IRestClient);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  MCP.DSCall.Convencoes;

{ TToolRestApis }

constructor TToolRestApis.Create(const ARest: IRestClient);
begin
  inherited Create;
  FRest := ARest;
end;

function TToolRestApis.Nome: String;
begin
  Result := 'rest_apis';
end;

function TToolRestApis.Descricao: String;
begin
  Result :=
    'Lista as APIs REST cadastradas no MCP.DSCall.json e testa a conexao com cada uma. ' +
    'Colunas: NOME, BASE_URL, AUTH (none/basic/bearer/jwt-hs256), CRED (se a credencial esta ' +
    'preenchida — o valor em si nunca e exibido), AMBIENTE, ESCRITA (allow_write), STATUS, DESCRICAO. ' +
    'STATUS traz o codigo HTTP da resposta: 401 ou 404 significam que o servidor RESPONDEU (esta no ar), ' +
    'nao que falhou; so "offline" indica que nao foi possivel alcancar. ' +
    'O array "apis" do config e a allowlist — nenhuma URL fora dele e alcancavel. ' +
    'Use ANTES de qualquer chamada REST para confirmar o alvo e o ambiente.' +
    FORMATO_RESPOSTA;
end;

function TToolRestApis.Schema: TJSONObject;
begin
  Result := TSchema.Create.Build;
end;

function TToolRestApis.Executar(const AArgs: TJSONObject): String;
begin
  Result := FRest.Apis;
end;

end.
