// Raul Pavanelli/Claude - 10/09/2026
// Cliente HTTP das rotas de log do IGERP (classes descendentes de TWeb, em
// SM.Web.pas). E o unico uso legitimo da porta HTTP do servidor DataSnap: a
// porta HTTP NAO serve /datasnap/rest — server method so por DBX/TCP.
//
// Rotas (relativas a http://<host>:<httpport>):
//   /log/listar        — array JSON com ID, DATA, SCRIPT, TAMANHO, PARAMETROS
//   /log/updatelimpar  — zera o log (usar antes de uma chamada, para isolar)
//
// A classe "log" esta sob {$IFDEF DEBUG} no servidor: em build Release as rotas
// nao existem e o DataSnap responde 500 com "datasnap.rest method not found".
// Nesse caso devolvemos uma explicacao, nao o erro cru.
unit MCP.DSCall.Log;

interface

uses
  System.JSON,
  MCP.DSCall.Config;

type
  IDSLog = interface
    ['{A31C7F58-4E96-4B02-9D7A-63E0158BC274}']
    // Limpa o log do servidor. Devolve '' em sucesso ou a mensagem de erro.
    function Limpar(const AServer: TDSServerConfig): String;
    // Scripts recentes em markdown compacto.
    //   AMax     — quantos dos mais recentes trazer (0 = todos os que sobrarem)
    //   AFiltro  — substring case-insensitive; casa em SCRIPT ou PARAMETROS
    //   ADesdeId — so registros com ID maior que este (0 = sem corte)
    // O rodape sempre informa o ultimo ID, para servir de ADesdeId da proxima
    // chamada — e assim acompanhar so o que e novo.
    function Listar(const AServer: TDSServerConfig; const AMax: Integer;
                    const AFiltro: String; const ADesdeId: Integer): String;
  end;

  TDSLog = class(TInterfacedObject, IDSLog)
  private
    function UrlBase(const AServer: TDSServerConfig): String;
    function ExplicarFalha(const AStatusCode: Integer; const ACorpo: String): String;
    // O log mistura tipos (ID e TAMANHO numericos, PARAMETROS array), entao a
    // leitura por campo tem de ser tolerante — GetValue<String> lanca em array.
    function CampoTexto(const AItem: TJSONObject; const ACampo: String): String;
    function DataCurta(const AISO: String): String;
  public
    function Limpar(const AServer: TDSServerConfig): String;
    function Listar(const AServer: TDSServerConfig; const AMax: Integer;
                    const AFiltro: String; const ADesdeId: Integer): String;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  MCP.DSCall.Tabela,
  REST.API;

const
  TIMEOUT_SEGUNDOS = 10;
  MAX_CHARS_SCRIPT = 4000;

{ TDSLog }

function TDSLog.UrlBase(const AServer: TDSServerConfig): String;
begin
  Result := Format('http://%s:%d', [AServer.Host, HttpPortDe(AServer)]);
end;

function TDSLog.CampoTexto(const AItem: TJSONObject; const ACampo: String): String;
var
  Valor: TJSONValue;
begin
  Valor := AItem.GetValue(ACampo);

  if Valor = nil then
    Exit('');

  if Valor is TJSONString then
    Exit(TJSONString(Valor).Value);

  // Arrays e objetos (PARAMETROS) viram texto JSON; vazio nao merece o "[]".
  if Valor is TJSONArray then
  begin
    if TJSONArray(Valor).Count = 0 then
      Exit('');

    Exit(Valor.ToJSON);
  end;

  if Valor is TJSONObject then
    Exit(Valor.ToJSON);

  Result := Valor.Value;
end;

function TDSLog.DataCurta(const AISO: String): String;
begin
  // "2026-09-10T10:30:36.885Z" -> "2026-09-10 10:30:36"
  Result := AISO.Replace('T', ' ').Replace('Z', '');

  if Result.Length > 19 then
    Result := Result.Substring(0, 19);
end;

function TDSLog.ExplicarFalha(const AStatusCode: Integer; const ACorpo: String): String;
begin
  if ACorpo.Contains('method not found') then
    Exit('ERRO: rota /log ausente no servidor. A classe de log so e compilada em build DEBUG ' +
         '(SM.Web.pas, sob $IFDEF DEBUG) — recompile o servidor em DEBUG para ter observabilidade de SQL.');

  Result := Format('ERRO: HTTP %d ao acessar a rota de log: %s', [AStatusCode, ACorpo]);
end;

function TDSLog.Limpar(const AServer: TDSServerConfig): String;
var
  API: TRESTAPI;
begin
  API := TRESTAPI.Create;
  try
    try
      API.Host(UrlBase(AServer));
      API.Route('log/updatelimpar');
      API.Timeout(TIMEOUT_SEGUNDOS);
      API.GET;

      if API.Response.Status <> TResponseStatus.Sucess then
        Exit(ExplicarFalha(API.Response.StatusCode, API.Response.ToString));

      Result := '';
    except
      on E: Exception do
        Result := 'ERRO: nao foi possivel limpar o log em ' + UrlBase(AServer) + ': ' + E.Message;
    end;
  finally
    FreeAndNil(API);
  end;
end;

function TDSLog.Listar(const AServer: TDSServerConfig; const AMax: Integer;
  const AFiltro: String; const ADesdeId: Integer): String;
var
  API     : TRESTAPI;
  Lista   : TJSONArray;
  Item    : TJSONObject;
  Tabela  : TTabela;
  iInicio : Integer;
  iIndice : Integer;
  iTotal  : Integer;
  iId     : Integer;
  iLinha  : Integer;
  iUltimoId    : Integer;
  Selecionados : TArray<Integer>;
  sFiltro : String;
  sScript : String;
  sParams : String;
begin
  API := TRESTAPI.Create;
  try
    try
      API.Host(UrlBase(AServer));
      API.Route('log/listar');
      API.Timeout(TIMEOUT_SEGUNDOS);
      API.GET;

      if API.Response.Status <> TResponseStatus.Sucess then
        Exit(ExplicarFalha(API.Response.StatusCode, API.Response.ToString));

      Lista := API.Response.ToJSONArray;
      if (Lista = nil) or (Lista.Count = 0) then
        Exit('[0 linhas] ultimo_id=0');

      sFiltro   := AFiltro.Trim.ToUpper;
      iUltimoId := 0;
      SetLength(Selecionados, 0);

      // Passo 1 — seleciona por ADesdeId e AFiltro. O corte por AMax so pode
      // vir DEPOIS do filtro, senao "os 20 mais recentes" viraria "os que
      // sobraram dos 20 ultimos", que e outra coisa.
      for iIndice := 0 to Lista.Count - 1 do
      begin
        if not (Lista.Items[iIndice] is TJSONObject) then
          Continue;

        Item := TJSONObject(Lista.Items[iIndice]);
        iId  := StrToIntDef(CampoTexto(Item, 'ID'), 0);

        // O maior ID do log INTEIRO e o ponto de corte temporal, mesmo quando
        // o filtro descarta o ultimo registro.
        if iId > iUltimoId then
          iUltimoId := iId;

        if (ADesdeId > 0) and (iId <= ADesdeId) then
          Continue;

        if sFiltro <> '' then
        begin
          sScript := CampoTexto(Item, 'SCRIPT');
          sParams := CampoTexto(Item, 'PARAMETROS');

          if not (sScript.ToUpper.Contains(sFiltro) or sParams.ToUpper.Contains(sFiltro)) then
            Continue;
        end;

        Selecionados := Selecionados + [iIndice];
      end;

      if Length(Selecionados) = 0 then
        Exit(Format('[0 linhas] ultimo_id=%d', [iUltimoId]));

      // Passo 2 — os mais recentes ficam no fim; trazer so a cauda pedida.
      iTotal  := Length(Selecionados);
      iInicio := 0;
      if (AMax > 0) and (iTotal > AMax) then
        iInicio := iTotal - AMax;

      Tabela := TTabela.Nova(['ID', 'DATA', 'TAMANHO', 'PARAMETROS', 'SCRIPT']);

      for iLinha := iInicio to iTotal - 1 do
      begin
        Item := TJSONObject(Lista.Items[Selecionados[iLinha]]);

        // Teto por script: um SELECT gerado pode ter dezenas de KB e nao ha
        // ganho em despejar tudo no contexto do agente.
        sScript := CelulaSegura(CampoTexto(Item, 'SCRIPT'));
        if sScript.Length > MAX_CHARS_SCRIPT then
          sScript := sScript.Substring(0, MAX_CHARS_SCRIPT) + ' ...[script truncado]';

        Tabela.Add([
          CampoTexto(Item, 'ID'),
          DataCurta(CampoTexto(Item, 'DATA')),
          CampoTexto(Item, 'TAMANHO'),
          CampoTexto(Item, 'PARAMETROS'),
          sScript]);
      end;

      Result := Tabela.ToString + Format(' ultimo_id=%d', [iUltimoId]);

      if iInicio > 0 then
        Result := Result + Format(' (%d anteriores omitidas pelo max)', [iInicio]);
    except
      on E: Exception do
        Result := 'ERRO: nao foi possivel ler o log em ' + UrlBase(AServer) + ': ' + E.Message;
    end;
  finally
    FreeAndNil(API);
  end;
end;

end.
