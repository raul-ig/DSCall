// Raul Pavanelli/Claude - 30/04/2026
// Atualização automática do executável do servidor MCP. Espelha
// SQLRioStyle/mcp/SQLRioStyleMCP.Atualizacao.pas — diferença é apenas o
// nome do projeto consultado no servidor de distribuição (cada exe tem
// seu próprio histórico de versões).
//
// Como o MCP é processo de longa duração (uma sessão pode durar horas),
// a chamada é feita no startup, antes do loop de stdio. A versão recém-
// baixada só é exercida na próxima inicialização — o Windows permite
// renomear o exe em uso, mas a imagem em memória continua sendo a antiga
// até o processo sair.
unit MCP.DSCall.Atualizacao;

interface

function AtualizacaoAutomatica: Boolean;
function FileVersion(FileName: String): String;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  System.IOUtils,
  System.JSON,
  REST.API;

const
  // Servidor de distribuicao das versoes.
  //
  // RELEASE aponta para PRODUCAO de proposito: e de la que o exe publicado se
  // atualiza, e amarrar isso no fonte garante que o binario entregue busque o
  // lugar certo sem depender de configuracao na maquina do usuario.
  //
  // DEBUG aponta para a maquina local porque este GET roda a CADA execucao do
  // MCP: sem essa separacao, toda sessao de desenvolvimento bateria em producao
  // sem ninguem perceber — foi o que aconteceu antes desta diretiva existir.
  //
  // Consequencia pratica: build de teste tem de ser DEBUG. O build.cmd usa Debug
  // por padrao e so gera Release quando pedido explicitamente ("build.cmd release").
{$IFDEF DEBUG}
  MD016 = 'http://127.0.0.1:8016';
{$ELSE}
  MD016 = 'http://10.0.2.228:8016';
{$ENDIF}
  PROJETO = 'MCP.DSCall';

function FileVersion(FileName: String): String;
var
  dwLen: DWORD;
  lpData: Pointer;
  lpdwHandle: DWORD;
  lplpBuffer: Pointer;
  puLen: LongWord;
  FixedFileInfo: VS_FIXEDFILEINFO;
begin
  Result := '';
  lpData := nil;
  if FileExists(FileName) then
  begin
    dwLen := GetFileVersionInfoSize(PChar(Filename), lpdwHandle);
    if dwLen > 0 then
    begin
      try
        lpData := AllocMem(dwLen);
        GetFileVersionInfo(PChar(Filename), 0, dwLen, lpData);
        if VerQueryValue(lpData, '\', lplpBuffer, puLen) then
        begin
          Move(lplpBuffer^, FixedFileInfo, SizeOf(FixedFileInfo));
          Result :=
            IntToStr(HiWord(FixedFileInfo.dwFileVersionMS)) +'.'+
            IntToStr(LoWord(FixedFileInfo.dwFileVersionMS)) +'.'+
            IntToStr(HiWord(FixedFileInfo.dwFileVersionLS)) +'.'+
            IntToStr(LoWord(FixedFileInfo.dwFileVersionLS));
        end;
      finally
        FreeMem(lpData);
      end;
    end;
  end;
end;

function Atualizar(const sVersaoAtual, sVersaoServidor: String): Boolean;
var
  PartesAtual: TArray<String>;
  PartesServidor: TArray<String>;
  I: Integer;
begin
  Result := False;
  PartesAtual := sVersaoAtual.Split(['.']);
  PartesServidor := sVersaoServidor.Split(['.']);
  if Length(PartesAtual) <> Length(PartesServidor) then
    Exit(True);
  for I := 0 to High(PartesAtual) do
    if PartesServidor[I].ToInteger > PartesAtual[I].ToInteger then
      Exit(True)
    else
    if PartesServidor[I].ToInteger < PartesAtual[I].ToInteger then
      Exit(False);
end;

function AtualizacaoAutomatica: Boolean;
var
  API: TRESTAPI;
  sVersaoAtual: String;
  sVersaoApp: String;
  sAtual: String;
  sOld: String;
begin
  Result := False;
  sAtual := ParamStr(0);
  sOld := ChangeFileExt(sAtual, '.old.exe');

  if TFile.Exists(sOld) then
    TFile.Delete(sOld);

  API := TRESTAPI.Create;
  try
    API.Host(MD016);
    API.Route('read');
    API.Timeout(3);
    API.Query(TJSONObject.Create.AddPair('project', PROJETO));
    API.GET;
    if API.Response.Status <> TResponseStatus.Sucess then
      raise Exception.Create(API.Response.ToString);

    if API.Response.ToJSONArray.Count = 0 then
      Exit;

    sVersaoApp := FileVersion(sAtual);
    for var vItem in API.Response.ToJSONArray do
    begin
      sVersaoAtual := vItem.Value;
      if Atualizar(sVersaoApp, sVersaoAtual.Split(['\'])[0]) then
      begin
        API.Route('download');
        API.Query(TJSONObject.Create.AddPair('project', PROJETO).AddPair('file', sVersaoAtual));
        API.GET;
        if API.Response.Status <> TResponseStatus.Sucess then
          raise Exception.Create(API.Response.ToString);

        TFile.Move(sAtual, sOld);
        API.Response.ToStream.SaveToFile(sAtual);

        Result := True;
      end;
    end;
  finally
    FreeAndNil(API);
  end;
end;

end.
