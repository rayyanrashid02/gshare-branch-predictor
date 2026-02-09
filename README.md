# GShare Branch Predictor (Verilog)

A Verilog implementation of a **GShare branch direction predictor** with a self-checking SystemVerilog testbench.

## Features
- **7-bit Global History Register (GHR)**
- **128-entry Pattern History Table (PHT)** with **2-bit saturating counters**
- **Speculative history updates** on prediction
- **Misprediction rollback** using the recorded history-at-prediction-time

## How it works (high level)
- **Index:** `index = PC ⊕ GHR`
- **Predict:** `predict_taken = PHT[index][1]` (MSB of the 2-bit counter)
- **Train:** increment/decrement `PHT[train_pc ⊕ train_history]` based on the actual outcome
- **Recover:** on mispredict, restore `GHR = {train_history[5:0], train_taken}`

## Repo layout
- `rtl/` — RTL (Verilog)
- `tb/` — self-checking testbench (SystemVerilog)
- `scripts/` — Yosys scripts for visualization
- `artifacts/` — schematic + waveform screenshots

## Artifacts

### Waveform (simulation)
![Waveform](artifacts/gshare_waveform.png)

### Structural schematic (Yosys)
![Schematic](artifacts/gshare_schematic.png)

## Tooling
- Simulation: **Icarus Verilog**
- Waveforms: **GTKWave**
- Schematic: **Yosys + Graphviz**