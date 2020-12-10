@setlocal enableextensions
@echo off

call ant -f ../../build.xml -Dproject=InformationStandard-1-0 -Dtestscripttools.localdir=.. %*
pause