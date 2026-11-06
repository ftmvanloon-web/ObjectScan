# ObjectScan — objecten scannen met iPhone en Windows

Een klein SwiftUI-project voor iPhone met LiDAR. De app gebruikt **Apple Object Capture**: foto’s, dieptegegevens en begeleide opname worden samen gebruikt voor een 3D-model. De reconstructie gebeurt op de iPhone. Scans hebben geen exportlimiet of betaalmuur.

**Status:** startproject. De broncode is hier op syntaxis en projectstructuur gecontroleerd. Een Xcode-build en een test op een echte iPhone zijn nog nodig. Er zit daarom nog geen installeerbare IPA in dit broncodepakket. De meegeleverde GitHub Actions-workflow maakt die IPA.

Open `START-HIER.html` voor de volledige Nederlandse handleiding voor Windows.

## Wat de eerste versie bevat

- Begeleide herkenning van het object en een instelbaar kader.
- Automatische foto-opname tijdens het rondlopen, handmatige extra foto’s en meerdere rondes.
- Feedback over onder meer afstand, licht en beweging.
- Lokale reconstructie met `PhotogrammetrySession` en het op iOS ondersteunde detailniveau `.reduced`.
- USDZ met geometrie en textuur, een bibliotheek en voorvertoning via Quick Look.
- Export via het gewone iOS-deelmenu naar bijvoorbeeld Bestanden.
- Bronbeelden en checkpoints blijven bewaard. Na een onderbroken berekening kan een volledig afgeronde opname opnieuw worden verwerkt.
- Verwijderen van een scan, inclusief bronbeelden, vraagt bevestiging.

## Bouwen zonder eigen Mac

1. Maak een GitHub-repository en upload de **inhoud** van deze map, inclusief `.github`.
2. Kies een openbare repository als je de gratis standaardrunners zonder privérepository-tegoed wilt gebruiken. De broncode wordt dan openbaar. Een privérepository gebruikt het inbegrepen maandtegoed van je account; extra gebruik kan kosten meebrengen.
3. Bij wijzigingen aan de app op `main` start de build automatisch. Je kunt hem ook starten via **Actions → Build ObjectScan for iPhone → Run workflow**.
4. Download na een geslaagde run het artifact **ObjectScan-iPhone** en pak het ZIP-bestand uit.
5. Installeer `ObjectScan-unsigned.ipa` met **AltStore Classic** en AltServer op Windows. Ondertekening gebeurt lokaal via je Apple-account; de workflow heeft geen Apple-wachtwoord, certificaat of GitHub-secret nodig.

De workflow draait na een handmatige start of bij wijzigingen aan de app op `main`, gebruikt een standaard `macos-15`-runner en bewaart het downloadbestand zeven dagen. Er wordt geen app in de App Store gepubliceerd.

## Installeren met Windows

Volg de actuele [AltStore Classic-handleiding voor Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). Gebruik Classic voor deze eigen IPA; de PAL-marktplaats heeft een andere installatieroute.

Installeer de benodigde Apple-componenten volgens die handleiding, verbind je iPhone via USB, vertrouw je pc en installeer AltStore met AltServer. Zet Ontwikkelaarsmodus aan op de iPhone. Zet daarna de IPA bijvoorbeeld via iCloud Drive of OneDrive in de app Bestanden en kies in AltStore **My Apps → +** het IPA-bestand.

Met een gratis Apple-account moeten AltStore en je eigen app uiterlijk elke zeven dagen worden vernieuwd. Laat AltServer op je pc draaien en gebruik op de iPhone **My Apps → Refresh All**, terwijl pc en iPhone elkaar via USB of hetzelfde netwerk kunnen bereiken. Daarvoor hoef je de app niet opnieuw in de cloud te bouwen. Verwijder de app niet om hem te vernieuwen: verwijderen wist de lokale scans. Exporteer belangrijke modellen apart.

## Eerste scan

Gebruik eerst een stilstaand, mat object met duidelijk zichtbare details in egaal licht. Houd het object volledig in beeld, kies **Object herkennen**, pas het kader aan en tik op **Start scannen**. Loop langzaam om het object en maak extra rondes van boven en van een lager standpunt. De app laat **Maak 3D-model** toe vanaf twintig foto’s; voldoende overlap en zicht op alle zijden zijn belangrijker dan alleen het aantal. Respecteer het fotolimiet dat de iPhone aangeeft.

Laat de app open tijdens de berekening. Het resultaat verschijnt in **Je scans**. Tik op **Bekijken** of **Exporteren**.

De eerste versie gebruikt rondes rond een stilstaand object. De zijde die op tafel staat wordt daardoor niet vanzelf vastgelegd. Reflecterende, doorzichtige of heel kleine objecten zijn moeilijker te reconstrueren. Controleer afmetingen en herstel open vlakken voordat je een model voor een passende 3D-print gebruikt.

## USDZ gebruiken op Windows

In Blender: **File → Import → Universal Scene Description** en kies het USDZ-bestand. Gebruik **Import Textures: Packed** om de texturen mee te nemen. Daarna kun je het model bewerken of exporteren als OBJ of STL. Het prototype exporteert rechtstreeks USDZ; de omzetting naar OBJ/STL gebeurt in deze route op je pc.

## Project

```text
.github/workflows/build-ios.yml       Handmatige cloudbuild
ObjectScan.xcodeproj/                 Xcode-project met gedeeld schema
ObjectScan/ObjectScanApp.swift        Startpunt
ObjectScan/LibraryView.swift          Bibliotheek, export en Quick Look
ObjectScan/ScannerView.swift          Opname en voortgang
ObjectScan/ScannerModel.swift         Capture- en reconstructiesessies
ObjectScan/ScanStore.swift            Lokale bestanden en herstelbare opnamen
scripts/build-ios.sh                 Releasebuild voor een echt iOS-apparaat
scripts/package_ipa.py                Verpakken voor lokale ondertekening
```

Er zijn geen externe Swift-pakketten, server, API-sleutel, account in de scan-app of abonnement nodig. De app vraagt cameratoegang. Je kiest zelf eventuele externe opslag bij export via het iOS-deelmenu. Bronfoto’s, checkpoints en het model staan in `Documenten/Scans/<uuid>` binnen de app en zijn ook bereikbaar via iOS-bestandsdeling.

## Validatie en volgende controle

Zie `VALIDATIE.txt` voor de uitgevoerde controles. Deze omgeving is Linux en heeft geen Xcode of iPhone. De Swift-parser is geen Swift-compiler en bewijst geen werkende iOS-build. De eerste echte acceptatiestap is een groene GitHub Actions-build, daarna opname → berekening → export op de iPhone 16 Pro.

Als de cloudbuild mislukt: open in Actions de stap **Build unsigned iPhone app** en bewaar de eerste `error:`-melding met enkele regels context. Dat is het bruikbare aanknopingspunt om eventuele compilerproblemen te herstellen.

## Bronnen

- [Apple: Object Capture](https://developer.apple.com/documentation/realitykit/objectcapturesession)
- [Apple: reconstructie op iOS](https://developer.apple.com/documentation/realitykit/creating-3d-objects-from-photographs)
- [Apple: detailniveaus; reduced op iOS](https://developer.apple.com/documentation/realitykit/photogrammetrysession/request/detail)
- [GitHub: inbegrepen Actions-gebruik](https://docs.github.com/en/actions/concepts/billing-and-usage)
- [AltStore Classic: installeren op Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore: vernieuwen na zeven dagen](https://faq.altstore.io/altstore-classic/your-altstore)
- [Blender: USD en USDZ](https://docs.blender.org/manual/en/4.2/files/import_export/usd.html)
