// Raul Pavanelli/Claude - 10/09/2026
// MCP Server para invocar server methods do IGERP (DataSnap) via DBX/TCP.
// Comunicacao MCP via stdin/stdout (JSON-RPC 2.0, LF-delimited).
// Nao depende de nenhuma unit do IGERP — compila isolado.
//
// Este arquivo e o COMPOSITION ROOT: e o unico ponto que conhece as classes
// concretas e monta o grafo de dependencias. Todo o resto conversa por
// interface. Acrescentar uma tool = criar a unit e registra-la aqui.
program MCP.DSCall;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows,
  Data.DB,
  Data.SqlExpr,
  Data.DBXCommon,
  Data.DBXDataSnap,
  Datasnap.DSProxy,
  IPPeerClient,
  REST.API                        in 'src\util\REST.API.pas',
  MCP.DSCall.Tabela               in 'src\util\MCP.DSCall.Tabela.pas',
  MCP.DSCall.Atualizacao          in 'src\util\MCP.DSCall.Atualizacao.pas',
  MCP.DSCall.Protocolo            in 'src\mcp\MCP.DSCall.Protocolo.pas',
  MCP.DSCall.Registro             in 'src\mcp\MCP.DSCall.Registro.pas',
  MCP.DSCall.Transporte           in 'src\mcp\MCP.DSCall.Transporte.pas',
  MCP.DSCall.Server               in 'src\mcp\MCP.DSCall.Server.pas',
  MCP.DSCall.Config               in 'src\ds\MCP.DSCall.Config.pas',
  MCP.DSCall.Convencoes           in 'src\ds\MCP.DSCall.Convencoes.pas',
  MCP.DSCall.Tipos                in 'src\ds\MCP.DSCall.Tipos.pas',
  MCP.DSCall.Conexoes             in 'src\ds\MCP.DSCall.Conexoes.pas',
  MCP.DSCall.Log                  in 'src\ds\MCP.DSCall.Log.pas',
  MCP.DSCall.Introspec            in 'src\ds\MCP.DSCall.Introspec.pas',
  MCP.DSCall.Invoke               in 'src\ds\MCP.DSCall.Invoke.pas',
  MCP.DSCall.Tool.Servers         in 'src\tools\MCP.DSCall.Tool.Servers.pas',
  MCP.DSCall.Tool.Classes         in 'src\tools\MCP.DSCall.Tool.Classes.pas',
  MCP.DSCall.Tool.DescribeClass   in 'src\tools\MCP.DSCall.Tool.DescribeClass.pas',
  MCP.DSCall.Tool.DescribeMethod  in 'src\tools\MCP.DSCall.Tool.DescribeMethod.pas',
  MCP.DSCall.Tool.Call            in 'src\tools\MCP.DSCall.Tool.Call.pas',
  MCP.DSCall.Tool.SqlLog          in 'src\tools\MCP.DSCall.Tool.SqlLog.pas';

{$R *.res}

const
  SERVER_NAME    = 'MCP.DSCall';
  SERVER_TITLE   = 'MCP.DSCall — server methods do IGERP via DataSnap';
  SERVER_VERSION = '1.0.0';

var
  Transporte : IMCPTransporte;
  Config     : TMCPDSCallConfig;
  Conexoes   : IDSConexoes;
  Log        : IDSLog;
  Introspec  : IDSIntrospec;
  Invoke     : IDSInvoke;
  Registro   : TMCPRegistroTools;
  Servidor   : TMCPServer;

begin
  SetConsoleOutputCP(CP_UTF8);

  // O transporte sobe primeiro: e por ele que qualquer falha e reportada, em
  // stderr. stdout fica reservado ao protocolo JSON-RPC.
  Transporte := TStdioTransporte.Create('[' + SERVER_NAME + '] ');

  // Atualizacao automatica no startup. O exe em execucao continua sendo a
  // versao antiga (Windows mantem a imagem em memoria); a nova so e exercida
  // na proxima inicializacao. Falhas sao silenciadas — servidor de distribuicao
  // offline nao pode impedir o MCP de subir.
  try
    if AtualizacaoAutomatica then
      Transporte.Log('Nova versao baixada — sera ativada na proxima execucao');
  except
    on E: Exception do
      Transporte.Log('Atualizacao automatica falhou: ' + E.ClassName + ': ' + E.Message);
  end;

  Registro := nil;
  try
    try
      // Se o MCP.DSCall.json nao existir, e aqui que ele e gerado e o processo
      // aborta com orientacao ao operador.
      Config := LoadConfig;

      Conexoes  := TDSConexoes.Create(Config);
      Log       := TDSLog.Create;
      Introspec := TDSIntrospec.Create(Conexoes);
      Invoke    := TDSInvoke.Create(Conexoes, Log);

      Registro := TMCPRegistroTools.Create;
      Registro.Registrar(TToolServers.Create(Introspec));
      Registro.Registrar(TToolClasses.Create(Introspec));
      Registro.Registrar(TToolDescribeClass.Create(Introspec));
      Registro.Registrar(TToolDescribeMethod.Create(Introspec));
      Registro.Registrar(TToolCall.Create(Invoke));
      Registro.Registrar(TToolSqlLog.Create(Invoke));

      // Bloqueia ate EOF do cliente.
      Servidor := TMCPServer.Create(Transporte, Registro, SERVER_NAME, SERVER_TITLE, SERVER_VERSION);
      try
        Servidor.Executar;
      finally
        Servidor.Free;
      end;
    except
      on E: Exception do
      begin
        Transporte.Log('Fatal: ' + E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Registro.Free;
  end;
end.
