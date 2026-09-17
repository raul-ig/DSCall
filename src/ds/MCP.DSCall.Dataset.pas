// Raul Pavanelli/Claude - 16/09/2026
// Acesso aos DataSetProviders dos server modules — as listagens que o cliente
// Delphi enxerga via TClientDataSet e que ds_call nao alcanca.
//
// POR QUE NAO DA PARA USAR ds_call AQUI: AS_GetRecords trafega o pacote Midas
// em BinaryBlob (tipo 33) + Variant (tipo 35), e AS_GetProviderNames devolve um
// OleVariant que o DBX degrada para WideString vazio. Montar esses pacotes na
// mao seria reimplementar o Midas. Em vez disso usamos a infraestrutura pronta
// do Delphi: TDSProviderConnection + TClientDataSet falam o protocolo por nos.
//
// Providers e Abrir moram juntos porque compartilham exatamente esse mecanismo
// — separa-los espalharia a montagem da TDSProviderConnection por duas units.
unit MCP.DSCall.Dataset;

interface

uses
  System.Classes,
  System.JSON,
  Data.SqlExpr,
  Datasnap.DSConnect,
  MCP.DSCall.Config,
  MCP.DSCall.Conexoes;

type
  IDSDataset = interface
    ['{4B2E9C08-1A7D-4F53-8E64-C9D05A3F18B7}']
    // Providers publicados por uma classe, com os parametros que cada um espera.
    function Providers(const ANomeServidor, AClasse: String): String;
    // Abre um provider e devolve as linhas em markdown compacto.
    //   AParams        — valores dos parametros do provider, por nome
    //   AQuery/ASearch — opcionais: quando informados, chama SetSQL antes de abrir
    //   AMax           — teto de linhas (0 = usa o default do config)
    function Abrir(const ANomeServidor, AClasse, AProvider, AQuery, ASearch: String;
                   const AParams: TJSONObject; const AMax: Integer): String;
  end;

  TDSDataset = class(TInterfacedObject, IDSDataset)
  private
    FConexoes : IDSConexoes;
    // Buffer do callback do GetProviderNames — a API entrega um nome por vez
    // via TGetStrProc, entao precisa de um metodo coletor (nao uma procedure
    // aninhada) e de um lugar para acumular.
    FColeta   : TStringList;
    procedure ColetarProvider(const ANome: String);

    function  NovaConexaoProvider(const AServer: TDSServerConfig;
                                  const AClasse: String): TDSProviderConnection;
    // SetSQL(pSearch, sQuery) NAO aceita SQL livre: sQuery e o NOME de uma query
    // ja cadastrada no server module e pSearch e o criterio de busca. Passar SQL
    // ali devolve "Query '<texto>' nao encontrada!".
    procedure SelecionarQuery(const AServer: TDSServerConfig; const AClasse, ASearch, AQuery: String);
    // Assinatura do provider: FetchParams pergunta ao servidor quais parametros
    // ele espera. Sem isso o provider roda com os defaults (tipicamente 0 ou
    // vazio) e devolve ZERO LINHAS sem erro nenhum — foi o que aconteceu com o
    // dspT1C8, que filtra por C0JL_FKORIG e recebia 0.
    function ParametrosDe(const AConexao: TDSProviderConnection; const AProvider: String): String;
  public
    constructor Create(const AConexoes: IDSConexoes);
    destructor  Destroy; override;

    function Providers(const ANomeServidor, AClasse: String): String;
    function Abrir(const ANomeServidor, AClasse, AProvider, AQuery, ASearch: String;
                   const AParams: TJSONObject; const AMax: Integer): String;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  Data.DBXCommon,
  Datasnap.DBClient,
  MCP.DSCall.Tipos,
  MCP.DSCall.Tabela;

const
  MAX_LINHAS_PADRAO = 200;

{ TDSDataset }

constructor TDSDataset.Create(const AConexoes: IDSConexoes);
begin
  inherited Create;
  FConexoes := AConexoes;
  FColeta   := TStringList.Create;
end;

destructor TDSDataset.Destroy;
begin
  FColeta.Free;
  inherited;
end;

procedure TDSDataset.ColetarProvider(const ANome: String);
begin
  FColeta.Add(ANome);
end;

function TDSDataset.NovaConexaoProvider(const AServer: TDSServerConfig;
  const AClasse: String): TDSProviderConnection;
begin
  Result := TDSProviderConnection.Create(nil);
  try
    // Reaproveita a conexao ja aberta e cacheada — nao abre socket novo.
    Result.SQLConnection   := FConexoes.Obter(AServer);
    Result.ServerClassName := AClasse;
    Result.Connected       := True;
  except
    Result.Free;
    raise;
  end;
end;

function TDSDataset.ParametrosDe(const AConexao: TDSProviderConnection; const AProvider: String): String;
var
  Dados   : TClientDataSet;
  iParam  : Integer;
  Param   : TParam;
begin
  Result := '';

  // Provider sem parametro simplesmente devolve lista vazia; falha de rede aqui
  // nao deve derrubar a listagem inteira.
  try
    Dados := TClientDataSet.Create(nil);
    try
      Dados.RemoteServer := AConexao;
      Dados.ProviderName := AProvider;
      Dados.FetchParams;

      for iParam := 0 to Dados.Params.Count - 1 do
      begin
        Param := Dados.Params[iParam];

        if Result <> '' then
          Result := Result + ' ';

        Result := Result + Param.Name + ':' + TDBXTipos.NomeTipoCampo(Param.DataType);
      end;
    finally
      FreeAndNil(Dados);
    end;
  except
    on E: Exception do
      Result := '(nao consultado: ' + E.Message + ')';
  end;
end;

function TDSDataset.Providers(const ANomeServidor, AClasse: String): String;
var
  Servidor : TDSServerConfig;
  Conexao  : TDSProviderConnection;
  Tabela   : TTabela;
  sNome    : String;
begin
  if AClasse.Trim = '' then
    Exit('ERRO: informe a classe.');

  Servidor := FConexoes.Resolver(ANomeServidor);

  FColeta.Clear;

  Conexao := NovaConexaoProvider(Servidor, AClasse);
  try
    Conexao.GetProviderNames(ColetarProvider);

    if FColeta.Count = 0 then
      Exit(Format('[0 providers] A classe %s nao publica DataSetProvider. ' +
                  'Use ds_describe_class para ver os metodos que ela expoe.', [AClasse]));

    Tabela := TTabela.Nova(['PROVIDER', 'PARAMETROS']);
    Tabela.Titulo(AClasse);
    Tabela.RodapeSubstantivo('providers');

    for sNome in FColeta do
      Tabela.Add([sNome, ParametrosDe(Conexao, sNome)]);

    Result := Tabela.ToString;
  finally
    FreeAndNil(Conexao);
  end;
end;

procedure TDSDataset.SelecionarQuery(const AServer: TDSServerConfig; const AClasse, ASearch, AQuery: String);
var
  Comando: TDBXCommand;
begin
  // Server method comum — vai por DBX normal. A ordem dos parametros e
  // (pSearch, sQuery), nessa sequencia.
  Comando := FConexoes.PrepararComando(AServer, AClasse + '.SetSQL');
  try
    if Comando.Parameters.Count < 2 then
      raise Exception.CreateFmt('%s.SetSQL tem assinatura inesperada (%d parametros).',
        [AClasse, Comando.Parameters.Count]);

    TDBXTipos.Informar(Comando.Parameters[0], ASearch);
    TDBXTipos.Informar(Comando.Parameters[1], AQuery);

    Comando.ExecuteUpdate;
  finally
    FreeAndNil(Comando);
  end;
end;

function TDSDataset.Abrir(const ANomeServidor, AClasse, AProvider, AQuery, ASearch: String;
  const AParams: TJSONObject; const AMax: Integer): String;
var
  Servidor : TDSServerConfig;
  Conexao  : TDSProviderConnection;
  Dados    : TClientDataSet;
  Tabela   : TTabela;
  Colunas  : TArray<String>;
  Celulas  : TArray<String>;
  Par      : TJSONPair;
  Param    : TParam;
  iCampo   : Integer;
  iMax     : Integer;
  iLidas   : Integer;
  bTruncou : Boolean;
  sFaltando: String;
begin
  if AClasse.Trim = '' then
    Exit('ERRO: informe a classe.');

  if AProvider.Trim = '' then
    Exit('ERRO: informe o provider. Use ds_providers para listar os da classe.');

  Servidor := FConexoes.Resolver(ANomeServidor);

  iMax := AMax;
  if iMax <= 0 then
    iMax := MAX_LINHAS_PADRAO;

  // SetSQL muda qual query o provider usa nesta sessao — nao e SQL arbitrario,
  // mas ainda e estado do server module, entao respeita a guarda de escrita.
  if (AQuery.Trim <> '') or (ASearch.Trim <> '') then
  begin
    if not Servidor.AllowWrite then
      Exit(Format('ERRO: servidor %s esta em modo somente leitura (allow_write=false) e os parametros ' +
                  'query/search exigem SetSQL, que altera o estado do server module. ' +
                  'Abra o provider sem eles.', [Servidor.Name]));

    SelecionarQuery(Servidor, AClasse, ASearch, AQuery);
  end;

  Conexao := NovaConexaoProvider(Servidor, AClasse);
  try
    Dados := TClientDataSet.Create(nil);
    try
      Dados.RemoteServer   := Conexao;
      Dados.ProviderName   := AProvider;
      // Um pacote so, do tamanho pedido: evita trazer a tabela inteira pela rede
      // quando o agente so quer espiar as primeiras linhas.
      Dados.FetchOnDemand  := False;
      Dados.PacketRecords  := iMax;

      // FetchParams SEMPRE: traz a definicao (nome e tipo) dos parametros, o que
      // permite converter cada valor pelo tipo certo e, quando nada foi passado,
      // saber que o provider esperava algo — para avisar se vier vazio.
      try
        Dados.FetchParams;
      except
        // Provider sem parametros pode lancar aqui; nao e erro.
      end;

      if Assigned(AParams) and (AParams.Count > 0) then
      begin
        sFaltando := '';

        for Par in AParams do
        begin
          Param := Dados.Params.FindParam(Par.JsonString.Value);

          if Param = nil then
          begin
            if sFaltando <> '' then
              sFaltando := sFaltando + ', ';

            sFaltando := sFaltando + Par.JsonString.Value;
            Continue;
          end;

          TDBXTipos.InformarParam(Param, Par.JsonValue.Value);
        end;

        // Nome errado passaria despercebido e o provider devolveria vazio — o
        // mesmo sintoma de nao ter passado parametro nenhum.
        if sFaltando <> '' then
          Exit(Format('ERRO: o provider %s nao tem o(s) parametro(s): %s. ' +
                      'Use ds_providers para ver os nomes exatos.', [AProvider, sFaltando]));
      end;

      try
        Dados.Open;
      except
        on E: Exception do
          Exit(Format('ERRO: nao abriu o provider %s de %s: %s. ' +
                      'Confira o nome com ds_providers.', [AProvider, AClasse, E.Message]));
      end;

      SetLength(Colunas, Dados.FieldCount);
      for iCampo := 0 to Dados.FieldCount - 1 do
        Colunas[iCampo] := Dados.Fields[iCampo].FieldName;

      Tabela := TTabela.Nova(Colunas);

      iLidas   := 0;
      bTruncou := False;

      Dados.First;
      while not Dados.Eof do
      begin
        if iLidas >= iMax then
        begin
          bTruncou := True;
          Break;
        end;

        SetLength(Celulas, Dados.FieldCount);
        for iCampo := 0 to Dados.FieldCount - 1 do
          Celulas[iCampo] := TDBXTipos.ValorDeCampo(Dados.Fields[iCampo]);

        Tabela.Add(Celulas);
        Inc(iLidas);

        Dados.Next;
      end;

      Result := Tabela.ToString;

      if bTruncou then
        Result := Result + Format(' (truncado em max=%d)', [iMax]);

      // Zero linhas com parametros nao informados e o sintoma classico: o
      // provider roda com os defaults e nao acusa nada. Dizer isso aqui evita
      // que se conclua "nao ha dados" quando na verdade faltou filtro.
      if (iLidas = 0) and (Dados.Params.Count > 0) and
         ((not Assigned(AParams)) or (AParams.Count = 0)) then
        Result := Result + Format(
          ' AVISO: este provider espera %d parametro(s) e nenhum foi informado — ' +
          'rodou com os defaults. Use ds_providers para ver os nomes e passe-os em params.',
          [Dados.Params.Count]);
    finally
      FreeAndNil(Dados);
    end;
  finally
    FreeAndNil(Conexao);
  end;
end;

end.
