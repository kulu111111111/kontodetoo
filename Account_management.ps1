# Skript CSV-failist andmete lugemiseks ning lokaalsete kasutajakontode haldamiseks (lisamine ja eemaldamine).

# --- POWERSHELL 7 ÜHILDUVUSE TAGAMINE ---
# Lahendame potentsiaalsed "TelemetryAPI" või "Assembly load" moodulivead uuemates PS versioonides.
# Impordime LocalAccounts mooduli spetsiaalses Windows PowerShell'i (PS5.1) tagasiühilduvusrežiimis.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "Tuvastasin PowerShell 7+. Laen 'LocalAccounts' mooduli ühilduvusrežiimis..." -ForegroundColor DarkGray
    # Puhastame sessiooni ja eemaldame mooduli, kui see on eelnevalt vigaselt mällu laetud
    Get-Module Microsoft.PowerShell.LocalAccounts -ErrorAction SilentlyContinue | Remove-Module -Force
    # Sunniviisiline import -UseWindowsPowerShell parameetriga, et vältida ühilduvusprobleeme
    Import-Module Microsoft.PowerShell.LocalAccounts -UseWindowsPowerShell -ErrorAction Stop
}
# --------------------------------------

# --- MUUTUJAD JA TÖÖKAUSTA MÄÄRAMINE ---
$projectPath = $PSScriptRoot
$sourceFile = Join-Path $projectPath "new-users-accounts.csv" 
$usersGroup = "Users" 

# Veendume, et vajalik algandmetega CSV on olemas
if (-not (Test-Path $sourceFile)) {
    Write-Error "Faili '$sourceFile' ei leitud! Aktiveeri enne esimene skript."
    exit
}

# CSV faili mällu laadimine turvalise try-catch plokiga
try {
    $csvData = Import-Csv -Path $sourceFile -Delimiter ";" -Encoding UTF8
}
catch {
    Write-Error "Viga CSV lugemisel: $_"
    exit
}

# --- KASUTAJA VALIKUMENÜÜ ---
Clear-Host
Write-Host "--- KOHALIKE KASUTAJATE HALDUS ---" -ForegroundColor Cyan
Write-Host "Vali tegevus:"
Write-Host "1. Lisa iga kasutaja CSV failist"
Write-Host "2. Kuva nimekiri ja kustuta valitud kasutaja"
Write-Host "-------------------------"
$choice = Read-Host "Sinu valik (1 või 2)"

switch ($choice) {
    "1" {
        # --- 1. VALIK: UUTE KASUTAJATE LISAMINE SÜSTEEMI ---
        Write-Host "`nAlustan kohalike kasutajate lisamist..." -ForegroundColor Yellow
        $addedUsers = @()

        # Läbime iga rea CSV failis
        foreach ($row in $csvData) {
            $fName = $row.Eesnimi
            $lName = $row.Perenimi
            $userName = $row.Kasutajanimi
            $passwordRaw = $row.Parool
            $originalDesc = $row.Kirjeldus
            $fullName = "$fName $lName"

            $errors = @()
            $statusNote = ""

            # Andmete esmane kontroll ja valideerimine
            if ($userName.Length -gt 20) {
                $errors += "Kasutajanimi liiga pikk ($($userName.Length) > 20)"
            }

            # Väldime topeltkasutajate loomist (kontrollime eksisteerimist)
            if (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue) {
                $errors += "Duplikaat (kasutaja juba olemas)"
            }

            # --- KIRJELDUSE PIKKUSE KONTROLL ---
            # Windows piirab kohaliku kasutaja kirjelduse (Description) pikkust 48 märgiga
            if ($originalDesc.Length -gt 48) {
                $finalDesc = $originalDesc.Substring(0, 48)
                $statusNote = "Kirjelduse pikkust kahandati (orig: $($originalDesc.Length))"
            } else {
                $finalDesc = $originalDesc
            }

            # Vigaste andmetega ridade vahelejätmine ja teavitamine
            if ($errors.Count -gt 0) {
                Write-Warning "EI LISATUD: $fullName ($userName) -> $($errors -join ', ')"
                continue
            }

            # Reaalse Windowsi lokaalse konto genereerimine
            try {
                # Parooli muutmine SecureString formaati, mida New-LocalUser nõuab
                $securePass = ConvertTo-SecureString $passwordRaw -AsPlainText -Force
                
                # Uue lokaalse kasutaja registreerimine süsteemis
                New-LocalUser -Name $userName `
                              -FullName $fullName `
                              -Description $finalDesc `
                              -Password $securePass `
                              -AccountNeverExpires `
                              -ErrorAction Stop | Out-Null
                
                # Õiguste andmine (tavakasutajate gruppi lisamine)
                Add-LocalGroupMember -Group $usersGroup -Member $userName -ErrorAction SilentlyContinue
                
                # Salvestame eduka tegevuse lõppraporti jaoks
                $addedUsers += [PSCustomObject]@{
                    Name = $fullName
                    Username = $userName
                    Notice = if ($statusNote) { $statusNote } else { "OK" }
                }
            }
            catch {
                Write-Error "Viga kasutaja $userName loomisel: $_"
            }
        }

        # Tagasiside ja koondtabeli kuvamine ekraanil
        Write-Host "`n--- TULEMUSED ---" -ForegroundColor Green
        if ($addedUsers.Count -gt 0) {
            $addedUsers | Format-Table -AutoSize
        } else {
            Write-Host "Uusi kasutajaid ei lisatud." -ForegroundColor Gray
        }
    }

    "2" {
        # --- 2. VALIK: KASUTAJA NING KODUKAUSTA EEMALDAMINE ---
        Write-Host "`n--- KASUTAJA KUSTUTAMINE ---" -ForegroundColor Yellow
        
        $existingUsers = @()
        
        # Filtreerime välja need CSV kasutajad, kes on reaalselt arvutis olemas
        foreach ($row in $csvData) {
            if (Get-LocalUser -Name $row.Kasutajanimi -ErrorAction SilentlyContinue) {
                $existingUsers += $row
            }
        }

        # Kui ühtegi vastet ei leitud, pole midagi kustutada
        if ($existingUsers.Count -eq 0) {
            Write-Warning "Ei leitud CSV failis mainitud kasutajat."
            exit
        }

        # Kuvame valikuks saadaolevate kasutajate nimekirja
        for ($i = 0; $i -lt $existingUsers.Count; $i++) {
            $u = $existingUsers[$i]
            Write-Host "$($i+1). $($u.Eesnimi) $($u.Perenimi) ($($u.Kasutajanimi))"
        }

        # Küsitakse kasutaja sisendit õige profiili kustutamiseks
        $delIndex = Read-Host "`nSisesta number, keda kustutada"
        if ($delIndex -match "^\d+$") {
            $index = [int]$delIndex - 1
            
            # Kontrollime, et sisestatud number on nimekirja piires
            if ($index -ge 0 -and $index -lt $existingUsers.Count) {
                $targetUser = $existingUsers[$index].Kasutajanimi
                
                try {
                    # Süsteemist kasutajakonto eemaldamine
                    Remove-LocalUser -Name $targetUser -ErrorAction Stop
                    Write-Host "Kasutaja '$targetUser' kustutatud." -ForegroundColor Green
                    
                    # Kasutaja personaalse profiilikausta (C:\Users\...) täielik eemaldamine
                    $homePath = "C:\Users\$targetUser"
                    if (Test-Path $homePath) {
                        Remove-Item -Path $homePath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host "Kodukaust kustutatud." -ForegroundColor Green
                    }
                } catch {
                    Write-Error "Viga kustutamisel: $_"
                }
            } else { Write-Warning "Vale number." }
        }
    }
}