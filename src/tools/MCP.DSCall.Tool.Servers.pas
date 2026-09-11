// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_servers — servidores cadastrados, status e o banco real de cada um.
unit MCP.DSCall.Tool.Servers;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Introspec;

type
  TToolServers = class(TMCPToolBase)
  private
    FIntrospec: IDSIntrospec;
  public
    constructor Create(const AIntrospec: IDSIntrospec);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  MCP.DSCall.Convencoes;

{ TToolServers }

constructor TToolServers.Create(const AIntrospec: IDSIntrospec);
begin
  inherited Create;
  FIntrospec := AIntrospec;
end;

function TToolServers.Nome: String;
begin
  Result := 'ds_servers';
end;

function TToolServers.Descricao: String;
begin
  Result :=
    'Lista os servidores DataSnap cadastrados e testa a conexao com cada um. ' +
    'Colunas: NOME, HOST, PORTA (TCP/DBX), HTTP (rotas TWeb), AMBIENTE, ESCRITA (allow_write), STATUS, ' +
    'BANCO (o banco REALMENTE atras do servidor, lido de TWeb.GetInfo), VERSAO, ' +
    'BUILD (DEBUG habilita ds_sql_log), DESCRICAO. ' +
    'Use ANTES de qualquer ds_call: a coluna BANCO e a evidencia confiavel do alvo — ' +
    'AMBIENTE e so um rotulo digitado no config.' +
    FORMATO_RESPOSTA;
end;

function TToolServers.Schema: TJSONObject;
begin
  Result := TSchema.Create.Build;
end;

function TToolServers.Executar(const AArgs: TJSONObject): String;
begin
  Result := FIntrospec.Servidores;
end;

end.
