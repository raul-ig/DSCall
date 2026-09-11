// Raul Pavanelli/Claude - 10/09/2026
// Textos de convencao embutidos nas descricoes das tools.
//
// Ficam aqui, e nao no CLAUDE.md, porque precisam valer em QUALQUER cliente
// MCP: o agente que consome este servidor pode nao ter acesso ao repositorio.
unit MCP.DSCall.Convencoes;

interface

const
  // Ciclo de trabalho obrigatorio ao testar alteracao de server method.
  WORKFLOW =
    ' CICLO DE TRABALHO (sempre valido): (1) Apos alterar qualquer SM*.pas e OBRIGATORIO rodar ' +
    'buildMD007.bat (ou buildMD029.bat), em D:\GIT\IGERP, antes de chamar — o .bat mata e reinicia o servidor; ' +
    'sem isso o binario no ar e o antigo e a chamada testa codigo velho SILENCIOSAMENTE, sem erro nenhum. ' +
    '(2) Confirmar com ds_describe_class que o metodo novo aparece — e a prova de que o servidor certo subiu. ' +
    '(3) Chamar com ds_call, de preferencia com com_sql=true para ver o SQL que o servidor montou. ' +
    '(4) Conferir os efeitos no banco por outro canal (MCP DBLinkDEV). ' +
    'EFEITO COLATERAL: o nome do metodo NAO indica se ele grava — CadastroCAR so consulta apesar do nome, ' +
    'DefinirPrincipal grava. Antes de invocar um metodo que possa gravar, capturar o estado pelo DBLinkDEV, ' +
    'chamar, conferir e restaurar. As chamadas rodam com a sessao ADMIN e executam codigo de negocio real. ' +
    'ALVO: conferir com ds_servers qual banco esta atras do servidor antes de qualquer escrita.';

  // Formato de resposta comum as tools tabulares.
  FORMATO_RESPOSTA =
    ' Resposta em markdown compacto (pipe-separated): 1a linha = colunas separadas por |, ' +
    'demais = dados. Rodape "[N linhas]". Em erro: "ERRO: <mensagem>".';

  // Descricao do argumento "server", repetido em todas as tools.
  ARG_SERVER =
    'Nome do servidor no MCP.DSCall.json (ex MD007, MD029). Omitido = o marcado como default. ' +
    'Nomes fora do config sao recusados — o array de servidores e a allowlist.';

implementation

end.
