// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_catalog_list — navega a arvore do catalogo de rotas.
unit MCP.DSCall.Tool.CatalogList;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest.Catalogo;

type
  TToolCatalogList = class(TMCPToolBase)
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

{ TToolCatalogList }

constructor TToolCatalogList.Create(const ACatalogo: ICatalogoRotas);
begin
  inherited Create;
  FCatalogo := ACatalogo;
end;

function TToolCatalogList.Nome: String;
begin
  Result := 'rest_catalog_list';
end;

function TToolCatalogList.Descricao: String;
begin
  Result :=
    'Navega o catalogo de rotas REST, um nivel por vez. Devolve TIPO (no ou rota) e NOME. ' +
    'Sem "api", lista as APIs catalogadas. Com "api" e sem "no", lista a raiz daquela API. ' +
    'Com "no", lista o que ha dentro dele — "no" aceita caminho com barras (ex "pedido/item"). ' +
    'O catalogo e organizado EM CAMADAS: cada no e uma pasta e cada rota e um arquivo, entao a ' +
    'arvore espelha o caminho real da rota. ' +
    'COMECE POR AQUI antes de qualquer chamada REST: e como se descobre o que ja se sabe sobre a API, ' +
    'sem precisar ler codigo-fonte. ' +
    'O catalogo comeca VAZIO e cresce com o uso: se a rota que voce procura nao esta aqui, ' +
    'descubra-a com o usuario e cadastre com rest_catalog_set.';
end;

function TToolCatalogList.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('api', 'Nome da API (ex MD030). Omitido: lista as APIs catalogadas.')
    .Texto('no', 'Caminho do no a abrir, com barras (ex "pedido" ou "pedido/item"). Omitido: raiz da API.')
    .Build;
end;

function TToolCatalogList.Executar(const AArgs: TJSONObject): String;
begin
  Result := FCatalogo.Listar(ArgTexto(AArgs, 'api'), ArgTexto(AArgs, 'no'));
end;

end.
