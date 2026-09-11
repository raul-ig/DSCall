// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_call — invoca um server method. E a unica tool que altera estado.
unit MCP.DSCall.Tool.Call;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Invoke;

type
  TToolCall = class(TMCPToolBase)
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
  System.SysUtils,
  MCP.DSCall.Convencoes;

{ TToolCall }

constructor TToolCall.Create(const AInvoke: IDSInvoke);
begin
  inherited Create;
  FInvoke := AInvoke;
end;

function TToolCall.Nome: String;
begin
  Result := 'ds_call';
end;

function TToolCall.Descricao: String;
begin
  Result :=
    'INVOCA um server method no servidor — executa codigo de negocio real com a sessao ADMIN, ' +
    'podendo GRAVAR no banco. Parametros por params (posicional, na ordem da assinatura) ou named (por nome); ' +
    'named tem precedencia. A aridade e conferida antes de executar. ' +
    'Retorno: NOME|TIPO|VALOR por parametro de saida. ' +
    'Recusado quando o servidor tem allow_write=false.' +
    WORKFLOW;
end;

function TToolCall.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('method', 'Metodo no formato TClasse.Metodo.', True)
    .ListaTexto('params', 'Parametros de entrada na ordem da assinatura. Numeros e booleanos podem vir como string.')
    .Objeto('named', 'Parametros por nome, conforme ds_describe_method. Tem precedencia sobre params.')
    .Booleano('com_sql', 'true limpa o log do servidor, executa e devolve os SQLs gerados apos --- SQL ---. ' +
                         'Exige servidor compilado em DEBUG.')
    .Texto('server', ARG_SERVER)
    .Build;
end;

function TToolCall.Executar(const AArgs: TJSONObject): String;
var
  sMetodo: String;
begin
  sMetodo := ArgTexto(AArgs, 'method');

  if sMetodo.Trim = '' then
    Exit('ERRO: parametro "method" e obrigatorio.');

  Result := FInvoke.Chamar(
    ArgServidor(AArgs),
    sMetodo,
    ArgLista(AArgs, 'params'),
    ArgObjeto(AArgs, 'named'),
    ArgBooleano(AArgs, 'com_sql'));
end;

end.
