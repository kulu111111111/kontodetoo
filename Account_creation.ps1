<#
.SYNOPSIS
    Genereerib juhuslikud kasutajad etteantud tekstifailidest (Uuendatud versioon).
.DESCRIPTION
    Loeb andmed failidest, küsib paroolieelistust ning genereerib 5 kasutajat.
    Tulemus salvestatakse CSV faili .NET andmestruktuure ja Regexi kasutades.
#>

# --- SEADISTUS JA FAILIDE ASUKOHAD ---
$tööKaust = $PSScriptRoot

$failEesnimed    = Join-Path $tööKaust "Eesnimed.txt"
$failPerenimed   = Join-Path $tööKaust "Perenimed.txt"
$failKirjeldused = Join-Path $tööKaust "Kirjeldused.txt"
$tulemusFail     = Join-Path $tööKaust "new-users-accounts.csv" 

# --- ABIFUNKTSIOONID ---

# Funktsioon täpitähtede eemaldamiseks kasutades Regex'i (kiirem ja lühem)
function Eemalda-Täpitähed {
    param ([String]$tekst)
    if ([string]::IsNullOrWhiteSpace($tekst)) { return $tekst }
    
    $normaliseeritud = $tekst.Normalize([Text.NormalizationForm]::FormD)
    # Eemaldab kõik diakriitilised märgid (NonSpacingMark)
    $ilmaMärkideta = $normaliseeritud -replace '\p{M}', ''
    return $ilmaMärkideta
}

# --- ETTEVALMISTUS (TESTIMISEKS) ---
# Loob failid lühema süntaksiga, kui neid pole
if (-not (Test-Path $failEesnimed)) {
    Write-Warning "Sisendfaile ei leitud, loon näidisfailid..."
    "Mari-Liis`nJüri`nNadežda`nTõnu`nAnna`nKarl" | Out-File $failEesnimed -Encoding UTF8
    "Männik`nKask`nOja-Pärn`nTamm`nIvanova`nSepp" | Out-File $failPerenimed -Encoding UTF8
    "Loob ja arendab tarkvara`nTegeleb klienditoega`nJuhib osakonna tööd`nHooldab servereid`nRaamatupidaja abi" | Out-File $failKirjeldused -Encoding UTF8
}

# --- PÕHILOOGIKA ---

try {
    $eesnimed    = Get-Content $failEesnimed -Encoding UTF8
    $perenimed   = Get-Content $failPerenimed -Encoding UTF8
    $kirjeldused = Get-Content $failKirjeldused -Encoding UTF8
}
catch {
    Write-Error "Failide laadimine ebaõnnestus! Veendu, et failid eksisteerivad."
    exit
}

# --- KÜSIME PAROOLI EELISTUST ---
Write-Host ("-" * 54)
$sisestatudParool = Read-Host "Sisesta ühine parool (5-8 märki) või vajuta ENTER juhuslikeks"

# Vaikeväärtusena eeldame juhuslikku parooli
$kasutaJuhuslikku = $true

if (-not [string]::IsNullOrWhiteSpace($sisestatudParool)) {
    if ($sisestatudParool.Length -in 5..8) {
        Write-Host "Rakendan kasutaja sisestatud ühist parooli." -ForegroundColor Green
        $kasutaJuhuslikku = $false
    }
    else {
        Write-Warning "Parooli pikkus ($($sisestatudParool.Length) märki) ei ole lubatud vahemikus!"
        Write-Warning "Kasutan turvalisuse tagamiseks automaatset paroolide genereerimist."
    }
}

# CSV hoidla (List on jõ