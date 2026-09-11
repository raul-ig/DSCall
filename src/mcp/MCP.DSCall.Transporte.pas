// Raul Pavanelli/Claude - 10/09/2026
// Transporte stdio do MCP: leitura e escrita de linhas UTF-8 em stdin/stdout.
//
// Separado do servidor de proposito — o servidor cuida de JSON-RPC e dispatch,
// esta unit cuida de bytes. stdout e EXCLUSIVO do protocolo: qualquer log vai
// para stderr, senao a mensagem corrompe o stream que o cliente esta lendo.
unit MCP.DSCall.Transporte;

interface

uses
  Winapi.Windows;

type
  IMCPTransporte = interface
    ['{2B9F0D14-6A73-4C25-8E31-D5C7A4F86192}']
    // Le uma linha; AEof indica fim de stream (cliente encerrou).
    function  LerLinha(out AEof: Boolean): String;
    procedure EscreverLinha(const ALinha: String);
    procedure Log(const AMensagem: String);
  end;

  TStdioTransporte = class(TInterfacedObject, IMCPTransporte)
  private
    FEntrada : THandle;
    FSaida   : THandle;
    FErro    : THandle;
    FPrefixo : String;
    procedure Escrever(const AHandle: THandle; const ATexto: String; const AFlush: Boolean);
  public
    constructor Create(const APrefixoLog: String);

    function  LerLinha(out AEof: Boolean): String;
    procedure EscreverLinha(const ALinha: String);
    procedure Log(const AMensagem: String);
  end;

implementation

uses
  System.SysUtils;

{ TStdioTransporte }

constructor TStdioTransporte.Create(const APrefixoLog: String);
begin
  inherited Create;
  FEntrada := GetStdHandle(STD_INPUT_HANDLE);
  FSaida   := GetStdHandle(STD_OUTPUT_HANDLE);
  FErro    := GetStdHandle(STD_ERROR_HANDLE);
  FPrefixo := APrefixoLog;
end;

procedure TStdioTransporte.Escrever(const AHandle: THandle; const ATexto: String; const AFlush: Boolean);
var
  Bytes   : TBytes;
  Escrito : DWORD;
  LF      : Byte;
begin
  Bytes := TEncoding.UTF8.GetBytes(ATexto);

  if Length(Bytes) > 0 then
    WriteFile(AHandle, Bytes[0], Length(Bytes), Escrito, nil);

  LF := 10;
  WriteFile(AHandle, LF, 1, Escrito, nil);

  if AFlush then
    FlushFileBuffers(AHandle);
end;

function TStdioTransporte.LerLinha(out AEof: Boolean): String;
var
  B      : Byte;
  Lidos  : DWORD;
  Buffer : TBytes;
  iConta : Integer;
begin
  SetLength(Buffer, 256);
  iConta := 0;
  AEof   := False;

  while True do
  begin
    if not ReadFile(FEntrada, B, 1, Lidos, nil) then
    begin
      AEof := True;
      Break;
    end;

    if Lidos = 0 then
    begin
      AEof := True;
      Break;
    end;

    if B = 10 then  // LF encerra a mensagem
      Break;

    if B = 13 then  // CR e ignorado
      Continue;

    if iConta >= Length(Buffer) then
      SetLength(Buffer, Length(Buffer) * 2);

    Buffer[iConta] := B;
    Inc(iConta);
  end;

  if iConta = 0 then
    Exit('');

  SetLength(Buffer, iConta);
  Result := TEncoding.UTF8.GetString(Buffer);
end;

procedure TStdioTransporte.EscreverLinha(const ALinha: String);
begin
  // Flush obrigatorio: o cliente espera a resposta linha a linha.
  Escrever(FSaida, ALinha, True);
end;

procedure TStdioTransporte.Log(const AMensagem: String);
begin
  Escrever(FErro, FPrefixo + AMensagem, False);
end;

end.
