# Play testing plan

Owner does every Play Console step by hand. Nothing here has been sent to anyone.

## 1. Internal testing (now)

Release: version code 1, 0.1.0, already uploaded to Internal testing.

1. Play Console > Test and release > Testing > Internal testing > **Testers** tab.
2. "Create email list": name it `Buseta internos`, add the Google account your phone
   uses in the Play Store. Save, tick the list, Save again.
3. **Releases** tab: open the 0.1.0 draft > Next > **Save and publish** (or "Start
   rollout to Internal testing"). Internal releases skip review; allow 5 to 30 minutes.
4. Back on **Testers**: copy the opt-in link ("Join on the web" / "Copy link").
5. On the phone, signed in with that same account: open the link, tap "Become a
   tester", then "Download it on Google Play" and install. "Item not found" usually
   means it is still processing or the phone uses another account; wait and retry.

Warnings on the upload:
- No deobfuscation file: ignore. Godot does not use R8/ProGuard.
- Native code without debug symbols: ignore for testing. Godot's export templates ship
  stripped libraries; symbols only help read native crash reports.

### On-phone check

- [ ] Home screen shows the buseta icon with "Buseta" under it (also try themed icons
      on Android 13+ if your launcher has them).
- [ ] Menu title reads "Buseta Simulator: Colombia".
- [ ] Spanish text by default (English if the phone is set to English).
- [ ] Short drive: start the first route, pick up a passenger, reach a stop, end the
      shift from pause. Note anything odd (lag, cut text, sound).

## 2. Closed testing (12 testers, 14 days in a row)

New personal accounts need at least 12 testers opted in for 14 consecutive days on a
closed track before "Apply for production" unlocks. Internal testers do not count.
Aim for 15 to 20, since some drop out and the count must stay at 12 or more.

1. Make a Google Group (groups.google.com), e.g. `buseta-testers`, set to "Anyone on
   the web can ask / join". Testers join it themselves; no email collecting needed.
2. Play Console > Testing > Closed testing > the default track (Alpha) > **Manage**.
3. **Countries/regions**: Colombia plus the countries your testers are in (each
   tester's Play country must be on the list, or they cannot install).
4. **Testers**: choose "Google Groups", add the group's email address. Fill in the
   feedback URL or email (farestagegames@gmail.com). Save.
5. **Create new release** > "Add from library" > version code 1 > release notes
   (es-419 and en-US) > Next > **Start rollout to Closed testing**.
6. The first closed release goes to Google review (hours to a few days). The store
   listing, content rating, Data safety, target audience and privacy URL must be
   complete first, or the rollout button stays grey.
7. When approved, copy the closed-test opt-in link and send it with the invite below.
8. Day 1 is the day you reach 12 opted-in testers. Keep everyone opted in until day
   14, then Dashboard > "Apply for production" (it asks how testing went: keep notes
   of feedback and any updates you shipped).

Ship at least one update during the 14 days (bump version code to 2), fixing what
testers report. Google looks for real engagement, not just 12 installs.

### Where to find 12+ testers

- Family and friends with Android phones (most reliable, ask them to open it every
  few days).
- Spanish students and tutoring contacts, especially Colombians.
- Colombian and Latin American WhatsApp groups you are already in.
- Reddit: r/AndroidClosedTesting, r/TestersCommunity (tester swaps: you test theirs,
  they test yours), r/Colombia only if its rules allow app posts.
- Facebook groups for bus simulator fans or Colombian expats.
- Avoid paid "12 testers" services: they break the "no paid services" rule and Google
  may reject testing that looks bought.

### Invite message (es)

> ¡Hola! Estoy haciendo un juego de manejar buseta en una ciudad costeña de Colombia:
> Buseta Simulator: Colombia. Necesito unas 12 personas con Android que lo prueben
> durante 2 semanas antes de publicarlo en Google Play. Es gratis, sin anuncios y
> funciona sin internet.
>
> 1. Únete a este grupo: [enlace del grupo de Google]
> 2. Acepta la prueba aquí y descárgalo: [enlace de la prueba]
> 3. No lo desinstales en 14 días y juega un ratico cada pocos días.
>
> Cualquier comentario me sirve muchísimo. ¡Mil gracias!

### Invite message (en)

> Hi! I'm making a bus driving game set in a Colombian coastal city: Buseta
> Simulator: Colombia. Before it can go on Google Play I need about 12 people with
> Android phones to test it for 2 weeks. It's free, has no ads and works offline.
>
> 1. Join this group: [Google Group link]
> 2. Accept the test and install it: [test link]
> 3. Keep it installed for 14 days and play for a few minutes every few days.
>
> Any feedback helps a lot. Thank you!

## 3. Owner to-do alongside testing

- Re-upload `store/privacy/index.html` to the `callenomad/city-bus-shift-privacy` repo:
  https://callenomad.github.io/city-bus-shift-privacy/ still shows the old name.
- Back up `~/Keys/city-bus-shift-upload.jks` off this Mac (password manager attachment
  or encrypted USB), with its password in the password manager. See RELEASE.md.
