// Raul Pavanelli/Claude - 10/09/2026
// Conversao entre TDBXValue e texto, e nomes legiveis de tipo e direcao.
//
// Isolada porque e a unica parte que conhece a tabela de tipos DBX: quando
// aparecer um tipo novo no IGERP, o ajuste e so aqui.
unit MCP.DSCall.Tipos;

interface

uses
  Data.DBXCommon;

type
  TDBXTipos = class
  public
    class function NomeTipo   (const ATipo: Integer): String;
    class function NomeDirecao(const ADirecao: Integer): String;

    // Entrada = o que o chamador precisa informar (in e inout).
    class function EhEntrada(const AParametro: TDBXParameter): Boolean;

    class procedure Informar(const AParametro: TDBXParameter; const AValor: String);
    class function  Ler     (const AParametro: TDBXParameter): String;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.JSON;

{ TDBXTipos }

class function TDBXTipos.NomeTipo(const ATipo: Integer): String;
begin
  case ATipo of
    TDBXDataTypes.Int32Type      : Result := 'Int32';
    TDBXDataTypes.Int16Type      : Result := 'Int16';
    TDBXDataTypes.Int64Type      : Result := 'Int64';
    TDBXDataTypes.WideStringType : Result := 'WideString';
    TDBXDataTypes.AnsiStringType : Result := 'AnsiString';
    TDBXDataTypes.BooleanType    : Result := 'Boolean';
    TDBXDataTypes.DoubleType     : Result := 'Double';
    TDBXDataTypes.BcdType        : Result := 'Bcd';
    TDBXDataTypes.JsonValueType  : Result := 'JsonValue';
  else
    Result := 'Tipo' + ATipo.ToString;
  end;
end;

class function TDBXTipos.NomeDirecao(const ADirecao: Integer): String;
begin
  case ADirecao of
    TDBXParameterDirections.InParameter     : Result := 'in';
    TDBXParameterDirections.OutParameter    : Result := 'out';
    TDBXParameterDirections.InOutParameter  : Result := 'inout';
    TDBXParameterDirections.ReturnParameter : Result := 'ret';
  else
    Result := '?';
  end;
end;

class function TDBXTipos.EhEntrada(const AParametro: TDBXParameter): Boolean;
begin
  Result := (AParametro.ParameterDirection = TDBXParameterDirections.InParameter) or
            (AParametro.ParameterDirection = TDBXParameterDirections.InOutParameter);
end;

class procedure TDBXTipos.Informar(const AParametro: TDBXParameter; const AValor: String);
var
  Conteudo: TJSONValue;
begin
  case AParametro.DataType of
    TDBXDataTypes.Int32Type,
    TDBXDataTypes.Int16Type      : AParametro.Value.SetInt32(StrToInt(AValor));
    TDBXDataTypes.Int64Type      : AParametro.Value.SetInt64(StrToInt64(AValor));
    TDBXDataTypes.BooleanType    : AParametro.Value.SetBoolean(SameText(AValor, 'true') or (AValor = '1'));
    TDBXDataTypes.DoubleType,
    TDBXDataTypes.BcdType        : AParametro.Value.SetDouble(StrToFloat(AValor.Replace(',', '.'), TFormatSettings.Invariant));
    TDBXDataTypes.JsonValueType  :
      begin
        Conteudo := TJSONObject.ParseJSONValue(AValor);
        if Conteudo = nil then
          raise Exception.CreateFmt('Parametro %s espera JSON valido, recebeu: %s', [AParametro.Name, AValor]);

        // True: a posse passa para o TDBXValue, que libera junto com o comando.
        AParametro.Value.SetJSONValue(Conteudo, True);
      end;
  else
    AParametro.Value.SetWideString(AValor);
  end;
end;

class function TDBXTipos.Ler(const AParametro: TDBXParameter): String;
var
  sTexto   : WideString;
  Conteudo : TJSONValue;
begin
  if AParametro.Value.IsNull then
    Exit('');

  case AParametro.DataType of
    TDBXDataTypes.Int32Type,
    TDBXDataTypes.Int16Type      : Result := AParametro.Value.GetInt32.ToString;
    TDBXDataTypes.Int64Type      : Result := AParametro.Value.GetInt64.ToString;
    TDBXDataTypes.BooleanType    : Result := IfThen(AParametro.Value.GetBoolean, 'true', 'false');
    TDBXDataTypes.DoubleType,
    TDBXDataTypes.BcdType        : Result := FloatToStr(AParametro.Value.GetDouble, TFormatSettings.Invariant);
    TDBXDataTypes.JsonValueType  :
      begin
        // A posse do TJSONValue fica com o TDBXJSONValue (ele libera junto com
        // o comando): pegar so a referencia. Liberar aqui causa AV.
        Conteudo := AParametro.Value.GetJSONValue;
        if Conteudo = nil then
          Exit('');

        Result := Conteudo.ToJSON;
      end;
  else
    begin
      AParametro.Value.GetWideString(sTexto);
      Result := sTexto;
    end;
  end;
end;

end.
