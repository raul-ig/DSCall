// Raul Pavanelli/Claude - 10/09/2026
// Invocacao de server method — a unica parte do sistema que ALTERA estado.
//
// Separada da introspecao justamente por isso: aqui valem regras que nao valem
// em leitura, e ter as duas na mesma classe convidava a aplicar a regra errada.
//
//   - guarda de escrita (allow_write) antes de qualquer coisa;
//   - aridade conferida contra o Prepare antes de executar;
//   - NENHUMA retentativa depois do ExecuteUpdate: repetir automaticamente
//     poderia executar duas vezes um metodo que grava.
unit MCP.DSCall.Invoke;

interface

uses
  System.JSON,
  MCP.DSCall.Conexoes,
  MCP.DSCall.Log;

type
  IDSInvoke = interface
    ['{D6410B27-53AE-4F19-8C60-72B9E3A5148F}']
    function Chamar(const ANomeServidor, AMetodo: String; const APosicionais: TArray<String>;
                    const ANomeados: TJSONObject; const AComSQL: Boolean): String;
    function LogSQL(const ANomeServidor: String; const ALimpar: Boolean; const AMax: Integer): String;
  end;

  TDSInvoke = class(TInterfacedObject, IDSInvoke)
  private
    FConexoes: IDSConexoes;
    FLog     : IDSLog;
  public
    constructor Create(const AConexoes: IDSConexoes; const ALog: IDSLog);

    function Chamar(const ANomeServidor, AMetodo: String; const APosicionais: TArray<String>;
                    const ANomeados: TJSONObject; const AComSQL: Boolean): String;
    function LogSQL(const ANomeServidor: String; const ALimpar: Boolean; const AMax: Integer): String;
  end;

implementation

uses
  System.SysUtils,
  Data.DBXCommon,
  MCP.DSCall.Config,
  MCP.DSCall.Tipos,
  MCP.DSCall.Tabela;

{ TDSInvoke }

constructor TDSInvoke.Create(const AConexoes: IDSConexoes; const ALog: IDSLog);
begin
  inherited Create;
  FConexoes := AConexoes;
  FLog      := ALog;
end;

function TDSInvoke.Chamar(const ANomeServidor, AMetodo: String; const APosicionais: TArray<String>;
  const ANomeados: TJSONObject; const AComSQL: Boolean): String;
var
  Servidor    : TDSServerConfig;
  Comando     : TDBXCommand;
  Parametro   : TDBXParameter;
  Tabela      : TTabela;
  iParametro  : Integer;
  iEntradas   : Integer;
  iRecebidos  : Integer;
  iPosicao    : Integer;
  sValor      : String;
  sAvisoLog   : String;
begin
  if not AMetodo.Contains('.') then
    Exit('ERRO: informe o metodo como TClasse.Metodo.');

  Servidor := FConexoes.Resolver(ANomeServidor);

  // Guarda de escrita: o servidor so e invocavel se o operador liberou.
  if not Servidor.AllowWrite then
    Exit(Format('ERRO: servidor %s esta em modo somente leitura (allow_write=false no MCP.DSCall.json). ' +
                'Use ds_describe_method para inspecionar a assinatura sem executar.', [Servidor.Name]));

  Comando := FConexoes.PrepararComando(Servidor, AMetodo);
  try
    // Aridade conferida ANTES de executar — erro util em vez da excecao crua.
    iEntradas := 0;
    for iParametro := 0 to Comando.Parameters.Count - 1 do
      if TDBXTipos.EhEntrada(Comando.Parameters[iParametro]) then
        Inc(iEntradas);

    if Assigned(ANomeados) then
      iRecebidos := ANomeados.Count
    else
      iRecebidos := Length(APosicionais);

    if iRecebidos <> iEntradas then
      Exit(Format('ERRO: %s espera %d parametro(s) de entrada, recebeu %d. ' +
                  'Use ds_describe_method para ver a assinatura.',
        [AMetodo, iEntradas, iRecebidos]));

    // Nomeados tem precedencia sobre posicionais.
    iPosicao := 0;
    for iParametro := 0 to Comando.Parameters.Count - 1 do
    begin
      Parametro := Comando.Parameters[iParametro];

      if not TDBXTipos.EhEntrada(Parametro) then
        Continue;

      if Assigned(ANomeados) then
      begin
        if not Assigned(ANomeados.GetValue(Parametro.Name)) then
          Exit(Format('ERRO: falta o parametro "%s" em named. Use ds_describe_method para ver os nomes.',
            [Parametro.Name]));

        sValor := ANomeados.GetValue(Parametro.Name).Value;
      end
      else
      begin
        sValor := APosicionais[iPosicao];
        Inc(iPosicao);
      end;

      TDBXTipos.Informar(Parametro, sValor);
    end;

    // Isola no log do servidor apenas o SQL desta chamada.
    if AComSQL then
    begin
      sAvisoLog := FLog.Limpar(Servidor);
      if sAvisoLog <> '' then
        sAvisoLog := '(aviso) nao foi possivel limpar o log antes da chamada: ' + sAvisoLog;
    end;

    // A partir daqui NAO ha retentativa.
    Comando.ExecuteUpdate;

    Tabela := TTabela.NovaLista;
    Tabela.SemRodape;

    for iParametro := 0 to Comando.Parameters.Count - 1 do
    begin
      Parametro := Comando.Parameters[iParametro];

      if TDBXTipos.EhEntrada(Parametro) then
        Continue;

      Tabela.Add([
        Parametro.Name,
        TDBXTipos.NomeTipo(Parametro.DataType),
        TDBXTipos.Ler(Parametro)]);
    end;

    Result := Tabela.ToString;

    if Result = '' then
      Result := '(procedure sem retorno)';

    if AComSQL then
    begin
      if sAvisoLog <> '' then
        Result := Result + sLineBreak + sAvisoLog;

      Result := Result + sLineBreak + '--- SQL ---' + sLineBreak +
                FLog.Listar(Servidor, FConexoes.Config.MCP.SqlLogMax);
    end;
  finally
    FreeAndNil(Comando);
  end;
end;

function TDSInvoke.LogSQL(const ANomeServidor: String; const ALimpar: Boolean; const AMax: Integer): String;
var
  Servidor : TDSServerConfig;
  iMax     : Integer;
  sErro    : String;
begin
  // Rotas de log sao HTTP puro (classes TWeb) — nao passam pela conexao DBX,
  // entao nao dependem do servidor estar conectado nem de allow_write.
  Servidor := FConexoes.Resolver(ANomeServidor);

  if ALimpar then
  begin
    sErro := FLog.Limpar(Servidor);
    if sErro <> '' then
      Exit(sErro);
  end;

  iMax := AMax;
  if iMax <= 0 then
    iMax := FConexoes.Config.MCP.SqlLogMax;

  Result := FLog.Listar(Servidor, iMax);
end;

end.
