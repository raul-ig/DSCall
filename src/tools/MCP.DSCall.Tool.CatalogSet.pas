// Raul Pavanelli/Claude - 17/09/2026
// Tool rest_catalog_set — cadastra ou atualiza uma rota no catalogo.
unit MCP.DSCall.Tool.CatalogSet;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Rest.Catalogo;

type
  TToolCatalogSet = class(TMCPToolBase)
  private
    FCatalogo: ICatalogoRotas;
    function Validar(const ADados: TJSONObject): String;
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
  System.DateUtils,
  MCP.DSCall.Convencoes;

{ TToolCatalogSet }

constructor TToolCatalogSet.Create(const ACatalogo: ICatalogoRotas);
begin
  inherited Create;
  FCatalogo := ACatalogo;
end;

function TToolCatalogSet.Nome: String;
begin
  Result := 'rest_catalog_set';
end;

function TToolCatalogSet.Descricao: String;
begin
  Result :=
    'Cadastra ou atualiza uma rota no catalogo — e assim que o conhecimento sobre a API fica GUARDADO ' +
    'em vez de se perder no fim da conversa. Substitui o arquivo inteiro da rota: para editar um campo, ' +
    'leia antes com rest_catalog_get, altere o objeto e grave de volta completo. ' +
    'O caminho vira pastas: "pedido/item/listar" cria os nos "pedido" e "item" e a rota "listar". ' +
    'QUANDO USAR: sempre que descobrir como uma rota funciona — com o usuario, testando, ou lendo ' +
    'documentacao que ele forneca. Depois de chamar a rota com sucesso, volte aqui e mude o status ' +
    'para "validado". Registrar o que surpreendeu em "observacoes" vale mais que a descricao formal.' +
    CATALOGO_FORMATO;
end;

function TToolCatalogSet.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('api', 'Nome da API (ex MD030).', True)
    .Texto('rota', 'Caminho da rota, com barras (ex "pedido/listar"). Cada segmento vira um no.', True)
    .Objeto('dados', 'Objeto JSON com a definicao da rota — ver FORMATO DA ROTA na descricao.', True)
    .Build;
end;

function TToolCatalogSet.Validar(const ADados: TJSONObject): String;
const
  VERBOS  : array[0..3] of String = ('GET', 'POST', 'PUT', 'DELETE');
  EFEITOS : array[0..2] of String = ('leitura', 'escrita', 'processamento');
var
  sVerbo  : String;
  sEfeito : String;
  sItem   : String;
  bAchou  : Boolean;
begin
  Result := '';

  sVerbo  := ADados.GetValue<String>('verbo', '').Trim.ToUpper;
  sEfeito := ADados.GetValue<String>('efeito', '').Trim.ToLower;

  if sVerbo = '' then
    Exit('ERRO: informe "verbo" nos dados da rota (GET, POST, PUT ou DELETE).');

  bAchou := False;
  for sItem in VERBOS do
    if sItem = sVerbo then
      bAchou := True;

  if not bAchou then
    Exit(Format('ERRO: verbo "%s" invalido. Use GET, POST, PUT ou DELETE.', [sVerbo]));

  // Efeito e obrigatorio de proposito: e o campo que impede alguem de tratar
  // como leitura uma rota GET que na verdade processa.
  if sEfeito = '' then
    Exit('ERRO: informe "efeito" nos dados da rota: leitura, escrita ou processamento. ' +
         'Nao deduza do verbo — ha rotas GET que processam.');

  bAchou := False;
  for sItem in EFEITOS do
    if sItem = sEfeito then
      bAchou := True;

  if not bAchou then
    Exit(Format('ERRO: efeito "%s" invalido. Use leitura, escrita ou processamento.', [sEfeito]));
end;

function TToolCatalogSet.Executar(const AArgs: TJSONObject): String;
var
  sApi   : String;
  sRota  : String;
  Dados  : TJSONObject;
  sErro  : String;
begin
  sApi  := ArgTexto(AArgs, 'api');
  sRota := ArgTexto(AArgs, 'rota');
  Dados := ArgObjeto(AArgs, 'dados');

  if sApi.Trim = '' then
    Exit('ERRO: parametro "api" e obrigatorio.');

  if sRota.Trim = '' then
    Exit('ERRO: parametro "rota" e obrigatorio.');

  if Dados = nil then
    Exit('ERRO: parametro "dados" e obrigatorio e deve ser um objeto JSON.');

  sErro := Validar(Dados);
  if sErro <> '' then
    Exit(sErro);

  // Carimbo de atualizacao: sem ele nao da para saber se a definicao e recente
  // ou de meses atras. Sobrescreve o que vier, para nao confiar em data dada.
  Dados.RemovePair('atualizado_em').Free;
  Dados.AddPair('atualizado_em', FormatDateTime('yyyy-mm-dd', Now));

  Result := FCatalogo.Gravar(sApi, sRota, Dados);
end;

end.
