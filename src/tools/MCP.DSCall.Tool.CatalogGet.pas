// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_catalog_get — le a definicao completa de uma rota catalogada.
unit MCP.DSCall.Tool.CatalogGet;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest.Catalogo;

type
  TToolCatalogGet = class(TMCPToolBase)
  private
    FCatalogo: ICatalogoRotas;
  public
    constructor Create(const ACatalogo: ICatalogoRotas);

    function Nome: String; override;
    function Descricao: String; override;
    function Schema: TJSONObject; override;
    function Executar(const AArgs: TJSONObject): String; override;
  end;

implementation

uses
  System.SysUtils,
  MCP.DSCall.Convencoes;

{ TToolCatalogGet }

constructor TToolCatalogGet.Create(const ACatalogo: ICatalogoRotas);
begin
  inherited Create;
  FCatalogo := ACatalogo;
end;

function TToolCatalogGet.Nome: String;
begin
  Result := 'rest_catalog_get';
end;

function TToolCatalogGet.Descricao: String;
begin
  Result :=
    'Le a definicao completa de uma rota catalogada: verbo, parametros de query, corpo, resposta, ' +
    'efeito e observacoes. E assim que se descobre COMO chamar a rota sem ler codigo-fonte. ' +
    'Leia SEMPRE antes de executar: o campo "efeito" diz se a rota apenas le, se grava ou se dispara ' +
    'processamento — e o verbo sozinho nao revela isso. ' +
    'O campo "status" diz o quanto confiar: "validado" significa que a rota ja foi chamada com sucesso; ' +
    '"rascunho" significa que a definicao foi inferida e pode estar incompleta.' +
    CATALOGO_FORMATO;
end;

function TToolCatalogGet.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('api', 'Nome da API (ex MD030).', True)
    .Texto('rota', 'Caminho da rota, com barras (ex "pedido/listar").', True)
    .Build;
end;

function TToolCatalogGet.Executar(const AArgs: TJSONObject): String;
var
  sApi  : String;
  sRota : String;
begin
  sApi  := ArgTexto(AArgs, 'api');
  sRota := ArgTexto(AArgs, 'rota');

  if sApi.Trim = '' then
    Exit('ERRO: parametro "api" e obrigatorio.');

  if sRota.Trim = '' then
    Exit('ERRO: parametro "rota" e obrigatorio.');

  Result := FCatalogo.Ler(sApi, sRota);
end;

end.
