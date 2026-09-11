// Raul Pavanelli/Claude - 10/09/2026
// Tool ds_classes — classes de server method publicadas no servidor.
unit MCP.DSCall.Tool.Classes;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Introspec;

type
  TToolClasses = class(TMCPToolBase)
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

{ TToolClasses }

constructor TToolClasses.Create(const AIntrospec: IDSIntrospec);
begin
  inherited Create;
  FIntrospec := AIntrospec;
end;

function TToolClasses.Nome: String;
begin
  Result := 'ds_classes';
end;

function TToolClasses.Descricao: String;
begin
  Result :=
    'Lista as classes de server method publicadas no servidor (uma por linha). ' +
    'Sao centenas — use filter para restringir por substring (ex "0977" acha TSM0977A).' +
    FORMATO_RESPOSTA;
end;

function TToolClasses.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('server', ARG_SERVER)
    .Texto('filter', 'Substring case-insensitive para filtrar os nomes de classe.')
    .Build;
end;

function TToolClasses.Executar(const AArgs: TJSONObject): String;
begin
  Result := FIntrospec.ListarClasses(ArgServidor(AArgs), ArgTexto(AArgs, 'filter'));
end;

end.
