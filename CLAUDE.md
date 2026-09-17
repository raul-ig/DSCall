# MCP.DSCall — CLAUDE.md

## O que é este projeto

MCP Server em Delphi para invocar **server methods do IGERP** (DataSnap) via DBX/TCP.
Comunicação com o Claude via stdio (JSON-RPC 2.0).

Nasceu da investigação em `D:\000-Claude\DSCall\ESPECIFICACAO-MCP-DATASNAP-IGERP.md` (10/09/2026) e do protótipo console `DSCall.dpr` da mesma pasta. Estruturalmente espelha o `D:\GIT\RAUL\DBLink` (MCP.DBLink).

---

## Estrutura

```
<raiz-do-projeto>\
├── MCP.DSCall.dpr             — composition root (monta o grafo de dependências)
├── MCP.DSCall.dproj           — projeto Delphi (RAD Studio 22.0 / Win32)
├── MCP.DSCall.json            — configuração externa (NÃO versionar)
├── build.cmd                  — compila Release/Win32 em exe\
├── install.cmd                — publica em %USERPROFILE%\.claude\mcp\DSCall\
├── .gitignore / .gitattributes
├── README.md / CLAUDE.md
└── src\
    ├── mcp\                        — camada de protocolo, NÃO conhece DataSnap
    │   ├── MCP.DSCall.Protocolo.pas    — IMCPTool, TMCPToolBase, TSchema
    │   ├── MCP.DSCall.Registro.pas     — TMCPRegistroTools
    │   ├── MCP.DSCall.Transporte.pas   — IMCPTransporte / stdio
    │   └── MCP.DSCall.Server.pas       — loop, JSON-RPC, dispatch
    ├── ds\                         — domínio DataSnap
    │   ├── MCP.DSCall.Config.pas       — array de servidores; gera o JSON default
    │   ├── MCP.DSCall.Convencoes.pas   — textos embutidos nas descrições das tools
    │   ├── MCP.DSCall.Tipos.pas        — conversão TDBXValue ↔ texto
    │   ├── MCP.DSCall.Conexoes.pas     — IDSConexoes: cache, reconexão, Prepare
    │   ├── MCP.DSCall.Log.pas          — IDSLog: rotas /log das classes TWeb
    │   ├── MCP.DSCall.Introspec.pas    — IDSIntrospec: só leitura
    │   └── MCP.DSCall.Invoke.pas       — IDSInvoke: a única parte que altera estado
    ├── tools\                      — uma unit por tool
    │   └── MCP.DSCall.Tool.{Servers,Classes,DescribeClass,DescribeMethod,Call,SqlLog}.pas
    └── util\
        ├── MCP.DSCall.Tabela.pas       — markdown compacto (formato em um lugar só)
        ├── MCP.DSCall.Atualizacao.pas  — auto-update no startup (servidor MD016)
        └── REST.API.pas                — cliente HTTP (cópia local, sem dependência externa)
```

### Por que está dividido assim

- **`mcp\` não conhece DataSnap.** O servidor recebe transporte e registro prontos; não sabe o que é
  um server method. Isso permite testar o protocolo sem subir servidor nenhum.
- **`Introspec` e `Invoke` são separados de propósito.** Introspecção é leitura pura e pode ser
  repetida após reconexão; invocação **altera estado** e não pode. Ter as duas na mesma classe
  convidava a aplicar a regra errada.
- **Uma unit por tool.** Acrescentar uma tool é criar a unit e registrá-la no `.dpr` — o servidor não
  muda. Antes exigia editar dois pontos (a string do schema e a cadeia de `if`).
- **`TSchema` monta o `inputSchema` com `TJSONObject`**, nunca por concatenação de string. A versão
  anterior concatenava, e dois escapes inválidos (uma barra de caminho e um `\\"`) derrubaram o
  `tools/list` **inteiro** — o cliente não via tool nenhuma e só se descobria em runtime.
- **`TTabela` centraliza o markdown compacto.** Antes cada rotina concatenava `'|'` na mão e repetia
  a regra do rodapé.

### Como acrescentar uma tool

1. Criar `src\tools\MCP.DSCall.Tool.<Nome>.pas` com uma classe descendente de `TMCPToolBase`
   (`Nome`, `Descricao`, `Schema`, `Executar`), recebendo por construtor a interface de que precisa.
2. Acrescentar a unit ao `uses` do `.dpr` e ao `.dproj`.
3. Registrar no composition root: `Registro.Registrar(TToolNova.Create(Introspec));`

Nada mais. Nome duplicado falha no startup, e não silenciosamente.

---

## Fatos do protocolo que custaram caro para descobrir

Estes pontos foram verificados na prática contra o MD007 e **não devem ser re-derivados**:

- **Server method só responde por TCP** (porta 211 no MD007, 229 no MD029), protocolo binário DBX. Não há como chamar por `curl`.
- **A porta HTTP não é DataSnap REST.** A 8211 responde HTTP, mas só serve as classes descendentes de `TWeb` (`SM.Web.pas`), com rota `/<classe>/<metodo>`. Qualquer outro path devolve HTTP 500 com `{"error":"datasnap.rest method not found in the server method list"}` — mensagem do runtime do DataSnap que **engana**: parece método não publicado, mas o problema é que `/datasnap/rest/...` não é servido.
- **A porta HTTP é derivada** da TCP por concatenação: `PortHTTP := '8' + PortTCP` (`DS.Config.pas`).
- **`Prepare` traz a assinatura real** (`Parameters.Count`, `Name`, `DataType`, `ParameterDirection`) — é a fonte da verdade usada tanto por `ds_describe_method` quanto pela validação de aridade do `ds_call`.
- **`ReturnParameter` é o último parâmetro** de uma `function`; `procedure` não tem.
- **Métodos `private` não são publicados** pelo DataSnap; só `public`/`published`.
- **As rotas `/log` só existem em build DEBUG** do servidor (`log = class(TWeb)` sob `{$IFDEF DEBUG}`, `SM.Web.pas`).

---

## Configuração — MCP.DSCall.json

Arquivo no mesmo diretório do executável (`ChangeFileExt(ParamStr(0), '.json')`). Na primeira execução é gerado já com MD007 e MD029, e o programa aborta para o operador conferir.

O **array de servidores é a allowlist**: `ds_call` só alcança hosts cadastrados. Um servidor de produção responde ao mesmo protocolo e às mesmas credenciais — por isso `environment` aparece em `ds_servers`.

| Campo | Significado |
|---|---|
| `name` | Chave usada no argumento `server` das tools (case-insensitive) |
| `port` | Porta TCP/DBX — é por onde os server methods respondem |
| `http_port` | `0` deriva como `'8' + port`; valor explícito sobrepõe |
| `environment` | Rótulo livre (DEV/HOMOLOG/PROD), exibido em `ds_servers` |
| `allow_write` | `false` bloqueia `ds_call`; introspecção continua liberada |
| `default` | Servidor usado quando a tool omite `server` |

**Nunca alterar** `MCP.DSCall.json` — é configuração de ambiente do operador e contém a senha do DataSnap.

---

## Ciclo de trabalho obrigatório

Está replicado nas descrições das tools (constante `WORKFLOW` em `src\ds\MCP.DSCall.Convencoes.pas`) para valer em qualquer cliente MCP, sem depender deste arquivo:

1. **`buildMD007.bat` após alterar qualquer `SM*.pas`** — o `.bat` mata e reinicia o servidor. Sem isso o binário no ar é o antigo e a chamada testa código velho **silenciosamente**, sem erro nenhum.
2. **`ds_describe_class`** — confirmar que o método novo aparece. É a prova de que o servidor certo subiu.
3. **`ds_call`**, de preferência com `com_sql: true`.
4. **Conferir os efeitos no banco** por outro canal (MCP DBLinkDEV).

Sobre o build: se o cliente MD009 falhar com `Undeclared identifier` num método novo, é o `DS.Proxy.pas` gerado pela metade — regenerar com `D:\01-Utilitarios\Proxy.exe`. **Não afeta o MCP**, que fala DBX direto e dispensa proxy.

---

## Segurança — o ponto que exige mais cuidado

`ds_call` executa código de negócio com a sessão `ADMIN`. Na investigação original, uma chamada de teste alterou `T00J.C00J_REGCAR` e desativou uma rota em `T1G0`.

- **O nome do método não indica o efeito.** `CadastroCAR` só consulta apesar do nome; `DefinirPrincipal` grava.
- **Para métodos que gravam**: capturar o estado pelo DBLinkDEV, chamar, conferir, restaurar.
- **Confirmar o alvo** com `ds_servers` antes de qualquer escrita — o protocolo é idêntico em DEV e produção.
- **Reconexão nunca repete escrita**: a retentativa automática existe só na introspecção e até o `Prepare` (que não tem efeito colateral). Depois do `ExecuteUpdate` não há retry.

---

## Formato de resposta

Markdown compacto (pipe-separated, sem alinhamento e sem linha separadora de cabeçalho) — escolhido para minimizar tokens. Erros viram `ERRO: <mensagem>`.

```
ds_describe_method               ds_call
TSM0977A.RotasAtivasDoCAR        ReturnParameter|Int32|4
NOME|TIPO|DIRECAO
iFKT1C8|Int32|in
ReturnParameter|Int32|ret

ds_servers
NOME|HOST|PORTA|HTTP|AMBIENTE|ESCRITA|STATUS|BANCO|VERSAO|BUILD|DESCRICAO
MD007|127.0.0.1|211|8211|DEV|sim|ok|IGERP|2.379.0.15|DEBUG|MATRIZ - DEV local
[1 linhas]
```

**`BANCO`, `VERSAO` e `BUILD` vêm de `TWeb.GetInfo`**, não do config: `AMBIENTE` é apenas um rótulo digitado pelo operador, enquanto `BANCO` é a evidência confiável de qual base está atrás do servidor. `BUILD=DEBUG` indica que `ds_sql_log` vai funcionar. Servidor sem a classe `TWeb.GetInfo` (caso do MD029) deixa as três colunas vazias — de propósito, sem quebrar a linha.

`ds_describe_class` omite por padrão os métodos herdados de `TServerModuleBase` (`AS_*`, `SetSQL`, `GetLastIG_RECNO`, `ExecCountSql`, `GravarMensagemSistema`, `GetParT007`, `SetCustomSQL`) — existem em todas as classes e só gastariam tokens. `all: true` mostra todos.

---

## Build e instalação

```bat
build.cmd      compila Release/Win32 -> exe\MCP.DSCall.exe
install.cmd    publica em %USERPROFILE%\.claude\mcp\DSCall\
```

`install.cmd` aceita um destino alternativo como primeiro argumento. Ele **nunca sobrescreve o
`MCP.DSCall.json`** — a config tem a senha do DataSnap e os servidores do operador; se não existir,
o próprio exe gera o esqueleto na primeira execução. Também recusa a cópia se o exe estiver em uso
(Claude aberto), em vez de falhar com "acesso negado".

Nenhum dos dois instala nada no Delphi: o projeto é um executável isolado, sem package nem
componente.

### Build pelo Claude (PowerShell — saída enxuta)

```powershell
cmd.exe /c ".\build.cmd" 2>&1 | Select-Object -Last 8
```

Em caso de erro, aumentar `-Last` (ex.: `-Last 30`).

### Por que os .cmd usam `goto` em vez de blocos `if (...)`

O caminho do RAD Studio contém `(x86)` e o `cmd.exe` expande variáveis ao **parsear** o bloco: o
parêntese do caminho fecharia o bloco antes da hora e quebraria o script mesmo quando a condição nem
fosse satisfeita. Por isso as checagens saltam para labels.

E os `.cmd` **precisam estar em CRLF** — com LF puro o `cmd.exe` quebra linhas no meio e reclama de
comandos inexistentes. O `.gitattributes` garante isso.

### Teste do protocolo sem o Claude

Alimentar o exe com linhas JSON-RPC:

```powershell
$linhas = @(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ds_servers","arguments":{}}}'
)
Set-Content -Path "$env:TEMP\t.jsonl" -Value $linhas -Encoding utf8
cmd.exe /c "type `"$env:TEMP\t.jsonl`" | `".\exe\MCP.DSCall.exe`""
```

### Bateria de regressão (leitura pura, segura)

Contra o MD007 em DEV, com os resultados já verificados:

| Chamada | Esperado |
|---|---|
| `TSM0977A.RotasAtivasDoFornecedor 89551` | `1` |
| `TSM0977A.RotasAtivasDoCAR 11225` | `1` |
| `TSM0977A.RotasAtivasDoCAR 328` | `0` |
| `TSM0977A.RotasAtivasDoCAR 2957` | `4` |
| `TSM0977A.RotasAtivasDoCAR 999999` | `0`, sem exceção |

---

## Atualização automática

No startup, antes de subir o loop MCP, consulta o servidor de distribuição interno (`http://127.0.0.1:8016`) com `project=MCP.DSCall` e baixa uma versão mais nova se houver. A nova versão só é exercida na **próxima** execução. Falhas são silenciadas (stderr) e não impedem o servidor de subir.

O `FileVersion` no `VerInfo` do `.dproj` está em `1.0.0.0` — atualizar **manualmente** ao publicar uma nova versão.

---

## Encoding dos fontes

Os `.pas` deste projeto têm **BOM UTF-8**. Sem o BOM o compilador Delphi lê os arquivos como ANSI e os caracteres acentuados das strings chegam corrompidos ao cliente MCP (já aconteceu com o travessão do `SERVER_TITLE`). Ao criar uma unit nova, garantir o BOM. Exceção: `REST.API.pas` é cópia fiel do MCP.DBLink e fica como está lá.

---

## Regras para o Claude

- **Economia de tokens é regra de ouro.** Em qualquer decisão de formato de resposta, log, mensagem de erro ou descrição de tool, escolher a alternativa que consome menos tokens sem comprometer a correção. Para dados tabulares: markdown compacto (pipe-separated) ≈ TSV > CSV > JSON. Medir antes de afirmar ganho.
- **Sempre revisar antes de aplicar.** Para qualquer alteração além de um ajuste trivial, apresentar o plano primeiro — arquivos criados/alterados, dependências novas, impacto no build, riscos — e aguardar aprovação explícita. Vale especialmente para novas units, mudanças no `.dpr`/`.dproj`, novas dependências e nos `.cmd`.
- **Respeitar as fronteiras das camadas.** `src\mcp\` não pode passar a conhecer DataSnap; as tools falam por interface (`IDSIntrospec`, `IDSInvoke`, `IDSLog`), nunca com classes concretas; só o `.dpr` instancia. Uma tool que precise de algo novo pede à interface — não busca a conexão por conta própria.
- **Schema de tool só por `TSchema`.** Nunca voltar a montar JSON de schema concatenando string.
- **Nunca alterar** `MCP.DSCall.json` (configuração do operador, com credenciais).
- **Nunca alterar fontes-base do Delphi/RAD Studio.** Os arquivos sob `C:\Program Files (x86)\Embarcadero\Studio\22.0\source\` são somente leitura — consultar sim, editar jamais. Qualquer correção vai no código do projeto.
- **Não rodar `buildMD007.bat` sem autorização** — ele derruba e reinicia o servidor que o operador pode estar usando.
- Ao invocar um método pela primeira vez, chamar `ds_describe_method` antes: acerta ordem e tipos, e evita a exceção crua do DBX.
- Conferir os efeitos de qualquer escrita pelo **DBLinkDEV** (nunca DBLink, que é produção).
