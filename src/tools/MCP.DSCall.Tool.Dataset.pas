// Raul Pavanelli/Claude - 16/09/2026
// Tool ds_dataset — abre um provider e devolve as linhas.
unit MCP.DSCall.Tool.Dataset;

interface

uses
  System.JSON,
  MCP.DSCall.Protocolo,
  MCP.DSCall.Dataset;

type
  TToolDataset = class(TMCPToolBase)
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

{ TToolDataset }

constructor TToolDataset.Create(const ADataset: IDSDataset);
begin
  inherited Create;
  FDataset := ADataset;
end;

function TToolDataset.Nome: String;
begin
  Result := 'ds_dataset';
end;

function TToolDataset.Descricao: String;
begin
  Result :=
    'Abre um DataSetProvider do server module e devolve as linhas — e como se ve as LISTAGENS que a ' +
    'tela Delphi mostra, sem abrir a tela. Descubra o nome do provider com ds_providers. ' +
    'Booleano sai como 1/0, datas como yyyy-mm-dd hh:nn:ss, numeros com ponto, blob como [blob N bytes]. ' +
    'A MAIORIA DOS PROVIDERS E PARAMETRIZADA: aberto sem params vem com as COLUNAS e ZERO LINHAS, ' +
    'porque roda com os defaults (0 / vazio) e nao acusa erro. Chame ds_providers ANTES para ver os ' +
    'nomes e tipos dos parametros, e informe-os em params. ' +
    'Use query/search para escolher outra consulta cadastrada no server module. ' +
    'ATENCAO: query NAO e SQL livre — e o NOME de uma query ja cadastrada; passar SQL ali devolve ' +
    '"Query nao encontrada". Como isso altera o estado do server module na sessao, exige allow_write=true.' +
    FORMATO_RESPOSTA;
end;

function TToolDataset.Schema: TJSONObject;
begin
  Result := TSchema.Create
    .Texto('class', 'Nome da classe, ex TSM0977A.', True)
    .Texto('provider', 'Nome do provider, conforme ds_providers.', True)
    .Objeto('params', 'Valores dos parametros do provider, por nome — ex {"C0JL_FKORIG": 11225}. ' +
                      'Os nomes e tipos vem de ds_providers; nome inexistente e recusado com erro.')
    .Inteiro('max', 'Teto de linhas (default 200). Limita tambem o que trafega na rede.')
    .Texto('query', 'Opcional: NOME de uma query cadastrada no server module (2o argumento de SetSQL). ' +
                    'Nao aceita SQL livre.')
    .Texto('search', 'Opcional: criterio de busca (1o argumento de SetSQL).')
    .Texto('server', ARG_SERVER, True)
    .Build;
end;

function TToolDataset.Executar(const AArgs: TJSONObject): String;
var
  sClasse   : String;
  sProvider : String;
begin
  sClasse   := ArgTexto(AArgs, 'class');
  sProvider := ArgTexto(AArgs, 'provider');

  if sClasse.Trim = '' then
    Exit('ERRO: parametro "class" e obrigatorio.');

  if sProvider.Trim = '' then
    Exit('ERRO: parametro "provider" e obrigatorio. Use ds_providers para listar os da classe.');

  Result := FDataset.Abrir(
    ArgServidor(AArgs),
    sClasse,
    sProvider,
    ArgTexto(AArgs, 'query'),
    ArgTexto(AArgs, 'search'),
    ArgObjeto(AArgs, 'params'),
    ArgInteiro(AArgs, 'max'));
end;

end.
