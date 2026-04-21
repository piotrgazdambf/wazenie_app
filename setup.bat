@echo off
echo.
echo ============================================================
echo   System Wazenia - Flutter Project Setup
echo ============================================================
echo.

:: Sprawdz Flutter
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [BLAD] Flutter nie jest zainstalowany!
    echo.
    pause
    exit /b 1
)

echo [OK] Flutter znaleziony
flutter --version

:: Utworz katalog assets
if not exist "assets\images" mkdir "assets\images"

:: Generuj platformowy boilerplate w katalogu tymczasowym
set "PROJECT_DIR=%~dp0"
set "TEMP_PROJ=%TEMP%\wazenie_setup_%RANDOM%"
echo.
echo [1/4] Generuje platform boilerplate...
mkdir "%TEMP_PROJ%" 2>nul
cd /d "%TEMP_PROJ%"
flutter create --project-name wazenie_app --org pl.gazda.wazenie --platforms web,android . >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [BLAD] Nie udalo sie uruchomic flutter create
    pause
    exit /b 1
)
echo [OK] Boilerplate wygenerowany

:: Skopiuj platformowe katalogi
echo.
echo [2/4] Kopiuje platformowe katalogi...
if not exist "%PROJECT_DIR%android" (
    xcopy /E /I /Q "%TEMP_PROJ%\android" "%PROJECT_DIR%android\"
    echo [OK] android/
)
if not exist "%PROJECT_DIR%web" (
    xcopy /E /I /Q "%TEMP_PROJ%\web" "%PROJECT_DIR%web\"
    echo [OK] web/
)
if not exist "%PROJECT_DIR%test" (
    xcopy /E /I /Q "%TEMP_PROJ%\test" "%PROJECT_DIR%test\"
    echo [OK] test/
)
if not exist "%PROJECT_DIR%.gitignore" (
    copy "%TEMP_PROJ%\.gitignore" "%PROJECT_DIR%\" >nul
)
if not exist "%PROJECT_DIR%.metadata" (
    copy "%TEMP_PROJ%\.metadata" "%PROJECT_DIR%\" >nul
)

:: Cleanup
rmdir /S /Q "%TEMP_PROJ%" 2>nul

:: Wróc do katalogu projektu
cd /d "%PROJECT_DIR%"

:: Instalacja zaleznosci
echo.
echo [3/4] Instaluje zaleznosci (flutter pub get)...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [BLAD] flutter pub get nie powiodlo sie
    pause
    exit /b 1
)
echo [OK] Zaleznosci zainstalowane

echo.
echo [4/4] Weryfikacja projektu...
flutter analyze --no-fatal-infos >nul 2>&1
echo [OK] Analiza zakonczona

echo.
echo ============================================================
echo   Setup zakonczony pomyslnie!
echo ============================================================
echo.
echo NASTEPNE KROKI:
echo.
echo 1. Utworz projekt Firebase
echo 2. Wygeneruj firebase_options.dart
echo 3. Ustaw reguly Firestore
echo 4. Uruchom aplikacje: flutter run -d chrome
echo.
pause
