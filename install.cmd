@echo off
rem ---------------------------------------------------------------------------
rem  Instalacao do MCP.DSCall
rem
rem  Copia exe\MCP.DSCall.exe para %USERPROFILE%\.claude\mcp\DSCall\ — mesmo
rem  padrao dos outros MCP.*.exe da maquina.
rem
rem  A configuracao (MCP.DSCall.json) NAO e sobrescrita: ela contem a senha do
rem  DataSnap e os servidores do operador. Se ainda nao existir, o proprio exe
rem  gera um esqueleto com MD007 e MD029 na primeira execucao.
rem
rem  Uso: install.cmd            instala em %USERPROFILE%\.claude\mcp\DSCall
rem       install.cmd <destino>  instala na pasta informada
rem ---------------------------------------------------------------------------
setlocal

set "BASE=%~dp0"
set "ORIGEM=%BASE%exe\MCP.DSCall.exe"

if "%~1"=="" (
  set "DESTINO=%USERPROFILE%\.claude\mcp\DSCall"
) else (
  set "DESTINO=%~1"
)

if not exist "%ORIGEM%" (
  echo [ERRO] "%ORIGEM%" nao existe. Rode build.cmd primeiro.
  exit /b 1
)

rem O Claude mantem o MCP rodando enquanto esta aberto, e um exe em execucao
rem fica travado em disco: a copia falharia com "acesso negado" sem explicar.
tasklist /FI "IMAGENAME eq MCP.DSCall.exe" 2>nul | find /I "MCP.DSCall.exe" >nul
if not errorlevel 1 (
  echo [ERRO] MCP.DSCall.exe esta em execucao — provavelmente o Claude esta aberto.
  echo        Feche o Claude Desktop / Claude Code e rode install.cmd de novo.
  exit /b 1
)

if not exist "%DESTINO%" mkdir "%DESTINO%"

echo [1/2] Copiando o binario...
copy /Y "%ORIGEM%" "%DESTINO%\MCP.DSCall.exe" >nul
if errorlevel 1 (
  echo [ERRO] Falha ao copiar para "%DESTINO%".
  exit /b 1
)

echo [2/2] Verificando a configuracao...
if exist "%DESTINO%\MCP.DSCall.json" (
  echo       Config existente preservada.
) else (
  echo       Sem config ainda — sera gerada com MD007 e MD029 na primeira execucao.
)

echo.
echo Instalacao OK
echo   Binario: %DESTINO%\MCP.DSCall.exe
echo   Config.: %DESTINO%\MCP.DSCall.json
echo.
echo Registro no Claude (claude_desktop_config.json ou .claude.json), em mcpServers:
echo.
echo   "DSCall": {
echo     "command": "%DESTINO:\=\\%\\MCP.DSCall.exe"
echo   }
echo.
endlocal
