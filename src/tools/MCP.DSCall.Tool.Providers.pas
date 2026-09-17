// Raul Pavanelli/Claude - 16/09/2026
// Tool ds_providers — DataSetProviders publicados por uma classe.
unit MCP.DSCall.Tool.Providers;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Dataset;

type
  TToolProviders = class(TMCPToolBase)
  private
    FDataset: IDSDataset;
  public
    constructor Create(const ADataset: IDSDataset);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  System.SysUtils,
  MCP.DSCall.Convencoes;

{ TToolProviders }

constructor TToolProviders.Create(const ADataset: IDSDataset);
begin
  inherited Create;
  FDataset := ADataset;
end;

function TToolProviders.Nome: String;
begin
  Result := 'ds_providers';
end;

function TToolProviders.Descricao: String;
begin
  Result :=
    'Lista os DataSetProviders publicados por uma classe de server module — as LISTAGENS que a tela ' +
    'Delphi consome via TClientDataSet, e que ds_call nao alcanca (AS_GetRecords trafega pacote Midas binario). ' +
    'Devolve PROVIDER e PARAMETROS (nome:tipo de cada parametro que ele espera). ' +
    'Passe o nome e os parametros para ds_dataset — provider parametrizado aberto sem params devolve ' +
    'ZERO LINHAS silenciosamente, entao consultar aqui antes evita concluir que "nao ha dados". ' +
    'NAO executa nada: so enumera e pergunta a assinatura. ' +
    'Classe sem provider devolve [0 providers] — nesse caso os dados vem por server method, use ds_describe_class.';
end;

function TToolProviders.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('class', 'Nome da classe, ex TSM0977A.', True)
    .Texto('server', ARG_SERVER, True)
    .Build;
end;

function TToolProviders.Executar(const AArgs: TJSONObject): String;
var
  sClasse: String;
begin
  sClasse := ArgTexto(AArgs, 'class');

  if sClasse.Trim = '' then
    Exit('ERRO: parametro "class" e obrigatorio.');

  Result := FDataset.Providers(ArgServidor(AArgs), sClasse);
end;

end.
