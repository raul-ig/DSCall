// Raul Pavanelli/Claude - 10/09/2026
// Contratos da camada MCP. Esta unit NAO conhece DataSnap: e a fronteira que
// permite acrescentar uma tool sem tocar no servidor (OCP) e testar o servidor
// sem subir um servidor DataSnap (DIP).
//
// O TSchema existe por um motivo concreto: a versao anterior montava o
// inputSchema concatenando string JSON na mao e dois escapes invalidos
// (uma barra de caminho e um \\" ) derrubaram o tools/list INTEIRO — o cliente
// nao via tool nenhuma e o erro so aparecia em runtime. Montando TJSONObject
// de verdade, esse tipo de defeito deixa de ser possivel.
unit MCP.DSCall.Protocolo;

interface

uses
  System.JSON;

type
  IMCPTool = interface
    ['{7C4A1E62-3D51-4B08-9E77-1F2A6C8D5B30}']
    function Nome: String;
    function Descricao: String;
    // inputSchema da tool. O chamador assume a posse do objeto devolvido.
    function Schema: TJSONObject;
    // Executa e devolve o texto ja formatado para o cliente. Erros de negocio
    // voltam como "ERRO: ..." no proprio texto; excecoes sobem para o servidor.
    function Executar(const AArgs: TJSONObject): String;
  end;

  // Construtor fluente de inputSchema.
  TSchema = class
  private
    FPropriedades : TJSONObject;
    FObrigatorios : TJSONArray;
    function Propriedade(const ANome, ATipo, ADescricao: String; const AObrigatorio: Boolean): TSchema;
  public
    constructor Create;
    destructor  Destroy; override;

    function Texto     (const ANome, ADescricao: String; const AObrigatorio: Boolean = False): TSchema;
    function Booleano  (const ANome, ADescricao: String): TSchema;
    function Inteiro   (const ANome, ADescricao: String): TSchema;
    function Objeto    (const ANome, ADescricao: String): TSchema;
    function ListaTexto(const ANome, ADescricao: String): TSchema;

    // Monta o objeto final e o entrega ao chamador; a instancia se autolibera.
    function Build: TJSONObject;
  end;

  // Base das tools: concentra a leitura defensiva de argumentos, que antes
  // estava repetida (e divergente) em cada ramo do dispatch.
  TMCPToolBase = class(TInterfacedObject, IMCPTool)
  protected
    function ArgTexto   (const AArgs: TJSONObject; const ANome: String; const APadrao: String = ''): String;
    function ArgBooleano(const AArgs: TJSONObject; const ANome: String; const APadrao: Boolean = False): Boolean;
    function ArgInteiro (const AArgs: TJSONObject; const ANome: String; const APadrao: Integer = 0): Integer;
    function ArgObjeto  (const AArgs: TJSONObject; const ANome: String): TJSONObject;
    function ArgLista   (const AArgs: TJSONObject; const ANome: String): TArray<String>;
    // Argumento "server" — comum a todas as tools deste MCP.
    function ArgServidor(const AArgs: TJSONObject): String;
  public
    function Nome: String; virtual; abstract;
    function Descricao: String; virtual; abstract;
    function Schema: TJSONObject; virtual; abstract;
    function Executar(const AArgs: TJSONObject): String; virtual; abstract;
  end;

implementation

uses
  System.SysUtils;

{ TSchema }

constructor TSchema.Create;
begin
  inherited Create;
  FPropriedades := TJSONObject.Create;
  FObrigatorios := TJSONArray.Create;
end;

destructor TSchema.Destroy;
begin
  // So chega aqui sem Build em caso de excecao no meio da montagem.
  FPropriedades.Free;
  FObrigatorios.Free;
  inherited;
end;

function TSchema.Propriedade(const ANome, ATipo, ADescricao: String; const AObrigatorio: Boolean): TSchema;
var
  Campo: TJSONObject;
begin
  Campo := TJSONObject.Create;
  Campo.AddPair('type', ATipo);
  Campo.AddPair('description', ADescricao);

  FPropriedades.AddPair(ANome, Campo);

  if AObrigatorio then
    FObrigatorios.Add(ANome);

  Result := Self;
end;

function TSchema.Texto(const ANome, ADescricao: String; const AObrigatorio: Boolean): TSchema;
begin
  Result := Propriedade(ANome, 'string', ADescricao, AObrigatorio);
end;

function TSchema.Booleano(const ANome, ADescricao: String): TSchema;
begin
  Result := Propriedade(ANome, 'boolean', ADescricao, False);
end;

function TSchema.Inteiro(const ANome, ADescricao: String): TSchema;
begin
  Result := Propriedade(ANome, 'integer', ADescricao, False);
end;

function TSchema.Objeto(const ANome, ADescricao: String): TSchema;
begin
  Result := Propriedade(ANome, 'object', ADescricao, False);
end;

function TSchema.ListaTexto(const ANome, ADescricao: String): TSchema;
var
  Campo : TJSONObject;
  Itens : TJSONObject;
begin
  Itens := TJSONObject.Create;
  Itens.AddPair('type', 'string');

  Campo := TJSONObject.Create;
  Campo.AddPair('type', 'array');
  Campo.AddPair('items', Itens);
  Campo.AddPair('description', ADescricao);

  FPropriedades.AddPair(ANome, Campo);

  Result := Self;
end;

function TSchema.Build: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', FPropriedades);

  if FObrigatorios.Count > 0 then
    Result.AddPair('required', FObrigatorios)
  else
    FObrigatorios.Free;

  // A posse das partes passou para Result; zerar antes do destrutor.
  FPropriedades := nil;
  FObrigatorios := nil;
  Free;
end;

{ TMCPToolBase }

function TMCPToolBase.ArgTexto(const AArgs: TJSONObject; const ANome, APadrao: String): String;
begin
  if AArgs = nil then
    Exit(APadrao);

  Result := AArgs.GetValue<String>(ANome, APadrao);
end;

function TMCPToolBase.ArgBooleano(const AArgs: TJSONObject; const ANome: String; const APadrao: Boolean): Boolean;
begin
  if AArgs = nil then
    Exit(APadrao);

  Result := AArgs.GetValue<Boolean>(ANome, APadrao);
end;

function TMCPToolBase.ArgInteiro(const AArgs: TJSONObject; const ANome: String; const APadrao: Integer): Integer;
begin
  if AArgs = nil then
    Exit(APadrao);

  Result := AArgs.GetValue<Integer>(ANome, APadrao);
end;

function TMCPToolBase.ArgObjeto(const AArgs: TJSONObject; const ANome: String): TJSONObject;
var
  Valor: TJSONValue;
begin
  Result := nil;

  if AArgs = nil then
    Exit;

  Valor := AArgs.GetValue(ANome);

  if Valor is TJSONObject then
    Result := TJSONObject(Valor);
end;

function TMCPToolBase.ArgLista(const AArgs: TJSONObject; const ANome: String): TArray<String>;
var
  Valor : TJSONValue;
  Item  : TJSONValue;
begin
  SetLength(Result, 0);

  if AArgs = nil then
    Exit;

  Valor := AArgs.GetValue(ANome);

  if not (Valor is TJSONArray) then
    Exit;

  // .Value normaliza numero e booleano para texto — o tipo real do parametro
  // e resolvido depois, pelo Prepare.
  for Item in TJSONArray(Valor) do
    Result := Result + [Item.Value];
end;

function TMCPToolBase.ArgServidor(const AArgs: TJSONObject): String;
begin
  Result := ArgTexto(AArgs, 'server');
end;

end.
