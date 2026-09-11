# MCP.DSCall

Servidor MCP (Model Context Protocol) em Delphi que expõe os **server methods do IGERP** (DataSnap) ao Claude — introspecção e invocação direta, sem passar pela tela Delphi.

## O que faz

- **Tools MCP sobre stdio** (JSON-RPC 2.0) consumíveis pelo Claude Desktop / Claude Code.
- **Chamada de server method** por DBX/TCP — o único protocolo que o IGERP aceita para isso. A porta HTTP do servidor **não** é DataSnap REST: serve apenas as classes `TWeb`.
- **Introspecção** das classes e métodos publicados, com a assinatura real obtida do próprio servidor.
- **Observabilidade de SQL**: `com_sql` limpa o log do servidor, executa o método e devolve o script que ele montou.
- **Múltiplos servidores** num array de configuração, com guarda de escrita por servidor.

## Tools expostas

| Tool | Descrição |
|------|-----------|
| `ds_servers` | Servidores cadastrados, ambiente, permissão de escrita e status de conexão. |
| `ds_classes` | Classes publicadas no servidor, filtráveis por substring. |
| `ds_describe_class` | Métodos de uma classe + `LifeCycle` (omite os herdados de `TServerModuleBase`). |
| `ds_describe_method` | Assinatura real: nome, tipo e direção de cada parâmetro. Não executa nada. |
| `ds_call` | Invoca o server method. Recusado em servidor com `allow_write: false`. |
| `ds_sql_log` | Scripts SQL executados recentemente pelo servidor. |

Respostas em **markdown compacto** (pipe-separated, sem alinhamento) para minimizar tokens. Erros viram `ERRO: <mensagem>`.

## Requisitos

- Windows + RAD Studio 22.0 (Delphi 11 Alexandria)
- Um servidor DataSnap do IGERP no ar (MD007 / MD029)
- Nenhuma unit do IGERP — o projeto compila isolado, só com RTL/DataSnap

## Arquitetura

```
src\mcp\    protocolo MCP — não conhece DataSnap (IMCPTool, registro, transporte, servidor)
src\ds\     domínio DataSnap (config, conexões, tipos, log, introspecção, invocação)
src\tools\  uma unit por tool, ligada ao domínio só por interface
src\util\   tabela markdown, auto-update, cliente HTTP
```

O `.dpr` é o **composition root**: o único ponto que instancia classes concretas e monta o grafo.
Acrescentar uma tool é criar a unit e registrá-la lá — o servidor não muda.

Leitura (`IDSIntrospec`) e escrita (`IDSInvoke`) são interfaces separadas de propósito: a primeira
pode ser repetida após reconexão, a segunda não.

## Build e instalação

```bat
build.cmd      compila Release/Win32 -> exe\MCP.DSCall.exe
install.cmd    publica em %USERPROFILE%\.claude\mcp\DSCall\
```

`install.cmd` aceita um destino alternativo como argumento e **nunca sobrescreve** o
`MCP.DSCall.json` existente. Nenhum dos dois instala nada no Delphi — o projeto é um executável
isolado, sem package nem componente.

Depois de instalar, registre em `mcpServers`:

```json
"DSCall": { "command": "C:\\Users\\<voce>\\.claude\\mcp\\DSCall\\MCP.DSCall.exe" }
```

## Configuração

Na **primeira execução**, se `MCP.DSCall.json` não existir, o programa cria um ao lado do executável **já com os servidores MD007 e MD029 de DEV cadastrados** e aborta com mensagem orientando a conferir.

```json
{
  "servers": [
    {
      "name": "MD007",
      "description": "MATRIZ - DEV local",
      "host": "127.0.0.1",
      "port": 211,
      "http_port": 0,
      "user": "ADMIN",
      "password": "ADMIN;DEV;DSConnection",
      "environment": "DEV",
      "allow_write": true,
      "default": true
    }
  ],
  "mcp": { "timeout_ms": 30000, "sql_log_max": 20 }
}
```

- `name` é a chave usada no argumento `server` das tools. **O array é a allowlist**: nenhum host fora dele é alcançável.
- `http_port: 0` deriva a porta HTTP como `'8' + port` (regra do `DS.Config.pas` do IGERP).
- `default: true` marca o servidor usado quando a tool omite `server`.
- `allow_write: false` bloqueia `ds_call` naquele servidor; a introspecção continua liberada.

O arquivo contém a senha do DataSnap e está no `.gitignore` — não versionar.

## Segurança

`ds_call` executa **código de negócio real com a sessão ADMIN** e pode gravar no banco. O nome do método não indica o efeito (`CadastroCAR` só consulta; `DefinirPrincipal` grava). Antes de invocar algo que possa gravar: capturar o estado pelo DBLinkDEV, chamar, conferir e restaurar. Confirme o ambiente com `ds_servers` antes de qualquer escrita.

## Documentação

- [CLAUDE.md](CLAUDE.md) — como o Claude deve trabalhar neste projeto.
- `D:\000-Claude\DSCall\ESPECIFICACAO-MCP-DATASNAP-IGERP.md` — a investigação que originou o projeto.
