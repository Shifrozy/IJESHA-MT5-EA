# 🚀 IJESHA ALGO EA v2.0 (MetaTrader 5)

[![MQL5](https://img.shields.io/badge/Language-MQL5-blue.svg?style=for-the-badge&logo=c%2B%2B)](https://www.mql5.com/)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg?style=for-the-badge)](https://www.metatrader5.com/)
[![Win Rate](https://img.shields.io/badge/Target%20Win%20Rate-65%25%2B-brightgreen.svg?style=for-the-badge)](https://github.com/Shifrozy/IJESHA-MT5-EA)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=for-the-badge)](LICENSE)

An institutional-grade, aggressive **MetaTrader 5 Expert Advisor (EA)** engineered with multi-layer trend-momentum confirmation, adaptive volatility sizing, dynamic ATR-based risk controls, break-even protection, trailing stop mechanisms, and an interactive real-time HUD dashboard.

---

## 📌 Key Highlights & Features

- ⚡ **Multi-Indicator Confluence Matrix**:
  - **Stochastic Oscillator** (%K 14, %D 3, Slowing 3) — Cycle extremes & momentum crossovers.
  - **Commodity Channel Index (CCI 14)** — Trend strength & overbought/oversold boundaries (`±100`).
  - **Parabolic SAR** (Step 0.02, Max 0.20) — Dynamic trailing direction and stop confirmation.
  - **Exponential Moving Averages (EMA 50 & EMA 21 Fast)** — Macro & intermediate trend alignment.
  - **Relative Strength Index (RSI 14)** — Exhaustion & momentum filtering.
  - **Average True Range (ATR 14)** — Volatility-adapted dynamic Stop Loss & Take Profit calculation.

- 🛡️ **Autonomous Trade Protection & Risk Management**:
  - **Fixed Lot Sizing**: Optimized for consistent account scaling (`0.02` default or user-defined).
  - **Spread Protection**: Real-time spread ceiling filter (`<= 50 pts`) to prevent slippage during rollover/news.
  - **Single Position Rule**: Enforces 1 active position per symbol to eliminate over-exposure.
  - **Break-Even Trigger**: Moves Stop Loss to Entry + Profit Offset after `30 points` gain.
  - **Smart Trailing Stop**: Activates at `50 points` profit with a `15 points` step for maximum profit retention.
  - **High-Liquidity Session Filter**: Filters out low-volume, choppy market phases (07:00 – 20:00 server time).

- 📊 **Interactive On-Chart Visual GUI**:
  - Live HUD Dashboard displaying live indicator states, spread, trend bias, and P/L.
  - Real-time **Divergence Line Visualizer** drawn directly on candlesticks for visual confirmation.

---

## 🏗️ Algorithmic Confluence Workflow

```mermaid
flowchart TD
    A[New Tick / Bar Data] --> B{Spread <= Max Allowed?}
    B -- No --> Z[Skip / Wait]
    B -- Yes --> C{Inside Trading Session 07:00-20:00?}
    C -- No --> Z
    C -- Yes --> D{Active Position for Symbol?}
    D -- Yes --> E[Manage Open Trade: BE & Trailing Stop]
    D -- No --> F[Evaluate Multi-Indicator Confluence Matrix]
    
    subgraph BUY_SIGNAL [BUY Strategy Logic]
        G1[Stochastic < 20 Oversold]
        G2[CCI < -100]
        G3[Price > Parabolic SAR]
        G4[Fast EMA > Slow EMA or Price > EMA]
        G5[RSI < 45 Oversold Zone]
    end
    
    subgraph SELL_SIGNAL [SELL Strategy Logic]
        H1[Stochastic > 80 Overbought]
        H2[CCI > 100]
        H3[Price < Parabolic SAR]
        H4[Fast EMA < Slow EMA or Price < EMA]
        H5[RSI > 55 Overbought Zone]
    end

    F --> BUY_SIGNAL
    F --> SELL_SIGNAL

    BUY_SIGNAL --> I[Calculate ATR-based Dynamic SL/TP] --> J[Execute Buy Order]
    SELL_SIGNAL --> K[Calculate ATR-based Dynamic SL/TP] --> L[Execute Sell Order]
```

---

## ⚙️ Strategy Specification

### 🟢 Long (Buy) Signal Confluence:
1. **Stochastic Oscillator**: Main line `< 20` (Oversold condition).
2. **CCI (14)**: Value `< -100` (Momentum dip confirmation).
3. **Parabolic SAR**: Price is **above** current SAR level.
4. **EMA Filter**: Price is above EMA 50 & Fast EMA 21 is bullish.
5. **RSI Filter**: RSI `< 45` (Prevents buying at top of trend).
6. **Spread Filter**: Current Market Spread `< InpMaxSpread`.

### 🔴 Short (Sell) Signal Confluence:
1. **Stochastic Oscillator**: Main line `> 80` (Overbought condition).
2. **CCI (14)**: Value `> 100` (Momentum surge confirmation).
3. **Parabolic SAR**: Price is **below** current SAR level.
4. **EMA Filter**: Price is below EMA 50 & Fast EMA 21 is bearish.
5. **RSI Filter**: RSI `> 55` (Prevents selling at absolute bottom).
6. **Spread Filter**: Current Market Spread `< InpMaxSpread`.

---

## 🛠️ Input Parameters Reference

| Group | Parameter | Default | Description |
| :--- | :--- | :--- | :--- |
| **Trade Settings** | `InpLotSize` | `0.02` | Fixed trading volume |
| | `InpMagicNumber` | `123456` | Unique EA identifier |
| | `InpMaxSpread` | `50` | Maximum allowable spread (Points) |
| | `InpSignalLookback` | `5` | Lookback window for confluence |
| **Stochastic** | `InpStochK` / `D` / `Slowing` | `14` / `3` / `3` | Stochastic oscillator period settings |
| | `InpStochOversold` / `Overbought` | `20.0` / `80.0` | Oversold / Overbought thresholds |
| **CCI** | `InpCCIPeriod` | `14` | Commodity Channel Index period |
| | `InpCCIBuyLevel` / `SellLevel` | `-100.0` / `100.0` | Signal triggering boundaries |
| **ATR Risk** | `InpATRPeriod` | `14` | Volatility evaluation period |
| | `InpSLMultiplier` | `1.5` | Stop Loss multiplier (`SL = ATR * 1.5`) |
| | `InpTPMultiplier` | `2.0` | Take Profit multiplier (`TP = ATR * 2.0`) |
| **Parabolic SAR** | `InpSARStep` / `InpSARMax` | `0.02` / `0.20` | Acceleration factor and maximum bound |
| **EMA Trend Filter** | `InpUseEMAFilter` | `true` | Enable/Disable EMA trend validation |
| | `InpEMAPeriod` / `FastPeriod` | `50` / `21` | Slow and Fast EMA periods |
| **RSI Filter** | `InpUseRSIFilter` | `true` | Enable/Disable RSI exhaustion filter |
| **Session Filter** | `InpUseSessionFilter` | `true` | Enable trading time window |
| | `InpSessionStartHour` / `EndHour` | `7` / `20` | Active trading hours (Server time) |
| **Trade Protection** | `InpUseBreakEven` | `true` | Auto-move SL to entry at `30 pts` profit |
| | `InpUseTrailing` | `true` | Auto-trailing stop at `50 pts` profit |
| **Visuals** | `InpDrawDivergence` | `true` | Render on-chart divergence lines |

---

## 📥 Installation & Setup Guide

1. **Clone or Download Repository**:
   ```bash
   git clone https://github.com/Shifrozy/IJESHA-MT5-EA.git
   ```

2. **Copy Files to MetaTrader 5**:
   - Open **MetaTrader 5**.
   - Click `File` -> `Open Data Folder`.
   - Navigate to `MQL5/Experts/`.
   - Copy `IJESHA_ALGO_EA.mq5` and `IJESHA_ALGO_EA.ex5` into this folder.

3. **Enable Algorithmic Trading**:
   - In MT5, press `Ctrl + O` to open Options -> **Expert Advisors**.
   - Check **"Allow Algo Trading"**.
   - Check **"Allow WebRequest / DLL imports"** if required.

4. **Attach to Chart**:
   - In the MT5 Navigator (`Ctrl + N`), expand **Expert Advisors**.
   - Drag & drop **IJESHA ALGO EA** onto your target chart (recommended: EURUSD, GBPUSD, XAUUSD, USDJPY on M5/M15/H1).
   - Ensure the "Algo Trading" button on the MT5 toolbar is green.

---

## 📈 Recommended Pairs & Timeframes

- **Primary Assets**: `EURUSD`, `GBPUSD`, `XAUUSD` (Gold), `USDJPY`
- **Recommended Timeframe**: `M5`, `M15`, `H1`
- **Broker Recommendations**: Low spread ECN/RAW accounts (Exness, IC Markets, Pepperstone).

---

## 📄 License & Disclaimer

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

> **⚠️ Risk Warning:** Trading Forex and CFDs carries high risk and may not be suitable for all investors. Algorithmic backtest results do not guarantee future performance. Always test thoroughly on a Demo account before deploying real capital.
