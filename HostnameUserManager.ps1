# ��������� ������
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'ru-RU'

# ������� ��� ������ ���� � ����� � ���������
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

    # ���� ����� script �� �������, ���������� ���� �� ���������
    return "D:\script\hostnames.txt"
}

# ���������� ���� � ����� � ���������
$defaultIndexFilePath = Find-IndexFilePath
$indexFilePath = Read-Host "������� ���� � ����� ��� �������� �������� ���������� [�� ���������: $defaultIndexFilePath]"

# ���� ������������ ����� Enter ��� �����, ���������� �������� �� ���������
if ([string]::IsNullOrWhiteSpace($indexFilePath)) {
    $indexFilePath = $defaultIndexFilePath
}

# ���������, ���������� �� ���� ��������
if (-Not (Test-Path $indexFilePath)) {
    # ���� ���� �� ����������, ������� ��� � �������� � ������� 1
    Write-Host "���� �������� �� ������. �������� ������ �����..."
    Set-Content -Path $indexFilePath -Value "1"
}

# ������� ��� ������ ������� ���������� ������� �� �����
function Get-FirstAvailableIndex {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
        if ($content.Count -gt 0) {
            # ���������� ������ ������
            return [int]$content[0]
        }
    }
    return 1 # ���������� 1, ���� ���� ���� ��� ���������
}

# ������� ��� ���������� ����� ����� ������������� �������
function Update-IndexFile {
    param (
        [string]$filePath,
        [int]$usedIndex
    )
    $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    # ������� �������������� ������
    $remainingIndexes = $content | Where-Object { $_ -ne $usedIndex.ToString() }
    # ��������� ���������� ������� ������� � ����
    Set-Content -Path $filePath -Value $remainingIndexes
}

# --- ����� ��������� ---
Write-Host "�������� ������� ���������:"
Write-Host "[1] s21ws"
Write-Host "[2] crl-slpw"
Write-Host "[3] ������� ���� ������� �������"
Write-Host "[4] �� ������"
$hostnameChoice = Read-Host "������� ����� ��������"

switch ($hostnameChoice) {
    "1" { $hostnamePrefix = "s21ws" }
    "2" { $hostnamePrefix = "crl-slpw" }
    "3" { $hostnamePrefix = Read-Host "������� ���� ������� ��������" }
    "4" { $hostnamePrefix = $null } # �� ������ ���
    default { $hostnamePrefix = "s21ws" } # �� ���������
}

# ���� ������� ��������� ����� ����������
if ($hostnamePrefix) {
    # �������� ������ ��������� ������
    $nextIndex = Get-FirstAvailableIndex -filePath $indexFilePath

    # ���������� ����� ��� ����������
    $newComputerName = "{0}{1:D3}" -f $hostnamePrefix, $nextIndex

    # ������� ���������� � ����� �����
    Write-Host "������� ��� ���������� ����� �������� ��: $newComputerName"

    # ������ ��� ����������
    try {
        Rename-Computer -NewName $newComputerName -Force
        Write-Host "��� ���������� ������� �������� �� $newComputerName."
    } catch {
        Write-Host "������ ��� ��������� ����� ����������: $_" -ForegroundColor Red
    }

    # ��������� ���� �������� ����� ������������� �������
    Update-IndexFile -filePath $indexFilePath -usedIndex $nextIndex
} else {
    Write-Host "��� ���������� ��������� ��� ���������."
}

# --- �������� ������������� ---
Write-Host "�������� �������������:"
Write-Host "[1] ������� ������������ 'deleted'"
Write-Host "[2] ����������� ������ ���� ������������� � ������� ��� ��������"
Write-Host "[3] ����������"
$userDeletionChoice = Read-Host "������� ����� ��������"

if ($userDeletionChoice -eq "1") {
    $accountName = "deleted"
    try {
        $user = Get-LocalUser -Name $accountName -ErrorAction SilentlyContinue
        if ($user) {
            Remove-LocalUser -Name $accountName -Confirm:$false
            Write-Host "������� ������ '$accountName' ������� �������."
        } else {
            Write-Host "������� ������ '$accountName' �� �������."
        }
    } catch {
        Write-Host "������ ��� �������� ������� ������ '$accountName': $_" -ForegroundColor Red
    }
} elseif ($userDeletionChoice -eq "2") {
    # �������� ������ ���� ��������� �������������
    $allUsers = Get-LocalUser | Where-Object { $_.Name -ne "Administrator" -and $_.Name -ne "DefaultAccount" -and $_.Name -ne "Guest" }
    if ($allUsers.Count -eq 0) {
        Write-Host "��� ��������� ������������� ��� ��������." -ForegroundColor Yellow
    } else {
        Write-Host "������ ��������� ������������� ��� ��������:"
        $userList = @()
        $index = 1
        foreach ($user in $allUsers) {
            Write-Host "[$index] $($user.Name)"
            $userList += $user.Name
            $index++
        }
        Write-Host "[0] ����������" # ��������� ����� "����������"

        # ���������� ������� ������������� ��� ��������
        $selectedUsers = Read-Host "������� ������ ������������� ����� ������� (��������, 1,3,5)"
        if ($selectedUsers -eq "0") {
            Write-Host "������� �������� �������������."
        } else {
            $selectedIndices = $selectedUsers.Split(",") | ForEach-Object { [int]$_ }
            foreach ($index in $selectedIndices) {
                if ($index -ge 1 -and $index -le $userList.Count) {
                    $userName = $userList[$index - 1]
                    try {
                        Remove-LocalUser -Name $userName -Confirm:$false
                        Write-Host "������� ������ '$userName' ������� �������."
                    } catch {
                        Write-Host "������ ��� �������� ������� ������ '$userName': $_" -ForegroundColor Red
                    }
                } else {
                    Write-Host "�������� �����: $index. �������." -ForegroundColor Yellow
                }
            }
        }
    }
} elseif ($userDeletionChoice -eq "3") {
    Write-Host "������� �������� �������������."
}

# --- �������� ������� ������ � ������� �������������� ---
Write-Host "�������� ������� ������ � ������� ��������������:"
Write-Host "[1] ������� ������������ 'master'"
Write-Host "[2] ������� ���� ��� ������������"
Write-Host "[3] ����������"
$adminAccountChoice = Read-Host "������� ����� ��������"

if ($adminAccountChoice -eq "1") {
    $newAdminUser = "master"
} elseif ($adminAccountChoice -eq "2") {
    $newAdminUser = Read-Host "������� ��� ������������"
} else {
    $newAdminUser = $null
}

if ($newAdminUser) {
    try {
        # ���������, ���������� �� ������������
        $existingUser = Get-LocalUser -Name $newAdminUser -ErrorAction SilentlyContinue

        if ($existingUser) {
            Write-Host "������������ '$newAdminUser' ��� ����������."
        } else {
            # ������� ������� ������ ��� ������
            New-LocalUser -Name $newAdminUser

            # ������������� ���� "������ ������� �� ��������"
            Set-LocalUser -Name $newAdminUser -PasswordNeverExpires $true

            # ���������� ��� ������ ��������������� � ����������� �� �����������
            $culture = (Get-Culture).Name
            if ($culture -eq "ru-RU") {
                $adminGroup = "��������������"  # ��� ������� �����������
            } else {
                $adminGroup = "Administrators" # ��� ���������� �����������
            }

            # ��������� ������������ � ������ ���������������
            Add-LocalGroupMember -Group $adminGroup -Member $newAdminUser

            Write-Host "������������ '$newAdminUser' ������� ������ � �������� � ������ ���������������."
        }
    } catch {
        Write-Host "������ ��� �������� ������������ '$newAdminUser': $_" -ForegroundColor Red
    }
} else {
    Write-Host "������� �������� ������� ������."
}

# --- ������������ ���������� ---
Write-Host "��� ���������� ��������� ��������� ������������ ����������."
$confirmRestart = Read-Host "������ ������������� ��������� ������? (Y/N)"

# ��������� ����� ������������
if ($confirmRestart -eq 'Y' -or $confirmRestart -eq 'y') {
    Restart-Computer -Force
} else {
    Write-Host "������������ ��������. ��������� ������� � ���� ����� ������ ������������."
}