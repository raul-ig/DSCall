// Raul Pavanelli/Claude - 10/09/2026
// Conversao entre TDBXValue e texto, e nomes legiveis de tipo e direcao.
//
// Isolada porque e a unica parte que conhece a tabela de tipos DBX: quando
// aparecer um tipo novo no IGERP, o ajuste e so aqui.
unit MCP.DSCall.Tipos;

interface

uses
  Data.DB,
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

    // Valor de um campo de dataset (ds_dataset) como texto de celula.
    // Booleano sai como 1/0 aqui, e nao true/false como em Ler: um dataset traz
    // centenas de linhas e o par de caracteres a menos por celula pesa. Ler
    // trata retorno de function, onde o par de linhas nao faz diferenca.
    class function ValorDeCampo(const ACampo: TField): String;

    // Parametro de provider (ds_dataset): o tipo vem do FetchParams, entao a
    // conversao e dirigida por ele — passar tudo como string faria o provider
    // comparar texto com inteiro e devolver vazio sem erro nenhum.
    class procedure InformarParam(const AParam: TParam; const AValor: String);
    class function  NomeTipoCampo(const ATipo: TFieldType): String;
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
    TDBXDataTypes.DateType       : Result := 'Date';
    TDBXDataTypes.TimeType       : Result := 'Time';
    TDBXDataTypes.DateTimeType   : Result := 'DateTime';
    TDBXDataTypes.TimeStampType  : Result := 'TimeStamp';
    TDBXDataTypes.UInt16Type     : Result := 'UInt16';
    TDBXDataTypes.UInt32Type     : Result := 'UInt32';
    TDBXDataTypes.SingleType     : Result := 'Single';
    TDBXDataTypes.BytesType      : Result := 'Bytes';
    TDBXDataTypes.VarBytesType   : Result := 'VarBytes';
    TDBXDataTypes.BlobType       : Result := 'Blob';
    // Os tres abaixo aparecem nos metodos AS_* (providers). Nao sao chamaveis
    // por ds_call: trafegam o pacote Midas binario — use ds_dataset.
    TDBXDataTypes.BinaryBlobType : Result := 'BinaryBlob';
    TDBXDataTypes.VariantType    : Result := 'Variant';
    TDBXDataTypes.ObjectType     : Result := 'Object';
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

class function TDBXTipos.ValorDeCampo(const ACampo: TField): String;
begin
  if ACampo.IsNull then
    Exit('');

  case ACampo.DataType of
    ftBoolean:
      Result := IfThen(ACampo.AsBoolean, '1', '0');

    ftDate:
      Result := FormatDateTime('yyyy-mm-dd', ACampo.AsDateTime);

    ftTime:
      Result := FormatDateTime('hh:nn:ss', ACampo.AsDateTime);

    ftDateTime, ftTimeStamp:
      // Sem milissegundos de proposito: ruido em quase toda leitura.
      Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ACampo.AsDateTime);

    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
      // Ponto invariante — nunca virgula, para o valor poder ser reusado em SQL.
      Result := FloatToStr(ACampo.AsFloat, TFormatSettings.Invariant);

    ftBlob, ftGraphic, ftOraBlob, ftOraClob, ftVarBytes, ftBytes:
      // Despejar binario no contexto do agente nao ajuda ninguem.
      Result := Format('[blob %d bytes]', [ACampo.DataSize]);
  else
    // CHAR(N) vem com padding do SQL Server; o espaco a direita e ruido.
    Result := ACampo.AsString.TrimRight;
  end;
end;

class function TDBXTipos.NomeTipoCampo(const ATipo: TFieldType): String;
begin
  // FieldTypeNames traz "ftInteger"; o prefixo so gasta token.
  Result := FieldTypeNames[ATipo];

  if Result.StartsWith('ft') then
    Result := Result.Substring(2);
end;

class procedure TDBXTipos.InformarParam(const AParam: TParam; const AValor: String);
begin
  if AValor = '' then
  begin
    AParam.Clear;
    Exit;
  end;

  case AParam.DataType of
    ftSmallint, ftInteger, ftWord, ftAutoInc:
      AParam.AsInteger := StrToInt(AValor);

    ftLargeint:
      AParam.AsLargeInt := StrToInt64(AValor);

    ftBoolean:
      AParam.AsBoolean := SameText(AValor, 'true') or (AValor = '1');

    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
      AParam.AsFloat := StrToFloat(AValor.Replace(',', '.'), TFormatSettings.Invariant);

    ftDate, ftTime, ftDateTime, ftTimeStamp:
      AParam.AsDateTime := StrToDateTime(AValor);
  else
    AParam.AsString := AValor;
  end;
end;

end.
