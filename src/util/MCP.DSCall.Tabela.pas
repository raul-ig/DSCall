// Raul Pavanelli/Claude - 10/09/2026
// Montagem do markdown compacto (pipe-separated) usado por TODAS as respostas.
//
// Existe para que o formato seja definido em UM lugar so: antes cada rotina
// concatenava '|' na mao e repetia a regra do rodape, o que multiplicava a
// chance de divergencia entre tools.
//
// Formato:
//   linha 1     : nomes de coluna separados por |
//   linhas 2..N : dados, | entre celulas
//   ultima linha: rodape "[N linhas]" (ou variante informada)
unit MCP.DSCall.Tabela;

interface

type
  TTabela = record
  private
    FTitulo      : String;
    FLinhas      : TArray<String>;
    FTemCabec    : Boolean;
    FRodapeOff   : Boolean;
    FSubstantivo : String;
  public
    // Tabela com cabecalho de colunas.
    class function Nova(const AColunas: array of String): TTabela; static;
    // Lista simples, sem cabecalho (ex: nomes de classe, um por linha).
    class function NovaLista: TTabela; static;

    // Acrescenta uma linha ja formatada (sem pipes) ou monta a partir das celulas.
    procedure Add(const ACelulas: array of String); overload;
    procedure Add(const ALinha: String); overload;

    // Titulo livre acima do cabecalho (ex: "TSM0977A LifeCycle=Session").
    procedure Titulo(const ATexto: String);

    // Troca "linhas" por outro substantivo no rodape (ex: "metodos").
    procedure RodapeSubstantivo(const ATexto: String);
    // Suprime o rodape (respostas de item unico nao ganham nada com ele).
    procedure SemRodape;

    function Contagem: Integer;
    function ToString: String;
  end;

// Deixa um valor seguro para uma celula: sem pipe, sem TAB e sem quebra de linha.
function CelulaSegura(const ATexto: String): String;

implementation

uses
  System.SysUtils;

function CelulaSegura(const ATexto: String): String;
begin
  Result := ATexto.Replace('|', ' ')
                  .Replace(#9, ' ')
                  .Replace(#13, ' ')
                  .Replace(#10, ' ')
                  .Trim;

  while Result.Contains('  ') do
    Result := Result.Replace('  ', ' ');
end;

{ TTabela }

class function TTabela.Nova(const AColunas: array of String): TTabela;
var
  sCabecalho : String;
  sColuna    : String;
begin
  Result := TTabela.NovaLista;
  Result.FTemCabec := True;

  sCabecalho := '';
  for sColuna in AColunas do
  begin
    if sCabecalho <> '' then
      sCabecalho := sCabecalho + '|';

    sCabecalho := sCabecalho + sColuna;
  end;

  Result.FLinhas := [sCabecalho];
end;

class function TTabela.NovaLista: TTabela;
begin
  Result.FTitulo      := '';
  Result.FLinhas      := [];
  Result.FTemCabec    := False;
  Result.FRodapeOff   := False;
  Result.FSubstantivo := 'linhas';
end;

procedure TTabela.Titulo(const ATexto: String);
begin
  // Fica fora de FLinhas de proposito: titulo nao e linha de dado e nao pode
  // entrar na contagem do rodape.
  FTitulo := ATexto;
end;

procedure TTabela.Add(const ACelulas: array of String);
var
  sLinha  : String;
  sCelula : String;
  bPrimeira : Boolean;
begin
  sLinha    := '';
  bPrimeira := True;

  for sCelula in ACelulas do
  begin
    if not bPrimeira then
      sLinha := sLinha + '|';

    sLinha    := sLinha + CelulaSegura(sCelula);
    bPrimeira := False;
  end;

  FLinhas := FLinhas + [sLinha];
end;

procedure TTabela.Add(const ALinha: String);
begin
  FLinhas := FLinhas + [ALinha];
end;

procedure TTabela.RodapeSubstantivo(const ATexto: String);
begin
  FSubstantivo := ATexto;
end;

procedure TTabela.SemRodape;
begin
  FRodapeOff := True;
end;

function TTabela.Contagem: Integer;
begin
  // O cabecalho de colunas nao e dado.
  Result := Length(FLinhas);

  if FTemCabec then
    Dec(Result);

  if Result < 0 then
    Result := 0;
end;

function TTabela.ToString: String;
var
  Saida: TArray<String>;
begin
  Saida := [];

  if FTitulo <> '' then
    Saida := [FTitulo];

  Saida := Saida + FLinhas;

  if not FRodapeOff then
    Saida := Saida + [Format('[%d %s]', [Contagem, FSubstantivo])];

  Result := String.Join(sLineBreak, Saida);
end;

end.
