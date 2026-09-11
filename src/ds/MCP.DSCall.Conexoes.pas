// Raul Pavanelli/Claude - 10/09/2026
// Gestao das conexoes DBX com os servidores DataSnap.
//
// Responsabilidade unica: abrir, cachear, derrubar e reconectar. Quem invoca
// metodo ou faz introspecao depende desta interface, nao de TSQLConnection.
//
// O cache preserva o LifeCycle=Session entre chamadas encadeadas. A reconexao
// automatica mora aqui porque o unico ponto seguro para ela e o Prepare, que
// nao produz efeito no servidor — depois do ExecuteUpdate, repetir poderia
// executar duas vezes uma escrita.
unit MCP.DSCall.Conexoes;

interface

uses
  System.Generics.Collections,
  Data.SqlExpr,
  Data.DBXCommon,
  MCP.DSCall.Config;

type
  IDSConexoes = interface
    ['{5E8B3A17-9C24-4D60-B1F8-A0736E2D9C45}']
    function Config: TMCPDSCallConfig;
    // Resolve pelo nome; nome vazio devolve o default. Lanca se nao existir.
    function Resolver(const ANomeServidor: String): TDSServerConfig;

    function Obter     (const AServer: TDSServerConfig): TSQLConnection;
    function Reconectar(const AServer: TDSServerConfig): TSQLConnection;
    procedure Derrubar (const AServer: TDSServerConfig);

    // Comando de server method ja preparado. Reconecta e repete UMA vez se o
    // Prepare falhar — seguro, porque Prepare nao altera nada no servidor.
    function PrepararComando(const AServer: TDSServerConfig; const AMetodo: String): TDBXCommand;
  end;

  TDSConexoes = class(TInterfacedObject, IDSConexoes)
  private
    FConfig : TMCPDSCallConfig;
    FCache  : TObjectDictionary<String, TSQLConnection>;
    function Chave(const AServer: TDSServerConfig): String;
    function Abrir(const AServer: TDSServerConfig): TSQLConnection;
    function NovoComando(const ACon: TSQLConnection; const AMetodo: String): TDBXCommand;
  public
    constructor Create(const AConfig: TMCPDSCallConfig);
    destructor  Destroy; override;

    function Config: TMCPDSCallConfig;
    function Resolver(const ANomeServidor: String): TDSServerConfig;

    function Obter     (const AServer: TDSServerConfig): TSQLConnection;
    function Reconectar(const AServer: TDSServerConfig): TSQLConnection;
    procedure Derrubar (const AServer: TDSServerConfig);

    function PrepararComando(const AServer: TDSServerConfig; const AMetodo: String): TDBXCommand;
  end;

implementation

uses
  System.SysUtils;

{ TDSConexoes }

constructor TDSConexoes.Create(const AConfig: TMCPDSCallConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FCache  := TObjectDictionary<String, TSQLConnection>.Create([doOwnsValues]);
end;

destructor TDSConexoes.Destroy;
begin
  FCache.Free;
  inherited;
end;

function TDSConexoes.Config: TMCPDSCallConfig;
begin
  Result := FConfig;
end;

function TDSConexoes.Chave(const AServer: TDSServerConfig): String;
begin
  Result := UpperCase(AServer.Name);
end;

function TDSConexoes.Resolver(const ANomeServidor: String): TDSServerConfig;
begin
  if not FindServer(FConfig, ANomeServidor, Result) then
    raise Exception.CreateFmt('Servidor "%s" nao esta cadastrado no MCP.DSCall.json. Cadastrados: %s.',
      [ANomeServidor, NomesServidores(FConfig)]);
end;

function TDSConexoes.Abrir(const AServer: TDSServerConfig): TSQLConnection;
begin
  Result := TSQLConnection.Create(nil);
  try
    Result.DriverName  := 'DataSnap';
    Result.LoginPrompt := False;

    Result.Params.Values['DriverUnit']               := 'Data.DBXDataSnap';
    Result.Params.Values['HostName']                 := AServer.Host;
    Result.Params.Values['Port']                     := AServer.Port.ToString;
    Result.Params.Values['CommunicationProtocol']    := 'tcp/ip';
    Result.Params.Values['DatasnapContext']          := 'datasnap/';
    Result.Params.Values['DSAuthenticationUser']     := AServer.User;
    Result.Params.Values['DSAuthenticationPassword'] := AServer.Password;
    Result.Params.Values['ConnectTimeout']           := FConfig.MCP.TimeoutMS.ToString;
    Result.Params.Values['CommunicationTimeout']     := FConfig.MCP.TimeoutMS.ToString;

    try
      Result.Open;
    except
      on E: Exception do
        // Distinguir "nao conectou" de "metodo falhou" importa: o agente precisa
        // saber se o servidor caiu ou se o erro e de negocio.
        raise Exception.CreateFmt('Nao conectou em %s (%s:%d): %s. Verifique se o servidor esta no ar.',
          [AServer.Name, AServer.Host, AServer.Port, E.Message]);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TDSConexoes.Obter(const AServer: TDSServerConfig): TSQLConnection;
var
  Con: TSQLConnection;
begin
  if FCache.TryGetValue(Chave(AServer), Con) and Con.Connected then
    Exit(Con);

  // Entrada morta no cache: descarta antes de abrir outra.
  if FCache.ContainsKey(Chave(AServer)) then
    FCache.Remove(Chave(AServer));

  Result := Abrir(AServer);
  FCache.Add(Chave(AServer), Result);
end;

procedure TDSConexoes.Derrubar(const AServer: TDSServerConfig);
begin
  // doOwnsValues libera a conexao ao remover.
  FCache.Remove(Chave(AServer));
end;

function TDSConexoes.Reconectar(const AServer: TDSServerConfig): TSQLConnection;
begin
  Derrubar(AServer);
  Result := Obter(AServer);
end;

function TDSConexoes.NovoComando(const ACon: TSQLConnection; const AMetodo: String): TDBXCommand;
begin
  Result := ACon.DBXConnection.CreateCommand;
  try
    Result.CommandType := TDBXCommandTypes.DSServerMethod;
    Result.Text        := AMetodo;
    Result.Prepare;
  except
    Result.Free;
    raise;
  end;
end;

function TDSConexoes.PrepararComando(const AServer: TDSServerConfig; const AMetodo: String): TDBXCommand;
begin
  try
    Result := NovoComando(Obter(AServer), AMetodo);
  except
    // Cobre o servidor derrubado pelo buildMD007 no meio da sessao. Repetir o
    // Prepare e seguro: ele nao produz efeito colateral no servidor.
    Result := NovoComando(Reconectar(AServer), AMetodo);
  end;
end;

end.
