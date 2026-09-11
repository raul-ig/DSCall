// Raul Pavanelli/Claude - 10/09/2026
// Introspecao: o que o servidor publica e como se chama.
//
// Tudo aqui e LEITURA — nenhuma operacao altera estado no servidor. Por isso
// as operacoes podem ser repetidas apos uma reconexao sem risco, ao contrario
// da invocacao (ver MCP.DSCall.Invoke).
unit MCP.DSCall.Introspec;

interface

uses
  MCP.DSCall.Config,
  MCP.DSCall.Conexoes;

type
  IDSIntrospec = interface
    ['{0F7D2A93-8C15-4E6B-A248-9B3057E1D6CA}']
    // Servidores cadastrados, com status e o banco REAL de cada um.
    function Servidores: String;
    function ListarClasses  (const ANomeServidor, AFiltro: String): String;
    function DescreverClasse(const ANomeServidor, AClasse: String; const ATodos: Boolean): String;
    function DescreverMetodo(const ANomeServidor, AMetodo: String): String;
  end;

  TDSIntrospec = class(TInterfacedObject, IDSIntrospec)
  private
    FConexoes: IDSConexoes;

    function  EhMetodoHerdado(const AMetodo: String): Boolean;
    // Le TWeb.GetInfo para expor o banco que esta REALMENTE atras do servidor.
    // Um servidor mal cadastrado apontando para producao responde ao mesmo
    // protocolo — o nome do banco e a unica evidencia confiavel do alvo.
    procedure InfoServidor(const AServer: TDSServerConfig; out ABanco, AVersao, ABuild: String);

    function ListarClassesEm  (const AServer: TDSServerConfig; const AFiltro: String): String;
    function DescreverClasseEm(const AServer: TDSServerConfig; const AClasse: String; const ATodos: Boolean): String;
  public
    constructor Create(const AConexoes: IDSConexoes);

    function Servidores: String;
    function ListarClasses  (const ANomeServidor, AFiltro: String): String;
    function DescreverClasse(const ANomeServidor, AClasse: String; const ATodos: Boolean): String;
    function DescreverMetodo(const ANomeServidor, AMetodo: String): String;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.JSON,
  System.Generics.Collections,
  Data.DBXCommon,
  Datasnap.DSProxy,
  MCP.DSCall.Tipos,
  MCP.DSCall.Tabela;

const
  // Metodos herdados de TServerModuleBase — existem em TODAS as classes
  // publicadas e so gastariam tokens em cada describe.
  METODOS_HERDADOS: array[0..6] of String = (
    'GetLastIG_RECNO', 'GetParT007', 'SetCustomSQL', 'SetSQL', 'ExecCountSql',
    'GravarMensagemSistema', 'AS_');

{ TDSIntrospec }

constructor TDSIntrospec.Create(const AConexoes: IDSConexoes);
begin
  inherited Create;
  FConexoes := AConexoes;
end;

procedure TDSIntrospec.InfoServidor(const AServer: TDSServerConfig; out ABanco, AVersao, ABuild: String);
var
  Comando  : TDBXCommand;
  Conteudo : TJSONValue;
  Info     : TJSONObject;
begin
  ABanco  := '';
  AVersao := '';
  ABuild  := '';

  // GetInfo e leitura pura; se a classe TWeb nao existir neste servidor, apenas
  // ficamos sem a informacao — nao e motivo para falhar o ds_servers.
  try
    Comando := FConexoes.PrepararComando(AServer, 'TWeb.GetInfo');
    try
      Comando.ExecuteUpdate;

      if Comando.Parameters.Count = 0 then
        Exit;

      Conteudo := Comando.Parameters[Comando.Parameters.Count - 1].Value.GetJSONValue;
      if not (Conteudo is TJSONObject) then
        Exit;

      Info    := TJSONObject(Conteudo);
      ABanco  := Info.GetValue<String>('base_dados',      '').Trim;
      AVersao := Info.GetValue<String>('versao_servidor', '').Trim;
      ABuild  := Info.GetValue<String>('build_conf',      '').Trim;
    finally
      FreeAndNil(Comando);
    end;
  except
    // Silencioso de proposito: a ausencia da info nao invalida o resto da linha.
  end;
end;

function TDSIntrospec.Servidores: String;
var
  Servidor : TDSServerConfig;
  Tabela   : TTabela;
  sStatus  : String;
  sBanco   : String;
  sVersao  : String;
  sBuild   : String;
begin
  Tabela := TTabela.Nova(['NOME', 'HOST', 'PORTA', 'HTTP', 'AMBIENTE', 'ESCRITA',
                          'STATUS', 'BANCO', 'VERSAO', 'BUILD', 'DESCRICAO']);

  for Servidor in FConexoes.Config.Servers do
  begin
    sBanco  := '';
    sVersao := '';
    sBuild  := '';

    try
      FConexoes.Obter(Servidor);
      sStatus := 'ok';
      InfoServidor(Servidor, sBanco, sVersao, sBuild);
    except
      on E: Exception do
      begin
        FConexoes.Derrubar(Servidor);
        sStatus := 'offline';
      end;
    end;

    Tabela.Add([
      Servidor.Name,
      Servidor.Host,
      Servidor.Port.ToString,
      HttpPortDe(Servidor).ToString,
      Servidor.Environment,
      IfThen(Servidor.AllowWrite, 'sim', 'nao'),
      sStatus,
      sBanco,
      sVersao,
      sBuild,
      Servidor.Description]);
  end;

  Result := Tabela.ToString;
end;

function TDSIntrospec.ListarClassesEm(const AServer: TDSServerConfig; const AFiltro: String): String;
var
  Admin   : TDSAdminClient;
  Lista   : TJSONArray;
  Item    : TJSONValue;
  Tabela  : TTabela;
  sClasse : String;
begin
  Admin := TDSAdminClient.Create(FConexoes.Obter(AServer).DBXConnection);
  try
    Lista := Admin.ListClasses;
    if Lista = nil then
      Exit('[0 linhas]');

    Tabela := TTabela.NovaLista;

    for Item in Lista do
    begin
      sClasse := Item.Value;

      if (AFiltro.Trim <> '') and (not sClasse.ToUpper.Contains(AFiltro.Trim.ToUpper)) then
        Continue;

      Tabela.Add(sClasse);
    end;

    Result := Tabela.ToString;
  finally
    FreeAndNil(Admin);
  end;
end;

function TDSIntrospec.ListarClasses(const ANomeServidor, AFiltro: String): String;
var
  Servidor: TDSServerConfig;
begin
  Servidor := FConexoes.Resolver(ANomeServidor);

  // Leitura pura: uma retentativa apos reconexao e segura e cobre o servidor
  // derrubado pelo buildMD007 no meio da sessao.
  try
    Result := ListarClassesEm(Servidor, AFiltro);
  except
    FConexoes.Reconectar(Servidor);
    Result := ListarClassesEm(Servidor, AFiltro);
  end;
end;

function TDSIntrospec.EhMetodoHerdado(const AMetodo: String): Boolean;
var
  sHerdado: String;
begin
  for sHerdado in METODOS_HERDADOS do
    if SameText(AMetodo, sHerdado) or AMetodo.StartsWith(sHerdado, True) then
      Exit(True);

  Result := False;
end;

function TDSIntrospec.DescreverClasseEm(const AServer: TDSServerConfig; const AClasse: String;
  const ATodos: Boolean): String;
var
  Admin     : TDSAdminClient;
  Descricao : TJSONObject;
  Detalhe   : TJSONObject;
  Metodos   : TJSONArray;
  Item      : TJSONValue;
  Tabela    : TTabela;
  sMetodo   : String;
  iOmitidos : Integer;
begin
  Admin := TDSAdminClient.Create(FConexoes.Obter(AServer).DBXConnection);
  try
    Descricao := Admin.DescribeClass(AClasse);
    if (Descricao = nil) or (Descricao.Count = 0) then
      Exit(Format('ERRO: classe %s nao encontrada no servidor.', [AClasse]));

    // O retorno vem como {"TClasse":{"LifeCycle":"...","methods":[...]}}
    Detalhe := Descricao.Pairs[0].JsonValue as TJSONObject;
    if Detalhe = nil then
      Exit(Format('ERRO: resposta inesperada ao descrever %s.', [AClasse]));

    Tabela := TTabela.NovaLista;
    Tabela.Titulo(AClasse + ' LifeCycle=' + Detalhe.GetValue<String>('LifeCycle', '?'));
    Tabela.RodapeSubstantivo('metodos');

    Metodos   := Detalhe.GetValue('methods') as TJSONArray;
    iOmitidos := 0;

    if Assigned(Metodos) then
      for Item in Metodos do
      begin
        sMetodo := Item.Value;

        // O prefixo "TClasse." e redundante com o titulo.
        if sMetodo.StartsWith(AClasse + '.', True) then
          sMetodo := sMetodo.Substring(Length(AClasse) + 1);

        if (not ATodos) and EhMetodoHerdado(sMetodo) then
        begin
          Inc(iOmitidos);
          Continue;
        end;

        Tabela.Add(sMetodo);
      end;

    Result := Tabela.ToString;

    if iOmitidos > 0 then
      Result := Result + Format(' (%d herdados de TServerModuleBase omitidos — use all:true para ver todos)',
        [iOmitidos]);
  finally
    FreeAndNil(Admin);
  end;
end;

function TDSIntrospec.DescreverClasse(const ANomeServidor, AClasse: String; const ATodos: Boolean): String;
var
  Servidor: TDSServerConfig;
begin
  if AClasse.Trim = '' then
    Exit('ERRO: informe a classe.');

  Servidor := FConexoes.Resolver(ANomeServidor);

  try
    Result := DescreverClasseEm(Servidor, AClasse, ATodos);
  except
    FConexoes.Reconectar(Servidor);
    Result := DescreverClasseEm(Servidor, AClasse, ATodos);
  end;
end;

function TDSIntrospec.DescreverMetodo(const ANomeServidor, AMetodo: String): String;
var
  Servidor   : TDSServerConfig;
  Comando    : TDBXCommand;
  Tabela     : TTabela;
  iParametro : Integer;
  Parametro  : TDBXParameter;
begin
  if not AMetodo.Contains('.') then
    Exit('ERRO: informe o metodo como TClasse.Metodo.');

  Servidor := FConexoes.Resolver(ANomeServidor);

  // O Prepare e a fonte da verdade: traz os tipos DBX reais que o ds_call vai
  // usar, garantindo que descricao e execucao nunca divirjam.
  Comando := FConexoes.PrepararComando(Servidor, AMetodo);
  try
    Tabela := TTabela.Nova(['NOME', 'TIPO', 'DIRECAO']);
    Tabela.Titulo(AMetodo);
    Tabela.SemRodape;

    for iParametro := 0 to Comando.Parameters.Count - 1 do
    begin
      Parametro := Comando.Parameters[iParametro];

      Tabela.Add([
        Parametro.Name,
        TDBXTipos.NomeTipo(Parametro.DataType),
        TDBXTipos.NomeDirecao(Parametro.ParameterDirection)]);
    end;

    Result := Tabela.ToString;
  finally
    FreeAndNil(Comando);
  end;
end;

end.
