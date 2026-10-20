# Universal Remote

Offline universal IR remote for Android phones with an IR blaster (built on a Xiaomi Redmi 4X).
Air conditioners first; TV support follows.

## Features

- **Find my AC**: pick the brand (popular Vietnamese-market brands are suggested first) or let auto search try
  every code. The phone has no IR receiver, so you confirm when the AC beeps; a power-off check confirms the match.
- **AC remote**: temperature, mode, fan speed, swing and turbo, with each AC's last state remembered.
- **13 AC codes**: Daikin, Panasonic (DKE, JKE), LG (LG2, LG), Casper / Electra, Samsung, Toshiba,
  Mitsubishi Electric, Gree (YAW1F, YBOFB), Coolix (Midea-made units), Midea. Each encoder is checked byte for byte
  against [IRremoteESP8266](https://github.com/crankyoldgit/IRremoteESP8266) test vectors; Electra is also checked
  against 727 real Casper SC-09FS32 captures from [SmartIR](https://github.com/smartHomeHub/SmartIR).
- **TV groundwork**: NEC, Samsung32, Sony SIRC, Panasonic and Pronto encoders plus IRDB code sets.
- **IR diagnostics**: emitter check, carrier ranges, test bursts.

## Layout

Clean architecture with MVVM views, see [ARCHITECTURE_AND_PLAN.md](ARCHITECTURE_AND_PLAN.md).

```
lib/domain/   models, encoders (strategy per protocol), pairing search, use cases, repository interfaces
lib/data/     ConsumerIrService (MethodChannel), shared-preferences and asset repositories
lib/ui/       home, AC pairing wizard, AC remote, diagnostics (ChangeNotifier view models)
lib/app/      composition root
android/      MainActivity: ConsumerIrManager bridge on channel `universal_remote/ir`
assets/ir_db/ AC brand catalog, TV code sets
```

## Build and test

```bash
flutter analyze && flutter test
```

Builds go through [cicd-offline](https://github.com/hsluan/cicd-orchestrator) (project `universal-remote`): analyze and tests gate
the APK, `--install` puts it on the connected phone.

```bash
ci build universal-remote android dev --install
```
