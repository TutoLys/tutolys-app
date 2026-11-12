# Investor demo — operating sheet

The checklist for showing TutoLys to investors: what runs where, which
backend it talks to, which accounts to use, a five-minute script, and every
rough edge someone will hit. Decisions behind it: ADR 0127.

Written 2026-11-10 against `tutolys-app` at `b94bf90`. Re-check the rough
edges before each demo; several are being worked on.

## 1. Which device runs what

| Device | Build | How it's made | Status |
|---|---|---|---|
| **The laptop (Linux)** | Linux release, `build/demo/tutolys-linux-x64-<sha>.tar.gz` | `tool/build_demo.sh HOST linux` | Built here. **Best device for the demo**: it also runs the backend. |
| **Any browser** | Web release, `build/demo/web/` | `tool/build_demo.sh HOST web` | Built here. Serve it as static files. |
| **Android phone or tablet** | APK, `build/demo/tutolys-android-<sha>.apk` | `tool/build_demo.sh HOST apk` | Built here. Debug-signed: allow "install unknown apps". |
| **Windows PC** | Unsigned release folder | GitHub Actions `demo-windows` | Workflow written, **not run** (needs a push and Hafid's OK on cost). |
| **Mac** | Ad-hoc-signed `TutoLys.app` | GitHub Actions `demo-apple` | Same. |
| **iPhone / iPad** | Simulator app only | GitHub Actions `demo-apple` | Needs a Mac with Xcode to show. A real iPad needs an Apple Developer account. |

Decided: **the laptop plus one Android tablet** (Windows if a PC is at
hand; no Apple device). Two devices show
that a kid's progress follows them, without depending on CI or Apple.

## 2. Which backend the demo points at

Hosting (#5) is open, so there is no public backend. Every build has its
backend address **baked in at build time** (`--dart-define`), and a release
build refuses `127.0.0.1` (the release guard). So the address must be one
the tablet can reach.

### Option A — the laptop's dev-stack over its own hotspot (chosen)

Hafid's choice (2026-11-10). The laptop runs a Wi-Fi hotspot, so its
address is always **10.42.0.1** and the builds never need redoing at a
venue. The tablet joins that hotspot.

**Once, before the demo** (already done for the 2026-11-10 builds):

```bash
tool/build_demo.sh 10.42.0.1
```

**On the day, in this order:**

1. **Start the hotspot.** Find the Wi-Fi device (`nmcli -t -f DEVICE,TYPE
   device`, the one marked `wifi`, `wlp4s0` on this laptop), then:

   ```bash
   nmcli device wifi hotspot ifname wlp4s0 ssid TutoLys-Demo password "<a private password>"
   ```

   Check the laptop has 10.42.0.1:

   ```bash
   ip -4 addr show wlp4s0
   ```

   While the hotspot is on, the laptop's Wi-Fi card is not on the
   venue's Wi-Fi: no internet unless the laptop also has a cable. The
   demo needs none, except that the village's real weather goes stale
   (calm sky after 3 h) and mail doesn't leave.

2. **Expose the dev-stack on the hotspot** (`dev-stack/compose.demo-lan.yml`,
   opt-in; it touches backend and telemetry only, never the databases).
   The hotspot must be up first, or Docker can't bind 10.42.0.1:

   ```bash
   cd Platforms/dev-stack && docker compose -f docker-compose.yml -f compose.demo-lan.yml up -d --no-deps backend telemetry
   ```

   Check from the tablet's browser that `http://10.42.0.1:8000/api/v1/schema/docs/`
   answers.

3. **Web build**, if shown: serve it on the laptop itself, which keeps
   the browser on a secure origin (localhost). The web token store needs
   one, and a plain-http LAN address isn't:

   ```bash
   cd Platforms/tutolys-app/build/demo/web && python3 -m http.server 8090 --bind 127.0.0.1
   ```

   Then open `http://127.0.0.1:8090/` on the laptop. The override already
   allows that origin. For a browser on the tablet, use
   `dev-stack/lan-preview/` (HTTPS, self-signed) instead.

4. **Parents' portal** (Zone parent → « Ouvrir le site » opens
   `http://10.42.0.1:4321/portail/`). Serve the website on the hotspot
   address; the hotspot must be up first:

   ```bash
   cd Platforms/tutolys-web && npm run demo
   ```

   It builds the site into `dist-demo/` (about a minute) and serves it
   on `10.42.0.1:4321` only. The page calls `/api` on that same origin
   and the server forwards it to the backend on `127.0.0.1:8000`, so it
   needs no CORS or CSRF change. Step 2 isn't needed for the portal,
   only for the app. To serve again without rebuilding, run
   `npm run demo:serve`. Check from the tablet's browser that
   `http://10.42.0.1:4321/portail/` shows « Bon retour ! ».

   The demo server binds the hotspot address only, so it runs beside a
   normal `npm run dev` on 127.0.0.1:4321. Nothing else changes.
   - **Without a hotspot**, to rehearse: `DEMO_HOST=<the laptop's LAN
     address> npm run demo`.
   - **Over plain HTTP**, the « Copier » button for a pairing code does
     nothing (the browser keeps the clipboard for HTTPS). The code is
     on screen; read it out.

   **Revert:** stop it with Ctrl-C. Nothing else was changed. On the
   laptop, the portal is still at `http://127.0.0.1:4321/portail/` from
   `npm run dev`.

**After the demo**, back to loopback only, then stop the hotspot:

```bash
cd Platforms/dev-stack && docker compose up -d --no-deps backend telemetry
```

```bash
nmcli connection down Hotspot
```

**Cleartext HTTP.** The dev-stack has no TLS:
- Android: done. `tool/build_demo.sh` builds the APK with
  `TUTOLYS_DEMO_LAN=1`, which allows cleartext to any host. **Never
  publish that APK.** A normal build allows cleartext only to the 3D
  village's own loopback server.
- Windows, Linux: nothing needed.
- iOS (simulator only, no device demo): `NSAllowsLocalNetworking` is set.

### Option B — a hosted demo backend (later)

Once #5 is decided: one HTTPS backend and telemetry (for example
`api-demo.tutolys.ca`), rebuild with those URLs, and none of the
cleartext or hotspot steps apply. The CI workflows already take the URLs
as inputs. This is the right answer for anything beyond one meeting.

## 3. Demo accounts and content

**Only grades 1 and 2 have published lessons** (counted on the dev-stack,
2026-11-10):

| Grade | Math | Français | English | Science | Univers social | CCQ | ESL / FLS | Total |
|---|---|---|---|---|---|---|---|---|
| 1 | 294 | 450 | 133 | 152 | 294 | 104 | 10 / 10 | 1,447 |
| 2 | 188 | 613 | 129 | 88 | 220 | 100 | — | 1,338 |

A grade 3–6 kid sees an almost empty village. **Use grades 1 and 2 only.**

Requested from Backend in `Platforms/BACKEND_WORKORDER_DEMO_FAMILY.md`.
No credentials go in this file, in a repo or in chat:

- one guardian account, *Famille Démo*, on the Family plan (three seats);
- **two kids**: one in grade 1, one in grade 2, with different avatars,
  so « Qui joue ? » has a real choice;
- each kid paired on **both** demo devices (one pairing per device per
  kid; the app holds several kids per device).

**Warm them up the day before**: play three or four lessons per kid, so
the header shows a streak, XP and a level, and Quêtes shows progress.
On the morning of the demo, play one lesson per kid, or the streak shows
« jour 1 » again. Daily quests reset at midnight.

QA kids (`QA Kid xxxx`, « Noé 3D ») are test fixtures that tests erase
and recreate. Don't demo with them.

## 4. The five-minute script

1. **« Qui joue ? »** (0:00–0:30). Launch the app: with two kids paired
   it opens on the picker. Point out: no passwords for a six-year-old;
   a parent paired this device once.
2. **The village** (0:30–1:30). One building per subject, its progress
   pill from the kid's real mastery. The fox speaks a line about today's quest. The
   header shows streak, XP and level. Mention that the sky follows the
   real Montréal weather and time of day. *Optional*: Réglages → « Contrôles
   du ciel » shows the sky changing on demand (winter, storm, night).
3. **A lesson** (1:30–3:30). Tap Mathématique → Carte → the next
   lesson. Tap the speaker: the question is read aloud (a grade-1 kid
   can't read it). Answer one wrong on purpose: amber, never red, and
   another try. Then right: « Bravo ».
4. **Celebration** (3:30–4:00). The fox, the XP earned, the quest
   progress.
5. **Quêtes** (4:00–5:00). Three daily quests, the weekly badge,
   achievements, the streak and its shield (a streak freeze). Then hand
   the tablet over and show the same kid's progress on the laptop.

## 5. Rough edges an investor would hit

**Before the demo — will break it if missed**
- The baked-in backend address (section 2). A build made at home won't
  reach a laptop at the venue, and nothing on screen says why beyond a
  network error at pairing.
- The dev-stack must be up, exposed on the demo address, and not in the
  middle of a content import or audio drain.
- First launch on a new device downloads that grade's lessons and audio:
  do it before the meeting, on the demo network.

**Visible during the demo**
- **The 3D village on Android, iOS, macOS and Windows has never run on a
  real device.** It is built in, and any failure falls back to the 2D
  village within 20 s, or after two slow frame-rate readings. Try it on
  the actual tablet the day before; a low-end tablet will likely show 2D.
- The 3D village takes a few seconds to load (sky-coloured loader).
- Zone parent → « Ouvrir le site » opens the portal in the browser. On
  the tablet it loads only if the website is served on the hotspot (§2,
  step 4).
- Read-aloud voices are France-French (Piper has no Québec voice).
- *Entre amis* in the Série modal is a greyed « bientôt » tab, on
  purpose. The Boutique says « bientôt ».
- In English, non-language lessons are still French and tagged `FR`.
- The weather follows Montréal for every family (no per-family region yet).
- Avatars past the starters are unlocked by levels and achievements, so
  a warmed-up kid shows more of them.

**Platform-specific**
- **Android**: "Install unknown apps" must be allowed, and Play Protect
  may warn about an unknown developer (debug-signed APK).
- **Windows**: SmartScreen warns about an unsigned app (« Informations
  complémentaires → Exécuter quand même »). No installer: unzip and run
  `tutolys_app.exe`.
- **macOS**: unsigned outside the ad-hoc signature, so it opens with
  right-click → Ouvrir the first time. The device token is stored in the
  Keychain. With no Apple team the Keychain may refuse it, and the app
  would forget its pairing on relaunch. **Test a relaunch before relying
  on a Mac.**
- **iOS**: simulator only until there is an Apple Developer account
  (99 USD/year). A simulator on a Mac screen is a weaker demo than a
  real iPad.
- **Linux**: the tarball needs `libwebkit2gtk-4.1-0`, GStreamer and
  `gstreamer1.0-libav` on the target machine. The laptop has them.

## 6. What's waiting on Hafid

- **An Apple Developer account** (99 USD/year) and **a Mac**: Hafid has
  neither yet (2026-11-10). So the demo is Android, Linux, web and
  Windows; the iOS artifact only shows the app compiles.
- ~~CI spend~~: decided 2026-11-10, Windows + Apple. The Manager pushes
  and dispatches with `http://10.42.0.1:8000`, `:8001` and the portal
  URL `http://10.42.0.1:4321/portail/` (`portal_url` input).
- **A decision on #5 (hosting)** for anything beyond a single meeting.

## 7. CI cost per run (estimates)

GitHub bills hosted minutes on private repositories with a multiplier
against the plan's included minutes: Linux ×1, Windows ×2, macOS ×10.

| Workflow | Wall-clock | Counted against included minutes |
|---|---|---|
| `demo-windows` | ~12–18 min | ~25–35 min |
| `demo-apple`, macOS job only | ~10–15 min | ~100–150 min |
| `demo-apple`, iOS job only | ~15–25 min | ~150–250 min |
| `demo-apple`, both | ~25–40 min | ~250–400 min |

The Free plan includes 2,000 minutes a month, so one full Apple run uses
an eighth to a fifth of it. These are estimates: the first run is the
slowest (no Flutter or CocoaPods cache). Check GitHub's current price
list before running beyond the included minutes.
