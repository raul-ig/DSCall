// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_describe_method — assinatura real de um server method.
unit MCP.DSCall.Tool.DescribeMethod;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Introspec;

type
  TToolDescribeMethod = class(TMCPToolBase)
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
  System.SysUtils,
  MCP.DSCall.Convencoes;

{ TToolDescribeMethod }

constructor TToolDescribeMethod.Create(const AIntrospec: IDSIntrospec);
begin
  inherited Create;
  FIntrospec := AIntrospec;
end;

function TToolDescribeMethod.Nome: String;
begin
  Result := 'ds_describe_method';
end;

function TToolDescribeMethod.Descricao: String;
begin
  Result :=
    'Assinatura real de um server method, obtida do proprio servidor: NOME|TIPO|DIRECAO por parametro. ' +
    'Direcao in = entrada; ret = ReturnParameter (retorno de function; procedure nao tem). ' +
    'Tipos possiveis: Int32, Int64, WideString, AnsiString, Boolean, Double, Bcd, JsonValue. ' +
    'NAO executa nada — seguro em qualquer servidor, inclusive os de allow_write=false. ' +
    'Chame antes de ds_call para acertar ordem e tipos dos parametros.';
end;

function TToolDescribeMethod.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('method', 'Metodo no formato TClasse.Metodo, ex TSM0977A.RotasAtivasDoCAR.', True)
    .Texto('server', ARG_SERVER, True)
    .Build;
end;

function TToolDescribeMethod.Executar(const AArgs: TJSONObject): String;
var
  sMetodo: String;
begin
  sMetodo := ArgTexto(AArgs, 'method');

  if sMetodo.Trim = '' then
    Exit('ERRO: parametro "method" e obrigatorio.');

  Result := FIntrospec.DescreverMetodo(ArgServidor(AArgs), sMetodo);
end;

end.
