# Notificaties in de iOS-app

## In-app (DDP)

Na login abonneert de app op `notifications.active` (zelfde als de webapp). Je ziet een **bel** op het dashboard met een rode badge; tik om de lijst te openen.

Als je hier niets ziet: controleer dat je bent ingelogd en dat de Meteor-server draait (lokaal: `ws://127.0.0.1:3000/websocket` in DEBUG).

## Push (APNs) – vergrendeld scherm / achtergrond

Push gaat **niet** via MeteorDDPKit; de server stuurt via Apple (APNs). Daarvoor moet je:

1. **Xcode**  
   - Target → *Signing & Capabilities* → **+ Capability** → **Push Notifications**

2. **Meteor-server** (`settings.json` of omgeving)  
   - `Meteor.settings.private.push.enabled: true`  
   - APNs key (`.p8`), `keyId`, `teamId`, juiste `bundleId`  
   - Pakket: `meteor npm install apn` op de server

3. **Echt apparaat**  
   - De iOS-simulator krijgt geen echte productie-push; test op een iPhone.

4. **Eerste keer**  
   - De app vraagt toestemming voor meldingen. Daarna wordt het device-token naar `push.registerToken` gestuurd (alleen als je ingelogd bent).

Zonder deze stappen werkt **alleen** de in-app lijst (als de app open is), geen systeem-melding op het vergrendelscherm.
