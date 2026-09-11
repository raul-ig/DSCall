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
    'E a forma de conferir o SQL que um server method montou. ' +
    'So existe em build DEBUG do servidor — confira a coluna BUILD em ds_servers. ' +
    'Colunas: ID, DATA, TAMANHO, PARAMETROS, SCRIPT.' +
    FORMATO_RESPOSTA;
end;

function TToolSqlLog.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('server', ARG_SERVER)
    .Booleano('limpar', 'true zera o log ANTES de listar — use para isolar o efeito da proxima chamada.')
    .Inteiro('max', 'Quantos scripts mais recentes trazer. Default sql_log_max do config.')
    .Build;
end;

function TToolSqlLog.Executar(const AArgs: TJSONObject): String;
begin
  Result := FInvoke.LogSQL(
    ArgServidor(AArgs),
    ArgBooleano(AArgs, 'limpar'),
    ArgInteiro(AArgs, 'max'));
end;

end.
