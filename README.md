# PSD — Power Stage Designer

A modular Flutter application for power-stage design calculations.

## First milestone

- Flutter / Dart application foundation
- English-first interface with Arabic localization architecture
- Left navigation drawer for topologies and design calculators
- First working topology: **Buck Converter**
- SI units inside the calculation engine
- Unit tests for the Buck calculations

## Project structure

```text
lib/
  app/                 Application shell and theme
  core/                Units, validation and calculation models
  localization/         English and Arabic strings
  navigation/           Navigation drawer
  screens/              Main workspace
  topologies/buck/      Buck UI, engine and schematic
test/
  buck_engine_test.dart
```

## Run locally

Install the Flutter SDK, then:

```bash
flutter pub get
flutter test
flutter run
```

## Engineering notes

The calculation engine uses SI units internally. UI values are converted at the input/output boundary. The first Buck implementation is a design-sizing baseline; advanced waveform, loss and compensation modules will be added in later milestones.

## Status

Milestone 1 — application foundation and Buck Converter prototype.
