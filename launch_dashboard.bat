@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\streamlit.exe" (
    echo Streamlit not found at .venv\Scripts\streamlit.exe
    pause
    exit /b 1
)

echo Starting dashboard at http://localhost:8501 (close this window to stop it)
rem The blank line answers Streamlit's first-run email prompt, which would otherwise block the start.
echo.| ".venv\Scripts\streamlit.exe" run dashboard\app.py
if errorlevel 1 (
    echo Dashboard failed to start. Check the error above.
    pause
)
