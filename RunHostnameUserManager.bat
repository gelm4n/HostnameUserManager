@echo off
setlocal enabledelayedexpansion

:: Установка кодировки консоли на UTF-8
chcp 65001 >nul

:: Инициализация переменной для хранения пути к скрипту
set "scriptPath="

:: Перебираем все доступные диски
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\script\HostnameUserManager.ps1" (
        set "scriptPath=%%D:\script\HostnameUserManager.ps1"
        goto :found
    )
)

:: Если скрипт не найден
if not defined scriptPath (
    echo Скрипт HostnameUserManager.ps1 не найден ни на одном диске.
    pause
    exit /b 1
)

:found
:: Запуск скрипта PowerShell
echo Найден скрипт: %scriptPath%
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%scriptPath%"
pause