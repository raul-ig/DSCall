// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_catalog_delete — remove uma rota do catalogo.
unit MCP.DSCall.Tool.CatalogDelete;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest.Catalogo;

type
  TToolCatalogDelete = class(TMCPToolBase)
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
  System.SysUtils;

{ TToolCatalogDelete }

constructor TToolCatalogDelete.Create(const ACatalogo: ICatalogoRotas);
begin
  inherited Create;
  FCatalogo := ACatalogo;
end;

function TToolCatalogDelete.Nome: String;
begin
  Result := 'rest_catalog_delete';
end;

function TToolCatalogDelete.Descricao: String;
begin
  Result :=
    'Remove uma rota do catalogo. Apaga APENAS o arquivo da rota — a pasta do no continua, porque ' +
    'pode conter outras rotas. ' +
    'Use somente quando a rota deixou de existir na API ou foi cadastrada errada. ' +
    'Para corrigir uma definicao, NAO apague: grave por cima com rest_catalog_set. ' +
    'Nao remova rota por iniciativa propria — peca confirmacao ao usuario antes, ' +
    'porque o catalogo e conhecimento acumulado e nao ha como desfazer.';
end;

function TToolCatalogDelete.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('api', 'Nome da API (ex MD030).', True)
    .Texto('rota', 'Caminho da rota, com barras (ex "pedido/listar").', True)
    .Build;
end;

function TToolCatalogDelete.Executar(const AArgs: TJSONObject): String;
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

  Result := FCatalogo.Remover(sApi, sRota);
end;

end.
