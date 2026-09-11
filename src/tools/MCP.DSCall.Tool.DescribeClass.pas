// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_describe_class — metodos publicados de uma classe.
unit MCP.DSCall.Tool.DescribeClass;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Introspec;

type
  TToolDescribeClass = class(TMCPToolBase)
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

{ TToolDescribeClass }

constructor TToolDescribeClass.Create(const AIntrospec: IDSIntrospec);
begin
  inherited Create;
  FIntrospec := AIntrospec;
end;

function TToolDescribeClass.Nome: String;
begin
  Result := 'ds_describe_class';
end;

function TToolDescribeClass.Descricao: String;
begin
  Result :=
    'Metodos publicados de uma classe, com o LifeCycle no titulo. ' +
    'Por padrao omite os herdados de TServerModuleBase (AS_*, SetSQL, GetLastIG_RECNO etc.), que existem em ' +
    'todas as classes; passe all=true para ver todos. Metodos private NAO sao publicados pelo DataSnap. ' +
    'Use apos um build para confirmar que o metodo novo subiu.' +
    WORKFLOW;
end;

function TToolDescribeClass.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('class', 'Nome da classe, ex TSM0977A.', True)
    .Texto('server', ARG_SERVER)
    .Booleano('all', 'true inclui os metodos herdados de TServerModuleBase. Default false.')
    .Build;
end;

function TToolDescribeClass.Executar(const AArgs: TJSONObject): String;
var
  sClasse: String;
begin
  sClasse := ArgTexto(AArgs, 'class');

  if sClasse.Trim = '' then
    Exit('ERRO: parametro "class" e obrigatorio.');

  Result := FIntrospec.DescreverClasse(ArgServidor(AArgs), sClasse, ArgBooleano(AArgs, 'all'));
end;

end.
