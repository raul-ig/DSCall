// Raul Pavanelli/Claude - 10/09/2026
// Registro das tools publicadas. O servidor consulta o registro; nao conhece
// nenhuma tool concretamente. Acrescentar uma tool = criar a unit e registrar
// no composition root do .dpr, sem editar o servidor (OCP).
unit MCP.DSCall.Registro;

interface

uses
  System.JSON,
  System.Generics.Collections,
  MCP.DSCall.Protocolo;

type
  TMCPRegistroTools = class
  private
    FTools: TList<IMCPTool>;
  public
    constructor Create;
    destructor  Destroy; override;

    procedure Registrar(const ATool: IMCPTool);
    function  Localizar(const ANome: String; out ATool: IMCPTool): Boolean;
    function  Contagem: Integer;

    // Payload de tools/list: {"tools":[{name, description, inputSchema}, ...]}
    function  ListaJSON: TJSONObject;
  end;

implementation

uses
  System.SysUtils;

{ TMCPRegistroTools }

constructor TMCPRegistroTools.Create;
begin
  inherited Create;
  FTools := TList<IMCPTool>.Create;
end;

destructor TMCPRegistroTools.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TMCPRegistroTools.Registrar(const ATool: IMCPTool);
var
  Existente: IMCPTool;
begin
  if ATool = nil then
    raise Exception.Create('Tentativa de registrar uma tool nula.');

  // Nome duplicado deixaria uma das duas inalcancavel — falhar no startup e
  // muito melhor que descobrir isso em runtime.
  if Localizar(ATool.Nome, Existente) then
    raise Exception.CreateFmt('Tool "%s" registrada duas vezes.', [ATool.Nome]);

  FTools.Add(ATool);
end;

function TMCPRegistroTools.Localizar(const ANome: String; out ATool: IMCPTool): Boolean;
var
  Tool: IMCPTool;
begin
  for Tool in FTools do
    if SameText(Tool.Nome, ANome) then
    begin
      ATool := Tool;
      Exit(True);
    end;

  ATool  := nil;
  Result := False;
end;

function TMCPRegistroTools.Contagem: Integer;
begin
  Result := FTools.Count;
end;

function TMCPRegistroTools.ListaJSON: TJSONObject;
var
  Lista : TJSONArray;
  Item  : TJSONObject;
  Tool  : IMCPTool;
begin
  Lista := TJSONArray.Create;

  for Tool in FTools do
  begin
    Item := TJSONObject.Create;
    Item.AddPair('name',        Tool.Nome);
    Item.AddPair('description', Tool.Descricao);
    Item.AddPair('inputSchema', Tool.Schema);

    Lista.AddElement(Item);
  end;

  Result := TJSONObject.Create;
  Result.AddPair('tools', Lista);
end;

end.
