# Установка локали
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'ru-RU'

# Функция для поиска пути к файлу с индексами
function Find-IndexFilePath {
    $defaultFileName = "hostnames.txt"
    $defaultFolderName = "script"
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root

    foreach ($drive in $drives) {
        $path = Join-Path -Path $drive -ChildPath $defaultFolderName
        if (Test-Path $path) {
            return Join-Path -Path $path -ChildPath $defaultFileName
        }
    }

    # Если папка script не найдена, возвращаем путь по умолчанию
    return "D:\script\hostnames.txt"
}

# Определяем путь к файлу с индексами
$defaultIndexFilePath = Find-IndexFilePath
$indexFilePath = Read-Host "Введите путь к файлу для хранения индексов хостнеймов [по умолчанию: $defaultIndexFilePath]"

# Если пользователь нажал Enter без ввода, используем значение по умолчанию
if ([string]::IsNullOrWhiteSpace($indexFilePath)) {
    $indexFilePath = $defaultIndexFilePath
}

# Проверяем, существует ли файл индексов
if (-Not (Test-Path $indexFilePath)) {
    # Если файл не существует, создаем его и начинаем с индекса 1
    Write-Host "Файл индексов не найден. Создание нового файла..."
    Set-Content -Path $indexFilePath -Value "1"
}

# Функция для чтения первого доступного индекса из файла
function Get-FirstAvailableIndex {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
        if ($content.Count -gt 0) {
            # Возвращаем первый индекс
            return [int]$content[0]
        }
    }
    return 1 # Возвращаем 1, если файл пуст или поврежден
}

# Функция для обновления файла после использования индекса
function Update-IndexFile {
    param (
        [string]$filePath,
        [int]$usedIndex
    )
    $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    # Удаляем использованный индекс
    $remainingIndexes = $content | Where-Object { $_ -ne $usedIndex.ToString() }
    # Сохраняем оставшиеся индексы обратно в файл
    Set-Content -Path $filePath -Value $remainingIndexes
}

# --- Выбор хостнейма ---
Write-Host "Выберите префикс хостнейма:"
Write-Host "[1] s21ws"
Write-Host "[2] crl-slpw"
Write-Host "[3] Указать свой вариант индекса"
Write-Host "[4] Не менять"
$hostnameChoice = Read-Host "Введите номер варианта"

switch ($hostnameChoice) {
    "1" { $hostnamePrefix = "s21ws" }
    "2" { $hostnamePrefix = "crl-slpw" }
    "3" { $hostnamePrefix = Read-Host "Введите свой вариант префикса" }
    "4" { $hostnamePrefix = $null } # Не менять имя
    default { $hostnamePrefix = "s21ws" } # По умолчанию
}

# Если выбрано изменение имени компьютера
if ($hostnamePrefix) {
    # Получаем первый доступный индекс
    $nextIndex = Get-FirstAvailableIndex -filePath $indexFilePath

    # Генерируем новое имя компьютера
    $newComputerName = "{0}{1:D3}" -f $hostnamePrefix, $nextIndex

    # Выводим информацию о новом имени
    Write-Host "Текущее имя компьютера будет изменено на: $newComputerName"

    # Меняем имя компьютера
    try {
        Rename-Computer -NewName $newComputerName -Force
        Write-Host "Имя компьютера успешно изменено на $newComputerName."
    } catch {
        Write-Host "Ошибка при изменении имени компьютера: $_" -ForegroundColor Red
    }

    # Обновляем файл индексов после использования индекса
    Update-IndexFile -filePath $indexFilePath -usedIndex $nextIndex
} else {
    Write-Host "Имя компьютера оставлено без изменений."
}

# --- Удаление пользователей ---
Write-Host "Удаление пользователей:"
Write-Host "[1] Удалить пользователя 'deleted'"
Write-Host "[2] Просмотреть список всех пользователей и выбрать для удаления"
Write-Host "[3] Пропустить"
$userDeletionChoice = Read-Host "Введите номер варианта"

if ($userDeletionChoice -eq "1") {
    $accountName = "deleted"
    try {
        $user = Get-LocalUser -Name $accountName -ErrorAction SilentlyContinue
        if ($user) {
            Remove-LocalUser -Name $accountName -Confirm:$false
            Write-Host "Учетная запись '$accountName' успешно удалена."
        } else {
            Write-Host "Учетная запись '$accountName' не найдена."
        }
    } catch {
        Write-Host "Ошибка при удалении учетной записи '$accountName': $_" -ForegroundColor Red
    }
} elseif ($userDeletionChoice -eq "2") {
    # Получаем список всех локальных пользователей
    $allUsers = Get-LocalUser | Where-Object { $_.Name -ne "Administrator" -and $_.Name -ne "DefaultAccount" -and $_.Name -ne "Guest" }
    if ($allUsers.Count -eq 0) {
        Write-Host "Нет доступных пользователей для удаления." -ForegroundColor Yellow
    } else {
        Write-Host "Список доступных пользователей для удаления:"
        $userList = @()
        $index = 1
        foreach ($user in $allUsers) {
            Write-Host "[$index] $($user.Name)"
            $userList += $user.Name
            $index++
        }
        Write-Host "[0] Пропустить" # Добавляем опцию "Пропустить"

        # Предлагаем выбрать пользователей для удаления
        $selectedUsers = Read-Host "Введите номера пользователей через запятую (например, 1,3,5)"
        if ($selectedUsers -eq "0") {
            Write-Host "Пропуск удаления пользователей."
        } else {
            $selectedIndices = $selectedUsers.Split(",") | ForEach-Object { [int]$_ }
            foreach ($index in $selectedIndices) {
                if ($index -ge 1 -and $index -le $userList.Count) {
                    $userName = $userList[$index - 1]
                    try {
                        Remove-LocalUser -Name $userName -Confirm:$false
                        Write-Host "Учетная запись '$userName' успешно удалена."
                    } catch {
                        Write-Host "Ошибка при удалении учетной записи '$userName': $_" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Неверный номер: $index. Пропуск." -ForegroundColor Yellow
                }
            }
        }
    }
} elseif ($userDeletionChoice -eq "3") {
    Write-Host "Пропуск удаления пользователей."
}

# --- Создание учетной записи с правами администратора ---
Write-Host "Создание учетной записи с правами администратора:"
Write-Host "[1] Создать пользователя 'master'"
Write-Host "[2] Указать свое имя пользователя"
Write-Host "[3] Пропустить"
$adminAccountChoice = Read-Host "Введите номер варианта"

if ($adminAccountChoice -eq "1") {
    $newAdminUser = "master"
} elseif ($adminAccountChoice -eq "2") {
    $newAdminUser = Read-Host "Введите имя пользователя"
} else {
    $newAdminUser = $null
}

if ($newAdminUser) {
    try {
        # Проверяем, существует ли пользователь
        $existingUser = Get-LocalUser -Name $newAdminUser -ErrorAction SilentlyContinue

        if ($existingUser) {
            Write-Host "Пользователь '$newAdminUser' уже существует."
        } else {
            # Создаем учетную запись без пароля
            New-LocalUser -Name $newAdminUser

            # Устанавливаем флаг "Пароль никогда не истекает"
            Set-LocalUser -Name $newAdminUser -PasswordNeverExpires $true

            # Определяем имя группы администраторов в зависимости от локализации
            $culture = (Get-Culture).Name
            if ($culture -eq "ru-RU") {
                $adminGroup = "Администраторы"  # Для русской локализации
            } else {
                $adminGroup = "Administrators" # Для английской локализации
            }

            # Добавляем пользователя в группу администраторов
            Add-LocalGroupMember -Group $adminGroup -Member $newAdminUser

            Write-Host "Пользователь '$newAdminUser' успешно создан и добавлен в группу администраторов."
        }
    } catch {
        Write-Host "Ошибка при создании пользователя '$newAdminUser': $_" -ForegroundColor Red
    }
} else {
    Write-Host "Пропуск создания учетной записи."
}

# --- Перезагрузка компьютера ---
Write-Host "Для применения изменений требуется перезагрузка компьютера."
$confirmRestart = Read-Host "Хотите перезагрузить компьютер сейчас? (Y/N)"

# Проверяем ответ пользователя
if ($confirmRestart -eq 'Y' -or $confirmRestart -eq 'y') {
    Restart-Computer -Force
} else {
    Write-Host "Перезагрузка отменена. Изменения вступят в силу после ручной перезагрузки."
}