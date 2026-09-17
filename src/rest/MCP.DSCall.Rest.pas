// Raul Pavanelli/Claude - 17/09/2026
// Camada REST: monta o cliente HTTP de cada API cadastrada e testa conexao.
//
// Independente do DataSnap de proposito — nao usa IDSConexoes nem toca no banco.
// A URL vem do MCP.DSCall.json e so de la: resolver host por outro caminho
// (parametro no banco, por exemplo) exigiria o servidor DataSnap no ar so para
// falar com uma API REST, e deixaria o alvo menos previsivel.
//
// As tres autenticacoes espelham o que o IGLIB\PROXY ja faz:
//   basic      -> TAuthBasic  (MD030: usuario/senha do sistema)
//   bearer     -> TAuthBearer com token fixo do config
//   jwt-hs256  -> TAuthBearer com JWT assinado na hora (MD048: chave compartilhada)
unit MCP.DSCall.Rest;

interface

uses
  System.JSON,
  MCP.DSCall.Config,
  REST.API;

type
  IRestClient = interface
    ['{9C3E7A21-5B48-4D16-A07F-2E8B64D9530C}']
    // APIs cadastradas, com o resultado do teste de conexao.
    function Apis: String;
    // Cliente pronto (host, timeout e Authorization aplicados). O chamador
    // assume a posse e deve liberar.
    function NovoCliente(const AApi: TRestApiConfig): TRESTAPI;
    function Resolver(const ANomeApi: String): TRestApiConfig;

    // Executa a rota. AQuery/ABody/AHeaders sao opcionais (nil = nao enviar).
    function Chamar(const ANomeApi, ARota, AVerbo: String;
                    const AQuery, AHeaders: TJSONObject;
                    const ABody: TJSONValue): String;
  end;

  TRestClient = class(TInterfacedObject, IRestClient)
  private
    FConfig: TMCPDSCallConfig;
    function Autenticacao(const AApi: TRestApiConfig): IAuth;
    function GeraJWT(const AApi: TRestApiConfig): String;
    function TestarConexao(const AApi: TRestApiConfig): String;
  public
    constructor Create(const AConfig: TMCPDSCallConfig);

    function Apis: String;
    function NovoCliente(const AApi: TRestApiConfig): TRESTAPI;
    function Resolver(const ANomeApi: String): TRestApiConfig;
    function Chamar(const ANomeApi, ARota, AVerbo: String;
                    const AQuery, AHeaders: TJSONObject;
                    const ABody: TJSONValue): String;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  JOSE.Core.JWT,
  JOSE.Core.Builder,
  MCP.DSCall.Tabela;

const
  TIMEOUT_TESTE = 5;
  JWT_MINUTOS   = 5;

{ TRestClient }

constructor TRestClient.Create(const AConfig: TMCPDSCallConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TRestClient.Resolver(const ANomeApi: String): TRestApiConfig;
begin
  if FindApi(FConfig, ANomeApi, Result) then
    Exit;

  if ANomeApi.Trim = '' then
    raise Exception.CreateFmt('Informe a API: nao ha padrao. Cadastradas: %s.',
      [NomesApis(FConfig)]);

  raise Exception.CreateFmt('API "%s" nao esta cadastrada no MCP.DSCall.json. Cadastradas: %s.',
    [ANomeApi, NomesApis(FConfig)]);
end;

function TRestClient.GeraJWT(const AApi: TRestApiConfig): String;
var
  Token: TJWT;
begin
  if AApi.Secret.Trim = '' then
    raise Exception.CreateFmt('API %s usa auth=jwt-hs256 mas esta sem "secret" no MCP.DSCall.json.',
      [AApi.Name]);

  // Gerado a cada chamada e valido por poucos minutos: nao ha token velho para
  // invalidar nem renovacao a controlar. Mesmo esquema do MD048.pas do PROXY.
  Token := TJWT.Create;
  try
    Token.Claims.Issuer     := AApi.Issuer;
    Token.Claims.Subject    := AApi.Subject;
    Token.Claims.IssuedAt   := Now;
    Token.Claims.Expiration := IncMinute(Now, JWT_MINUTOS);

    Result := TJOSE.SHA256CompactToken(AApi.Secret, Token);
  finally
    FreeAndNil(Token);
  end;
end;

function TRestClient.Autenticacao(const AApi: TRestApiConfig): IAuth;
begin
  Result := nil;

  if (AApi.Auth = '') or (AApi.Auth = 'none') then
    Exit;

  if AApi.Auth = 'basic' then
    Exit(TAuthBasic.New(AApi.User, AApi.Password));

  if AApi.Auth = 'bearer' then
  begin
    if AApi.Token.Trim = '' then
      raise Exception.CreateFmt('API %s usa auth=bearer mas esta sem "token" no MCP.DSCall.json.',
        [AApi.Name]);

    Exit(TAuthBearer.New(AApi.Token));
  end;

  if AApi.Auth = 'jwt-hs256' then
    Exit(TAuthBearer.New(GeraJWT(AApi)));

  raise Exception.CreateFmt('API %s tem auth="%s" desconhecido. Use none, basic, bearer ou jwt-hs256.',
    [AApi.Name, AApi.Auth]);
end;

function TRestClient.NovoCliente(const AApi: TRestApiConfig): TRESTAPI;
var
  Auth: IAuth;
begin
  Result := TRESTAPI.Create;
  try
    Result.Host(AApi.BaseUrl);
    Result.Timeout(AApi.TimeoutSec);

    Auth := Autenticacao(AApi);
    if Assigned(Auth) then
      Result.Authorization(Auth);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TRestClient.TestarConexao(const AApi: TRestApiConfig): String;
var
  API: TRESTAPI;
begin
  API := nil;
  try
    // Montar o cliente e alcancar o servidor sao falhas DIFERENTES e precisam
    // aparecer diferentes: credencial faltando no config nao e servidor fora do
    // ar, e dizer "offline" nos dois casos manda procurar o problema no lugar
    // errado.
    try
      API := NovoCliente(AApi);
    except
      on E: Exception do
        Exit('config: ' + E.Message);
    end;

    try
      API.Timeout(TIMEOUT_TESTE);
      API.Route(AApi.HealthPath);
      API.GET;

      // Qualquer resposta HTTP prova que o servidor esta no ar e alcancavel.
      // 401/404 nao sao "offline": dizem que respondeu, e isso e o que o teste
      // de conexao precisa saber.
      Result := 'HTTP ' + API.Response.StatusCode.ToString;
    except
      on E: Exception do
        Result := 'offline';
    end;
  finally
    FreeAndNil(API);
  end;
end;

function TRestClient.Apis: String;
var
  Api    : TRestApiConfig;
  Tabela : TTabela;
  sCred  : String;
begin
  if Length(FConfig.Apis) = 0 then
    Exit('[0 apis] Nenhuma API cadastrada em "apis" no MCP.DSCall.json.');

  Tabela := TTabela.Nova(['NOME', 'BASE_URL', 'AUTH', 'CRED', 'AMBIENTE', 'ESCRITA', 'STATUS', 'DESCRICAO']);
  Tabela.RodapeSubstantivo('apis');

  for Api in FConfig.Apis do
  begin
    // Nunca imprimir a credencial em si — so se esta preenchida. Este texto vai
    // para o contexto do agente e pode acabar em transcricao.
    if Api.Auth = 'basic' then
      sCred := IfThen(Api.User <> '', 'user ok', 'SEM USER')
    else
    if Api.Auth = 'bearer' then
      sCred := IfThen(Api.Token <> '', 'token ok', 'SEM TOKEN')
    else
    if Api.Auth = 'jwt-hs256' then
      sCred := IfThen(Api.Secret <> '', 'secret ok', 'SEM SECRET')
    else
      sCred := '-';

    Tabela.Add([
      Api.Name,
      Api.BaseUrl,
      Api.Auth,
      sCred,
      Api.Environment,
      IfThen(Api.AllowWrite, 'sim', 'nao'),
      TestarConexao(Api),
      Api.Description]);
  end;

  Result := Tabela.ToString;
end;

function TRestClient.Chamar(const ANomeApi, ARota, AVerbo: String;
  const AQuery, AHeaders: TJSONObject; const ABody: TJSONValue): String;
var
  Api      : TRestApiConfig;
  API_HTTP : TRESTAPI;
  sVerbo   : String;
  sCorpo   : String;
begin
  Api := Resolver(ANomeApi);

  if ARota.Trim = '' then
    Exit('ERRO: informe a rota.');

  sVerbo := AVerbo.Trim.ToUpper;
  if sVerbo = '' then
    sVerbo := 'GET';

  // A guarda vale para TODOS os verbos, nao so os de escrita: nestas APIs ha
  // rota GET que processa, entao restringir por verbo daria falsa seguranca.
  if not Api.AllowWrite then
    Exit(Format('ERRO: API %s esta em modo somente leitura (allow_write=false no MCP.DSCall.json) ' +
                'e nenhuma rota pode ser executada — nem GET, porque nestas APIs ha GET que processa.',
      [Api.Name]));

  API_HTTP := NovoCliente(Api);
  try
    try
      API_HTTP.Route(ARota.Trim);

      if Assigned(AQuery) and (AQuery.Count > 0) then
        API_HTTP.Query(AQuery.Clone as TJSONObject);

      if Assigned(AHeaders) and (AHeaders.Count > 0) then
        API_HTTP.Headers(AHeaders.Clone as TJSONObject);

      if Assigned(ABody) then
        API_HTTP.Body(ABody.Clone as TJSONValue);

      if sVerbo = 'GET' then
        API_HTTP.GET
      else
      if sVerbo = 'POST' then
        API_HTTP.POST
      else
      if sVerbo = 'PUT' then
        API_HTTP.PUT
      else
      if sVerbo = 'DELETE' then
        API_HTTP.DELETE
      else
        Exit(Format('ERRO: verbo "%s" invalido. Use GET, POST, PUT ou DELETE.', [sVerbo]));

      sCorpo := API_HTTP.Response.ToString;

      // Status na primeira linha SEMPRE, inclusive em erro: e o que diz se a
      // chamada chegou a acontecer. Corpo cru, sem reformatar — o que a API
      // devolveu e o que interessa conferir.
      Result := Format('%s %s%sHTTP %d%s--- RESPOSTA ---%s%s',
        [sVerbo, UrlDe(Api, ARota), sLineBreak,
         API_HTTP.Response.StatusCode, sLineBreak, sLineBreak, sCorpo]);
    except
      on E: Exception do
        Result := Format('ERRO: falha ao chamar %s %s: %s',
          [sVerbo, UrlDe(Api, ARota), E.Message]);
    end;
  finally
    FreeAndNil(API_HTTP);
  end;
end;

end.
