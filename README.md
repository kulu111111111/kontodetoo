kasutajate tegemiseks arvutisse
(powershell skriptid)

see projekt on 2 skripti mis töötavad koos ja teevad kasutajaid.

Esimene teeb lihtsalt nimekirja

Teine teeb PÄRIS kasutajad arvutisse!!

Mis asjad siin on ja mida teevad:
Skript 1: Account_creation.ps1 (generaator)

teeb ise failid (Eesnimed.txt jne) kui sul neid pole mingite suvaliste nimedega

muudab nimed normaalseks kasutajanimeks (nt Jüri -> juri) ja võtab tühikud ära

Paroolid: saad ise panna mingi ühise (aga peab olema 5-8 märki) või skript ise mõtleb mingeid suvalisi paroole välja

salvestab lõpuks new-users-accounts.csv faili et teine skript saaks lugeda

Skript 2: Account_management.ps1 (haldur)

TEEB REAALSED KONTOD (Local Users) sinu arvutisse.

kontrollib asju: ei tee topelt kasutajaid kui juba on olemas arvutis

nime pikkus ei tohi olla üle 20!

kui kirjeldus on liiga pikk siis ta lihtsalt lõikab selle lühemaks (windows ei luba üle 48)

on olemas ka menüü kust saab kustutada kasutajaid ja siis ta kustutab C:\Users kausta ära ka.

Kuidas tööle panna???
NB!! Teine skript vajab administraatori õigusi, muidu ei tööta!

Samm 1. alguses tee nimekiri:

PowerShell
.\Account_creation.ps1
Samm 2. Siis tee kontod (tee powershell adminnina lahti!):

PowerShell
.\Account_management.ps1