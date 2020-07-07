@setlocal enableextensions
@echo off

call ant -f ..\_ant\build.xml -q -Dproject=Questionnaires-1-0-0 -DoutputXisInternal=true

pause