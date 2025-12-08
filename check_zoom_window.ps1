# Zoom 창 정보 확인
Get-Process -Name "Zoom" -ErrorAction SilentlyContinue | Select-Object Id, MainWindowTitle, Path
