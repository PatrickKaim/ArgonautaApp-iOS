# Meteor op de Mac bereiken vanaf een iPhone (development)

## Geen “doorsturen naar localhost” op de Mac

Er is **geen aparte router/port-forward** nodig binnen je thuisnetwerk:

- **Meteor** luistert op `0.0.0.0:3000` (standaard) = op **alle netwerkinterfaces** van de Mac, dus ook op `192.168.x.x:3000`.
- Een iPhone die naar `http://192.168.1.42:3000` / `ws://192.168.1.42:3000/websocket` gaat, stuurt het pakket **rechtstreeks** naar die Mac op het LAN. Dat is **niet** eerst “naar localhost” routeren: `localhost` op de Mac is alleen `127.0.0.1` **op die Mac**; vanaf de iPhone gebruik je het **LAN-IP** van de Mac.

**Poortforwarding op je internetrouter** is alleen nodig als je van **buiten** het huis naar binnen wilt — niet voor iPhone en Mac op hetzelfde WiFi.

Wat wél kan blokkeren:

1. **macOS-firewall** — inkomende verbindingen naar het Node/Meteor-proces.
2. **iOS** — vanaf iOS 14 o.a. **Local Network**-toestemming; in het project staat `NSLocalNetworkUsageDescription` in `Info.plist`.

---

## iOS Simulator vs fysiek toestel

**Simulator — defaults (geen `ARGO_METEOR_WS`, geen `public.rootUrl` in Meteor):**

- **DDP:** `ws://127.0.0.1:3000/websocket` — op de Simulator is `127.0.0.1` de **host-Mac** → werkt.
- **Magic link uit MailDev:** `http://localhost:3000/...` — Safari in de Simulator gebruikt `localhost` ook naar de **Mac** → werkt.
- Zet je **`public.rootUrl`** op een LAN-IP voor iPhone-tests, dan worden magic links `http://192.168.x.x/...`; die gaan op de **Simulator** nog steeds naar dezelfde Meteor op je Mac (je Mac luistert op alle interfaces).

Kortom: **lokaal ontwikkelen met alleen de Simulator** hoef je niets extra’s te zetten.

**Fysieke iPhone:** `localhost` in een mail wijst naar **de telefoon** → gebruik **LAN** (`public.rootUrl` + `ARGO_METEOR_WS`) of test tegen **productie** (hieronder).

---

## Backend: lokaal of `https://argonauta.nl`

Vaak is het **handiger** om de app (Simulator én iPhone) tegen de **productieserver** te laten praten zodra die live staat:

| Wat | Hoe |
|-----|-----|
| **DDP (DEBUG)** | Xcode → Scheme → Run → **Environment Variables**: `ARGO_METEOR_WS` = `wss://argonauta.nl/websocket` |
| **DDP (Release)** | Gebruikt al automatisch `wss://argonauta.nl/websocket` (geen override nodig). |
| **Magic links** | Komen van de server die de mail verstuurt. Tegen **productie** staan daar `https://argonauta.nl/...`-links in — die openen overal (ook op een fysieke iPhone) zolang je echte mail / webmail gebruikt. |

**Let op:** je praat dan tegen **productie-data** — gebruik een testaccount of wees voorzichtig met wijzigingen.

---

`localhost` / `127.0.0.1` op de iPhone wijst naar **de telefoon zelf**, niet naar je Mac. Daarom moet je het **lokale netwerk-IP van je Mac** gebruiken (zelfde WiFi als de iPhone).

## 1. Mac-IP achterhalen

```bash
ipconfig getifaddr en0
```

Of: **Systeeminstellingen → Netwerk → WiFi → Details → TCP/IP** (IPv4-adres, bv. `192.168.1.42`).

## 2. iOS-app: WebSocket-URL

**Optie A – zonder code wijzigen (aanbevolen)**  

Xcode → **Product → Scheme → Edit Scheme…** → **Run** → tab **Arguments** → **Environment Variables**:

| Name            | Value                                      |
|-----------------|--------------------------------------------|
| `ARGO_METEOR_WS` | `ws://192.168.1.42:3000/websocket` |

(Vervang `192.168.1.42` door jouw Mac-IP.)

**Optie B**  

Tijdelijk de default in `MeteorService.swift` (DEBUG) aanpassen naar dat `ws://…`-adres.

## 3. Meteor op de Mac

Standaard luistert `meteor run` op **poort 3000** op alle interfaces (`0.0.0.0`). Controleer anders:

```bash
METEOR_ALLOW_SUPERUSER=1 meteor run --port 3000
```

### Magic links / MailDev (inloggen vanaf de iPhone)

Magic links in e-mail worden op de server gebouwd met `Meteor.absoluteUrl(…)`. Die gebruikt **`ROOT_URL`**, standaard **`http://localhost:3000/`**. In de mail in MailDev staat dus een link naar **localhost** — op je iPhone is dat **de telefoon zelf**, niet je Mac.

**Oplossing (kies één):**

1. **`settings.json`** (aanbevolen naast `ARGO_METEOR_WS`): in `public.rootUrl` het LAN-adres zetten, bijvoorbeeld:
   ```json
   "public": {
     "rootUrl": "http://192.168.1.42:3000"
   }
   ```
   (Vervang door jouw Mac-IP; trailing slash mag, maar hoeft niet — de server normaliseert.)

2. **Of** bij het starten van Meteor:
   ```bash
   ROOT_URL=http://192.168.1.42:3000 meteor run --settings settings.json
   ```

Daarna bevat de mail in MailDev een link als `http://192.168.1.42:3000/auth/magic-link/…` die je op de iPhone (Safari) kunt openen; die gaat naar je Mac.

**Let op:** MailDev zelf draait op `http://localhost:1080` op de **Mac** — die web-UI bereik je niet direct met “localhost” vanaf de telefoon. Je kunt de link uit de mail **kopiëren** naar de iPhone, of tijdelijk de MailDev-poort ook op het LAN tonen (bijv. `docker run … -p 0.0.0.0:1080:1080`) en dan `http://192.168.x.x:1080` openen op de telefoon.

## 4. macOS-firewall

Als de iPhone niet verbindt: **Systeeminstellingen → Netwerk → Firewall** (of **Privacy en beveiliging**):

- Firewall tijdelijk uitzetten om te testen, óf
- **Opties** bij firewall: inkomende verbindingen toestaan voor **node** / **Terminal** / **Cursor**, of een regel voor poort **3000**.

## 5. WebStorm / IDE

De IDE **opent geen poort** en **blokkeert** het netwerk niet. Alleen de **Mac-firewall** en **router** (zeldzaam: client-isolatie op gast-WiFi) kunnen verkeer tegenhouden.

## 6. HTTPS / productie

Release-builds gebruiken `wss://argonauta.nl/websocket`. LAN-`ws://` is alleen voor lokale development.

---

## 7. Checklist: productie (`argonauta.nl`)

Korte referentie voor **Release** (TestFlight / App Store) versus **DEBUG** in Xcode, plus Universal Links en push.

### iOS-app (code)

| Onderwerp | Release | DEBUG (Xcode → Run) |
|-----------|---------|---------------------|
| **DDP / WebSocket** | `wss://argonauta.nl/websocket` in `MeteorService` — geen env-var nodig | Standaard `ws://127.0.0.1:3000/websocket` (Simulator → Meteor op de Mac). Tegen **productie** testen: Scheme → **Environment Variables** → `ARGO_METEOR_WS` = `wss://argonauta.nl/websocket` |
| **HTTP-basis voor relatieve media-URL’s** | `https://argonauta.nl` (`URLResolver`) | Afgeleid van `ARGO_METEOR_WS`, anders `http://127.0.0.1:3000` |
| **Magic link in de app** | Universal Link `https://argonauta.nl/auth/magic-link/…` (na tap op link in mail/Safari) | Zelfde als je tegen productie praat; lokaal + LAN zie de tabel *Backend: lokaal of argonauta.nl* en **§ 3. Meteor op de Mac** hierboven |

### Universal Links (magic link opent de app)

1. **Server:** `GET https://argonauta.nl/.well-known/apple-app-site-association` levert JSON met o.a. `appID` = `TEAMID.bundleId` (bijv. `H456SH8SHW.com.kaimws.ArgonautaApp`) en `paths` die `/auth/magic-link/*` dekken.
2. **iOS:** Entitlements bevatten `applinks:argonauta.nl`. Bundle ID in Xcode moet **exact** overeenkomen met die in AASA.
3. Eerste keer na install kan iOS de link nog in Safari openen; dat is normaal gedrag tot iOS de associatie heeft opgepikt.
4. **Technisch:** iOS levert Universal Links vaak via **`NSUserActivityTypeBrowsingWeb`** (continue user activity), niet alleen via `onOpenURL`. De app handelt beide af; alleen `onOpenURL` is vaak **niet genoeg** — dan opent de app wel, maar wordt de token niet naar de server gestuurd en blijft “Wachten op verificatie” draaien.

### Push (APNs)

- **Simulator:** remote push is **onbetrouwbaar**; echte tests op een **fysieke iPhone**.
- **Server (Meteor):** `private.push.enabled`, pad naar `.p8`, `keyId`, `teamId`, `bundleId` gelijk aan Xcode, `apnOptions.production: true` voor App Store / TestFlight-builds; npm-pakket **`apn` ^2.x** (Provider-API).
- **iOS:** Push Notifications capability aan. Na **Archive** voor de store: controleer in het ondertekende product dat **`aps-environment`** **production** is (Xcode zet dit vaak goed bij Release; anders entitlements per configuratie nalopen).

### Keychain (optioneel)

`KeychainService` gebruikt een vaste service-string (`nl.argonauta.app`). Die hoeft niet gelijk te zijn aan de bundle ID; **wijzig die string niet** als je bestaande opgeslagen tokens wilt behouden.
