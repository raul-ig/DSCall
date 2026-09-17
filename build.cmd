@echo off
rem ---------------------------------------------------------------------------
rem  Build do MCP.DSCall (Delphi 11 Alexandria / BDS 22.0)
rem
rem  Uso: build.cmd            compila DEBUG   (padrao — para desenvolver/testar)
rem       build.cmd release    compila RELEASE (para publicar)
rem
rem  POR QUE DEBUG E O PADRAO: a constante MD016 (servidor de auto-update) muda
rem  conforme a diretiva. Em RELEASE ela aponta para PRODUCAO, porque o exe
rem  publicado precisa se atualizar de la. Como esse GET roda a cada execucao do
rem  MCP, compilar Release para testar faria toda sessao de teste bater em
rem  producao. Por isso o padrao aqui e Debug, e Release exige ser pedido.
rem
rem  Gera exe\MCP.DSCall.exe. Nao instala nada no Delphi: o projeto e um
rem  executavel isolado, sem package nem componente.
rem
rem  NOTA: as checagens usam "goto" em vez de blocos "if (...)" de proposito.
rem  O caminho do RAD Studio contem "(x86)" e o cmd expande as variaveis ao
rem  PARSEAR o bloco: o parentese do caminho fecharia o bloco antes da hora,
rem  quebrando o script mesmo quando a condicao nem e satisfeita.
rem ---------------------------------------------------------------------------
setlocal

set "ROOT=C:\Program Files (x86)\Embarcadero\Studio\22.0"
set "BASE=%~dp0"
set "PROJETO=%BASE%MCP.DSCall.dproj"
set "SAIDA=%BASE%exe\MCP.DSCall.exe"

set "CONFIG=Debug"
set "DISTRIB=127.0.0.1:8016 (local)"
if /I "%~1"=="release" set "CONFIG=Release"
if /I "%~1"=="release" set "DISTRIB=10.0.2.228:8016 (PRODUCAO)"

if not exist "%ROOT%\bin\rsvars.bat" goto :sem_delphi
if not exist "%PROJETO%" goto :sem_projeto

rem Um exe em execucao fica travado em disco e o link falha com uma mensagem
rem que nao deixa claro o motivo. Encerrar antes e mais honesto que falhar.
taskkill /IM "MCP.DSCall.exe" /T /F >nul 2>&1

if not exist "%BASE%exe" mkdir "%BASE%exe"
if not exist "%BASE%dcu" mkdir "%BASE%dcu"

echo [1/2] Preparando o ambiente do compilador...
call "%ROOT%\bin\rsvars.bat" >nul
if errorlevel 1 goto :sem_rsvars

echo [2/2] Compilando %CONFIG%^|Win32...
msbuild "%PROJETO%" /t:Build /p:config=%CONFIG% /p:platform=Win32 /v:minimal /nologo
if errorlevel 1 goto :falhou

if not exist "%SAIDA%" goto :sem_saida

echo.
echo Build OK
echo   Binario....: %SAIDA%
echo   Config.....: %CONFIG%
echo   Auto-update: %DISTRIB%
echo.
if /I "%CONFIG%"=="Release" goto :aviso_release
echo   Para publicar, rode: build.cmd release
endlocal
exit /b 0

:aviso_release
echo   ATENCAO: binario de PUBLICACAO. O auto-update deste exe aponta para
echo            producao. Nao use para testar.
endlocal
exit /b 0

:sem_delphi
echo [ERRO] RAD Studio 22.0 nao encontrado em:
echo        %ROOT%
endlocal
exit /b 1

:sem_projeto
echo [ERRO] Projeto nao encontrado:
echo        %PROJETO%
endlocal
exit /b 1

:sem_rsvars
echo [ERRO] Falha ao carregar rsvars.bat.
endlocal
exit /b 1

:falhou
echo.
echo [ERRO] Build falhou.
endlocal
exit /b 1

:sem_saida
echo [ERRO] Build terminou sem erro mas o binario nao existe:
echo        %SAIDA%
endlocal
exit /b 1
