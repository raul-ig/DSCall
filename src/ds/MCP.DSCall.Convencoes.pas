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
    'OBRIGATORIO. Nome do servidor no MCP.DSCall.json (ex MD007, MD029). ' +
    'NAO existe servidor padrao: a escolha e sempre explicita, porque o protocolo e identico em ' +
    'DEV e producao e um alvo assumido por omissao so apareceria depois do efeito. ' +
    'Use ds_servers para ver os cadastrados; nomes fora do config sao recusados.';

  // Formato de uma rota no catalogo. Repetido nas descricoes das tools de
  // catalogo para que qualquer cliente MCP saiba preencher sem adivinhar.
  CATALOGO_FORMATO =
    ' FORMATO DA ROTA (objeto JSON): ' +
    '{"verbo":"GET|POST|PUT|DELETE", ' +
    '"descricao":"o que a rota faz, em uma frase", ' +
    '"efeito":"leitura|escrita|processamento", ' +
    '"query":[{"nome":"...","tipo":"string|integer|boolean|date","obrigatorio":true,"exemplo":"...","descricao":"..."}], ' +
    '"body":"exemplo do corpo JSON, quando houver", ' +
    '"resposta":"exemplo da resposta, quando conhecido", ' +
    '"observacoes":"o que surpreenderia quem chama a rota pela primeira vez", ' +
    '"status":"rascunho|validado"}. ' +
    'O campo EFEITO e o mais importante e nao pode ser deduzido do verbo: nestas APIs existe rota GET ' +
    'que PROCESSA (gera documento, dispara integracao). Marque "processamento" sempre que a rota fizer ' +
    'mais do que devolver dados, e "escrita" quando ela alterar cadastro. Na duvida, NAO marque leitura. ' +
    'STATUS: use "rascunho" enquanto a rota foi apenas lida de um fonte ou inferida, e "validado" somente ' +
    'depois de ter sido chamada com sucesso — assim quem consulta o catalogo sabe em que confiar.';

  // Politica de execucao das tools REST.
  REST_CONFIRMACAO =
    ' NUNCA CHAME UMA ROTA SEM PEDIDO EXPLICITO DO USUARIO. Nao chame para "conferir", "validar" ou ' +
    '"testar se funciona" por iniciativa propria, e nao encadeie chamadas a partir de um resultado. ' +
    'O verbo GET NAO garante leitura nestas APIs: ha rotas GET que processam e geram efeito real. ' +
    'Na duvida, pergunte ao usuario antes de executar.';

implementation

end.
