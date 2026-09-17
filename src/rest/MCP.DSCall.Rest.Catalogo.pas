// Raul Pavanelli/Claude - 17/09/2026
// Catalogo de rotas REST: o que existe em cada API e COMO chamar.
//
// Nao ha extrator nem pre-carga: o catalogo nasce vazio e cresce conforme as
// rotas sao descobertas e validadas. Isso e proposital — o projeto nao le fonte
// de nenhum outro repositorio.
//
// ARMAZENAMENTO EM CAMADAS: a arvore de pastas espelha o caminho da rota, um
// no por pasta. A rota "pedido/item/listar" da API MD030 vira:
//
//   <catalogo>\MD030\pedido\item\listar.json
//
// Assim navegar o catalogo e navegar a API, e um no com dezenas de rotas nao
// vira um arquivo gigante.
//
// SEGURANCA: todo caminho e validado e confinado na pasta do catalogo. Nome de
// no com ".." ou unidade de disco e recusado — sem isso, uma rota mal informada
// escreveria em qualquer lugar do disco.
unit MCP.DSCall.Rest.Catalogo;

interface

uses
  System.JSON;

type
  ICatalogoRotas = interface
    ['{E71A5C34-96D8-4F02-B5A3-8D24E06C7F91}']
    // Arvore de um nivel: sub-nos e rotas do caminho informado.
    function Listar(const AApi, ANo: String): String;
    // Conteudo completo de uma rota (o JSON como esta no arquivo).
    function Ler(const AApi, ARota: String): String;
    // Cria ou substitui a rota. ADados e o objeto JSON da rota.
    function Gravar(const AApi, ARota: String; const ADados: TJSONObject): String;
    function Remover(const AApi, ARota: String): String;
    // Onde o catalogo esta gravado — util para o operador versionar/inspecionar.
    function Raiz: String;
  end;

  TCatalogoRotas = class(TInterfacedObject, ICatalogoRotas)
  private
    FRaiz: String;
    function  PastaApi(const AApi: String): String;
    function  CaminhoRota(const AApi, ARota: String): String;
    function  CaminhoNo(const AApi, ANo: String): String;
    procedure ValidarSegmento(const ASegmento: String);
    function  Normalizar(const ACaminho: String): String;
    function  SegmentosDe(const ACaminho: String): TArray<String>;
  public
    constructor Create(const ARaiz: String);

    function Listar(const AApi, ANo: String): String;
    function Ler(const AApi, ARota: String): String;
    function Gravar(const AApi, ARota: String; const ADados: TJSONObject): String;
    function Remover(const AApi, ARota: String): String;
    function Raiz: String;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Types,
  MCP.DSCall.Tabela;

const
  EXT_ROTA = '.json';

{ TCatalogoRotas }

constructor TCatalogoRotas.Create(const ARaiz: String);
begin
  inherited Create;
  FRaiz := ExcludeTrailingPathDelimiter(ARaiz);
end;

function TCatalogoRotas.Raiz: String;
begin
  Result := FRaiz;
end;

procedure TCatalogoRotas.ValidarSegmento(const ASegmento: String);
var
  chInvalido: Char;
begin
  if ASegmento.Trim = '' then
    raise Exception.Create('Caminho invalido: ha um segmento vazio (barra dupla ou barra no fim).');

  // Confinar na pasta do catalogo: sem isso "../../algo" escreveria fora dela.
  if (ASegmento = '.') or (ASegmento = '..') then
    raise Exception.Create('Caminho invalido: ".." e "." nao sao permitidos.');

  if ASegmento.Contains(':') then
    raise Exception.Create('Caminho invalido: unidade de disco nao e permitida.');

  for chInvalido in TPath.GetInvalidFileNameChars do
    if ASegmento.Contains(chInvalido) then
      raise Exception.CreateFmt('Caminho invalido: o caractere "%s" nao pode ser usado em nome de no ou rota.',
        [chInvalido]);
end;

function TCatalogoRotas.Normalizar(const ACaminho: String): String;
begin
  Result := ACaminho.Trim.Replace('\', '/');

  while Result.StartsWith('/') do
    Result := Result.Substring(1);

  while Result.EndsWith('/') do
    Result := Result.Substring(0, Result.Length - 1);
end;

function TCatalogoRotas.SegmentosDe(const ACaminho: String): TArray<String>;
var
  sSegmento : String;
  sLimpo    : String;
begin
  SetLength(Result, 0);
  sLimpo := Normalizar(ACaminho);

  if sLimpo = '' then
    Exit;

  for sSegmento in sLimpo.Split(['/']) do
  begin
    ValidarSegmento(sSegmento);
    Result := Result + [sSegmento];
  end;
end;

function TCatalogoRotas.PastaApi(const AApi: String): String;
begin
  if AApi.Trim = '' then
    raise Exception.Create('Informe a api.');

  ValidarSegmento(AApi.Trim);
  Result := TPath.Combine(FRaiz, AApi.Trim);
end;

function TCatalogoRotas.CaminhoNo(const AApi, ANo: String): String;
var
  sSegmento: String;
begin
  Result := PastaApi(AApi);

  for sSegmento in SegmentosDe(ANo) do
    Result := TPath.Combine(Result, sSegmento);
end;

function TCatalogoRotas.CaminhoRota(const AApi, ARota: String): String;
var
  Segmentos : TArray<String>;
  iIndice   : Integer;
begin
  Segmentos := SegmentosDe(ARota);

  if Length(Segmentos) = 0 then
    raise Exception.Create('Informe a rota.');

  Result := PastaApi(AApi);

  // Todos menos o ultimo viram pasta; o ultimo e o arquivo da rota.
  for iIndice := 0 to High(Segmentos) - 1 do
    Result := TPath.Combine(Result, Segmentos[iIndice]);

  Result := TPath.Combine(Result, Segmentos[High(Segmentos)] + EXT_ROTA);
end;

function TCatalogoRotas.Listar(const AApi, ANo: String): String;
var
  sPasta   : String;
  Tabela   : TTabela;
  Pastas   : TStringDynArray;
  Arquivos : TStringDynArray;
  sItem    : String;
  iTotal   : Integer;
begin
  // Sem api: lista as APIs catalogadas (o primeiro nivel).
  if AApi.Trim = '' then
  begin
    if not TDirectory.Exists(FRaiz) then
      Exit('[0 apis] Catalogo vazio. Raiz: ' + FRaiz);

    Tabela := TTabela.Nova(['TIPO', 'NOME']);
    Tabela.RodapeSubstantivo('apis');

    for sItem in TDirectory.GetDirectories(FRaiz) do
      Tabela.Add(['api', TPath.GetFileName(sItem)]);

    Exit(Tabela.ToString);
  end;

  sPasta := CaminhoNo(AApi, ANo);

  if not TDirectory.Exists(sPasta) then
    Exit(Format('[0 itens] Nada catalogado em %s/%s ainda. Raiz: %s',
      [AApi, Normalizar(ANo), FRaiz]));

  Pastas   := TDirectory.GetDirectories(sPasta);
  Arquivos := TDirectory.GetFiles(sPasta, '*' + EXT_ROTA);

  Tabela := TTabela.Nova(['TIPO', 'NOME']);
  Tabela.RodapeSubstantivo('itens');

  // Nos primeiro, depois rotas: a arvore fica legivel de cima para baixo.
  for sItem in Pastas do
    Tabela.Add(['no', TPath.GetFileName(sItem)]);

  for sItem in Arquivos do
    Tabela.Add(['rota', TPath.GetFileNameWithoutExtension(sItem)]);

  iTotal := Length(Pastas) + Length(Arquivos);

  Result := Tabela.ToString;

  if iTotal = 0 then
    Result := Result + ' (pasta existe mas esta vazia)';
end;

function TCatalogoRotas.Ler(const AApi, ARota: String): String;
var
  sArquivo: String;
begin
  sArquivo := CaminhoRota(AApi, ARota);

  if not TFile.Exists(sArquivo) then
    Exit(Format('ERRO: rota "%s" nao esta catalogada na api %s. ' +
                'Use rest_catalog_list para navegar, ou rest_catalog_set para cadastrar.',
      [Normalizar(ARota), AApi]));

  Result := TFile.ReadAllText(sArquivo, TEncoding.UTF8);
end;

function TCatalogoRotas.Gravar(const AApi, ARota: String; const ADados: TJSONObject): String;
var
  sArquivo : String;
  sPasta   : String;
  bNova    : Boolean;
begin
  if ADados = nil then
    raise Exception.Create('Informe os dados da rota.');

  sArquivo := CaminhoRota(AApi, ARota);
  sPasta   := TPath.GetDirectoryName(sArquivo);
  bNova    := not TFile.Exists(sArquivo);

  if not TDirectory.Exists(sPasta) then
    TDirectory.CreateDirectory(sPasta);

  // Gravado formatado de proposito: o arquivo e para ser lido e editado por
  // pessoas tambem, nao so pela ferramenta.
  TFile.WriteAllText(sArquivo, ADados.Format(2), TEncoding.UTF8);

  if bNova then
    Result := Format('Rota "%s" CADASTRADA na api %s.', [Normalizar(ARota), AApi])
  else
    Result := Format('Rota "%s" ATUALIZADA na api %s.', [Normalizar(ARota), AApi]);

  Result := Result + sLineBreak + 'Arquivo: ' + sArquivo;
end;

function TCatalogoRotas.Remover(const AApi, ARota: String): String;
var
  sArquivo: String;
begin
  sArquivo := CaminhoRota(AApi, ARota);

  if not TFile.Exists(sArquivo) then
    Exit(Format('ERRO: rota "%s" nao esta catalogada na api %s — nada a remover.',
      [Normalizar(ARota), AApi]));

  TFile.Delete(sArquivo);

  // A pasta do no NAO e removida junto: ela pode conter outras rotas, e apagar
  // arvore por efeito colateral de um delete de rota seria destrutivo demais.
  Result := Format('Rota "%s" removida da api %s.', [Normalizar(ARota), AApi]);
end;

end.
