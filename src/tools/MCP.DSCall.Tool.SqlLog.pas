// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_sql_log — scripts SQL executados recentemente pelo servidor.
unit MCP.DSCall.Tool.SqlLog;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Invoke;

type
  TToolSqlLog = class(TMCPToolBase)
  private
    FInvoke: IDSInvoke;
  public
    constructor Create(const AInvoke: IDSInvoke);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  MCP.DSCall.Convencoes;

{ TToolSqlLog }

constructor TToolSqlLog.Create(const AInvoke: IDSInvoke);
begin
  inherited Create;
  FInvoke := AInvoke;
end;

function TToolSqlLog.Nome: String;
begin
  Result := 'ds_sql_log';
end;

function TToolSqlLog.Descricao: String;
begin
  Result :=
    'Scripts SQL executados recentemente pelo servidor (rota HTTP /log/listar das classes TWeb). ' +
    'O log e GLOBAL do servidor: captura o SQL de TODAS as sessoes, inclusive o da tela do cliente ' +
    'Delphi (MD009) — e por isso a forma de acompanhar o que esta acontecendo sem instrumentar nada. ' +
    'O SCRIPT vem carimbado com a origem no formato /* TClasse USUARIO */. ' +
    'PARA ACOMPANHAR UMA OPERACAO: chame uma vez, anote o ultimo_id do rodape, peca ao usuario para ' +
    'executar a acao na tela, e chame de novo com desde_id=<aquele valor> — voltam so os SQLs novos. ' +
    'So existe em build DEBUG do servidor — confira a coluna BUILD em ds_servers. ' +
    'Colunas: ID, DATA, TAMANHO, PARAMETROS, SCRIPT.' +
    FORMATO_RESPOSTA;
end;

function TToolSqlLog.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('server', ARG_SERVER, True)
    .Booleano('limpar', 'true zera o log ANTES de listar — use para isolar o efeito da proxima chamada.')
    .Inteiro('max', 'Quantos scripts mais recentes trazer, DEPOIS de aplicar filter e desde_id. ' +
                    'Default sql_log_max do config.')
    .Texto('filter', 'Substring case-insensitive; casa em SCRIPT ou PARAMETROS. ' +
                     'Use o nome da tabela (ex T1G0) ou da rotina (ex TSM0977A) para isolar o que interessa.')
    .Inteiro('desde_id', 'So registros com ID MAIOR que este. Passe o ultimo_id devolvido na chamada ' +
                         'anterior para ver apenas o que aconteceu desde entao.')
    .Build;
end;

function TToolSqlLog.Executar(const AArgs: TJSONObject): String;
begin
  Result := FInvoke.LogSQL(
    ArgServidor(AArgs),
    ArgBooleano(AArgs, 'limpar'),
    ArgInteiro(AArgs, 'max'),
    ArgTexto(AArgs, 'filter'),
    ArgInteiro(AArgs, 'desde_id'));
end;

end.
