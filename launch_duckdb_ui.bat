@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo Project Python environment not found at .venv\Scripts\python.exe
    pause
    exit /b 1
)

".venv\Scripts\python.exe" -u -c "import duckdb, time, webbrowser; con=duckdb.connect(r'data\swapi.duckdb'); con.execute('INSTALL ui'); con.execute('LOAD ui'); con.execute('CALL start_ui_server()'); print('DuckDB UI is running at http://localhost:4213'); webbrowser.open('http://localhost:4213'); time.sleep(86400)"
if errorlevel 1 (
    echo DuckDB UI failed to start. Check the error above.
    pause
)
