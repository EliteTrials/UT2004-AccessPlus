@echo off

for %%* in (.) do set project_name=%%~n*

title %project_name%
color 0F

echo.
echo Deleting compiled files %project_name%
echo.
cd..
cd system
del %project_name%.u
del %project_name%.ucl
del %project_name%.int

ucc.exe MakeCommandletUtils.EditPackagesCommandlet 1 %project_name%
ucc.exe editor.MakeCommandlet
ucc.exe MakeCommandletUtils.EditPackagesCommandlet 0 %project_name%
pause