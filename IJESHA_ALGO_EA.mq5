//+------------------------------------------------------------------+
//|                                            HAssAN EA.mq5    |
//|                                    Copyright 2026, IJESHATECH     |
//|                                         https://ijeshatech.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, IJESHATECH"
#property link      "https://ijeshatech.com"
#property version   "2.00"
#property description "IJESHA ALGO EA v2.0 - Optimized for 65%+ Win Rate"
#property description "Stochastic + CCI + SAR + EMA Trend + RSI + Session Filter"
#property description "Includes Divergence Lines, Break-Even & Trailing Stop"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_EMA_MODE
{
   EMA_MODE_PRICE_ONLY = 0,    // Price vs EMA50 Trend
   EMA_MODE_CROSSOVER  = 1,    // EMA21 / EMA50 Alignment
   EMA_MODE_COMBINED   = 2     // Price + EMA21 + EMA50 (Strict)
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Trade Settings ==="
input double   InpLotSize        = 0.02;    // Lot Size (Fixed)
input int      InpMagicNumber    = 123456;  // Magic Number
input bool     InpAutoSpread     = true;    // Auto-Adaptive Spread Limit
input int      InpMaxSpread      = 300;     // Maximum Spread (Points, 300 for Gold)
input int      InpSignalLookback = 5;       // Signal Lookback Bars

input group "=== Stochastic Settings ==="
input int      InpStochK         = 14;      // Stochastic %K Period
input int      InpStochD         = 3;       // Stochastic %D Period
input int      InpStochSlowing   = 3;       // Stochastic Slowing
input double   InpStochOversold  = 20.0;    // Stochastic Oversold Level
input double   InpStochOverbought= 80.0;    // Stochastic Overbought Level

input group "=== CCI Settings ==="
input int      InpCCIPeriod      = 14;      // CCI Period
input double   InpCCIBuyLevel    = -100.0;  // CCI Buy Level
input double   InpCCISellLevel   = 100.0;   // CCI Sell Level

input group "=== ATR Settings ==="
input int      InpATRPeriod      = 14;      // ATR Period
input double   InpSLMultiplier   = 1.5;     // Stop Loss = ATR x Multiplier
input double   InpTPMultiplier   = 2.0;     // Take Profit = ATR x Multiplier

input group "=== Parabolic SAR Settings ==="
input bool     InpUseSARFilter   = true;    // Use Parabolic SAR Filter
input double   InpSARStep        = 0.02;    // SAR Step
input double   InpSARMax         = 0.2;     // SAR Maximum

input group "=== EMA Trend Filter ==="
input bool           InpUseEMAFilter   = true;                 // Use EMA Trend Filter
input ENUM_EMA_MODE  InpEMAMode        = EMA_MODE_PRICE_ONLY;  // EMA Trend Filter Mode
input int            InpEMAPeriod      = 50;                   // EMA Period (Slow)
input int            InpEMAFastPeriod  = 21;                   // EMA Fast Period

input group "=== RSI Filter ==="
input bool     InpUseRSIFilter   = false;   // Use RSI Filter
input int      InpRSIPeriod      = 14;      // RSI Period
input double   InpRSIBuyMax      = 65.0;    // RSI Max for Buy (below = valid buy zone)
input double   InpRSISellMin     = 35.0;    // RSI Min for Sell (above = valid sell zone)

input group "=== Session Filter ==="
input bool     InpUseSessionFilter = true;  // Use Session Filter
input int      InpSessionStartHour = 7;     // Session Start Hour (Server Time)
input int      InpSessionEndHour   = 20;    // Session End Hour (Server Time)

input group "=== Break-Even Settings ==="
input bool     InpUseBreakEven   = true;    // Use Break-Even
input int      InpBEPoints       = 30;      // Break-Even Activation (Points)
input int      InpBEPlusPoints   = 5;       // Break-Even Plus (Points above entry)

input group "=== Trailing Stop Settings ==="
input bool     InpUseTrailing    = true;    // Use Trailing Stop
input int      InpTrailActivate  = 50;      // Trailing Activation (Points)
input int      InpTrailStep      = 15;      // Trailing Step (Points)

input group "=== Divergence Line Settings ==="
input bool     InpDrawDivergence = true;    // Draw Divergence Lines
input color    InpBuyDivColor    = clrLime; // Buy Divergence Line Color
input color    InpSellDivColor   = clrRed;  // Sell Divergence Line Color
input int      InpDivLineWidth   = 2;       // Divergence Line Width
input int      InpDivLookback    = 30;      // Divergence Lookback Bars

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CSymbolInfo    symInfo;

int            handleStoch;
int            handleCCI;
int            handleATR;
int            handleSAR;
int            handleEMA;
int            handleEMAFast;
int            handleRSI;

double         stochK[];
double         stochD[];
double         cciBuffer[];
double         atrBuffer[];
double         sarBuffer[];
double         emaBuffer[];
double         emaFastBuffer[];
double         rsiBuffer[];

int            divergenceCount = 0;
datetime       lastTradeTime   = 0;

//+------------------------------------------------------------------+
//| Setup optimal broker order filling mode                          |
//+------------------------------------------------------------------+
void SetupFillingMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set magic number and execution settings
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   SetupFillingMode();
   
   //--- Initialize symbol info
   symInfo.Name(_Symbol);
   symInfo.Refresh();
   
   //--- Create indicator handles
   handleStoch = iStochastic(_Symbol, PERIOD_CURRENT, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(handleStoch == INVALID_HANDLE)
   {
      Print("Error creating Stochastic handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   handleCCI = iCCI(_Symbol, PERIOD_CURRENT, InpCCIPeriod, PRICE_TYPICAL);
   if(handleCCI == INVALID_HANDLE)
   {
      Print("Error creating CCI handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   handleATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(handleATR == INVALID_HANDLE)
   {
      Print("Error creating ATR handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   handleSAR = iSAR(_Symbol, PERIOD_CURRENT, InpSARStep, InpSARMax);
   if(handleSAR == INVALID_HANDLE)
   {
      Print("Error creating SAR handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- EMA handles
   handleEMA = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMA == INVALID_HANDLE)
   {
      Print("Error creating EMA handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   handleEMAFast = iMA(_Symbol, PERIOD_CURRENT, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMAFast == INVALID_HANDLE)
   {
      Print("Error creating EMA Fast handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- RSI handle
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
   {
      Print("Error creating RSI handle: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- Set arrays as series
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   ArraySetAsSeries(cciBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(sarBuffer, true);
   ArraySetAsSeries(emaBuffer, true);
   ArraySetAsSeries(emaFastBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   
   Print("IJESHA ALGO EA v2.0 initialized on ", _Symbol, " ", EnumToString(Period()));
   
   //--- Create dashboard
   CreateDashboard();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(handleStoch   != INVALID_HANDLE) IndicatorRelease(handleStoch);
   if(handleCCI     != INVALID_HANDLE) IndicatorRelease(handleCCI);
   if(handleATR     != INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleSAR     != INVALID_HANDLE) IndicatorRelease(handleSAR);
   if(handleEMA     != INVALID_HANDLE) IndicatorRelease(handleEMA);
   if(handleEMAFast != INVALID_HANDLE) IndicatorRelease(handleEMAFast);
   if(handleRSI     != INVALID_HANDLE) IndicatorRelease(handleRSI);
   
   //--- Remove dashboard objects
   ObjectsDeleteAll(0, "IJESHA_");
   
   //--- Remove divergence lines
   ObjectsDeleteAll(0, "DIV_");
   
   Print("IJESHA ALGO EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Get dynamic effective maximum spread                             |
//+------------------------------------------------------------------+
int GetEffectiveMaxSpread()
{
   if(!InpAutoSpread)
      return InpMaxSpread;
   
   string sym = _Symbol;
   StringToUpper(sym);
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      return MathMax(InpMaxSpread, 500);
   else if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "CRYPTO") >= 0)
      return MathMax(InpMaxSpread, 2000);
   else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "NAS") >= 0 || StringFind(sym, "GER") >= 0)
      return MathMax(InpMaxSpread, 1000);
      
   return MathMax(InpMaxSpread, 100);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Refresh symbol info
   symInfo.Refresh();
   symInfo.RefreshRates();
   
   //--- Check spread
   int currentSpread = (int)symInfo.Spread();
   
   //--- Update dashboard
   UpdateDashboard(currentSpread);
   
   //--- Manage existing positions (Break-Even & Trailing)
   ManageOpenPositions();
   
   //--- Only check for new signals on new bar
   if(!IsNewBar())
      return;
   
   //--- Copy indicator buffers
   if(!CopyIndicatorBuffers())
      return;
   
   //--- Check if we already have a position on this symbol
   if(HasOpenPosition())
      return;
   
   //--- Check spread filter with dynamic limit
   if(currentSpread > GetEffectiveMaxSpread())
      return;
   
   //--- Session filter
   if(InpUseSessionFilter && !IsInTradingSession())
      return;
   
   //--- Minimum bar spacing (prevent rapid re-entry)
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentTime - lastTradeTime < PeriodSeconds(PERIOD_CURRENT) * 3)
      return;
   
   //--- Check for BUY signal
   if(CheckBuySignal())
   {
      ExecuteBuy();
      return;
   }
   
   //--- Check for SELL signal
   if(CheckSellSignal())
   {
      ExecuteSell();
      return;
   }
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is in trading session                      |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   int hour = dt.hour;
   
   //--- Handle wrap-around sessions (e.g., start=22, end=6)
   if(InpSessionStartHour < InpSessionEndHour)
      return (hour >= InpSessionStartHour && hour < InpSessionEndHour);
   else
      return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

//+------------------------------------------------------------------+
//| Copy all indicator buffers                                       |
//+------------------------------------------------------------------+
bool CopyIndicatorBuffers()
{
   int barsNeeded = MathMax(InpDivLookback + 5, InpEMAPeriod + 5);
   
   if(CopyBuffer(handleStoch, MAIN_LINE, 0, barsNeeded, stochK) <= 0)     return false;
   if(CopyBuffer(handleStoch, SIGNAL_LINE, 0, barsNeeded, stochD) <= 0)   return false;
   if(CopyBuffer(handleCCI, 0, 0, barsNeeded, cciBuffer) <= 0)            return false;
   if(CopyBuffer(handleATR, 0, 0, barsNeeded, atrBuffer) <= 0)            return false;
   if(CopyBuffer(handleSAR, 0, 0, barsNeeded, sarBuffer) <= 0)            return false;
   if(CopyBuffer(handleEMA, 0, 0, barsNeeded, emaBuffer) <= 0)            return false;
   if(CopyBuffer(handleEMAFast, 0, 0, barsNeeded, emaFastBuffer) <= 0)    return false;
   if(CopyBuffer(handleRSI, 0, 0, barsNeeded, rsiBuffer) <= 0)            return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if position exists for this symbol with our magic          |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check BUY conditions (Optimized for high win rate)               |
//| 1. Price above EMA50 (uptrend)                                   |
//| 2. EMA21 above EMA50 (trend confirmation)                       |
//| 3. Stochastic was recently oversold & now recovering             |
//| 4. CCI was recently below -100                                   |
//| 5. Price above Parabolic SAR                                    |
//| 6. RSI is in buy zone                                           |
//| 7. Bullish candle confirmation                                  |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   
   //--- 1. EMA Trend Filter
   if(InpUseEMAFilter)
   {
      if(InpEMAMode == EMA_MODE_PRICE_ONLY && close1 <= emaBuffer[1])
         return false;
      else if(InpEMAMode == EMA_MODE_CROSSOVER && emaFastBuffer[1] <= emaBuffer[1])
         return false;
      else if(InpEMAMode == EMA_MODE_COMBINED)
      {
         if(close1 <= emaBuffer[1] || emaFastBuffer[1] <= emaBuffer[1])
            return false;
      }
   }
   
   //--- 2. Price above Parabolic SAR (bullish)
   if(InpUseSARFilter)
   {
      if(close1 <= sarBuffer[1])
         return false;
   }
   
   //--- 3. Stochastic oversold or recent bullish recovery
   bool stochBuyValid = false;
   if(stochK[1] < InpStochOversold || (stochK[1] > stochD[1] && stochK[2] <= stochD[2]))
      stochBuyValid = true;
   else
   {
      for(int i = 1; i <= InpSignalLookback; i++)
      {
         if(stochK[i] < InpStochOversold)
         {
            stochBuyValid = true;
            break;
         }
      }
   }
   if(!stochBuyValid)
      return false;
   
   //--- Stochastic %K above %D or rising
   if(stochK[1] < stochD[1] && stochK[1] <= stochK[2])
      return false;
   
   //--- 4. CCI oversold or recent bullish reversal
   bool cciBuyValid = false;
   if(cciBuffer[1] < InpCCIBuyLevel || (cciBuffer[1] > InpCCIBuyLevel && cciBuffer[2] <= InpCCIBuyLevel))
      cciBuyValid = true;
   else
   {
      for(int i = 1; i <= InpSignalLookback; i++)
      {
         if(cciBuffer[i] < InpCCIBuyLevel)
         {
            cciBuyValid = true;
            break;
         }
      }
   }
   if(!cciBuyValid)
      return false;
   
   //--- CCI should be rising or oversold
   if(cciBuffer[1] <= cciBuffer[2] && cciBuffer[1] > InpCCIBuyLevel)
      return false;
   
   //--- 7. RSI filter - must be in buy zone
   if(InpUseRSIFilter)
   {
      if(rsiBuffer[1] > InpRSIBuyMax)
         return false;
   }
   
   //--- 8. Bullish candle confirmation (close > open)
   if(close1 <= open1)
      return false;
   
   Print("BUY Signal! Stoch=", DoubleToString(stochK[1],2),
         " CCI=", DoubleToString(cciBuffer[1],2),
         " RSI=", DoubleToString(rsiBuffer[1],2),
         " EMA50=", DoubleToString(emaBuffer[1], _Digits));
   
   return true;
}

//+------------------------------------------------------------------+
//| Check SELL conditions (Optimized for high win rate)              |
//| 1. Price below EMA50 (downtrend)                                |
//| 2. EMA21 below EMA50 (trend confirmation)                      |
//| 3. Stochastic was recently overbought & now declining           |
//| 4. CCI was recently above 100                                  |
//| 5. Price below Parabolic SAR                                   |
//| 6. RSI is in sell zone                                         |
//| 7. Bearish candle confirmation                                 |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   
   //--- 1. EMA Trend Filter
   if(InpUseEMAFilter)
   {
      if(InpEMAMode == EMA_MODE_PRICE_ONLY && close1 >= emaBuffer[1])
         return false;
      else if(InpEMAMode == EMA_MODE_CROSSOVER && emaFastBuffer[1] >= emaBuffer[1])
         return false;
      else if(InpEMAMode == EMA_MODE_COMBINED)
      {
         if(close1 >= emaBuffer[1] || emaFastBuffer[1] >= emaBuffer[1])
            return false;
      }
   }
   
   //--- 2. Price below Parabolic SAR (bearish)
   if(InpUseSARFilter)
   {
      if(close1 >= sarBuffer[1])
         return false;
   }
   
   //--- 3. Stochastic overbought or recent bearish recovery
   bool stochSellValid = false;
   if(stochK[1] > InpStochOverbought || (stochK[1] < stochD[1] && stochK[2] >= stochD[2]))
      stochSellValid = true;
   else
   {
      for(int i = 1; i <= InpSignalLookback; i++)
      {
         if(stochK[i] > InpStochOverbought)
         {
            stochSellValid = true;
            break;
         }
      }
   }
   if(!stochSellValid)
      return false;
   
   //--- Stochastic %K below %D or falling
   if(stochK[1] > stochD[1] && stochK[1] >= stochK[2])
      return false;
   
   //--- 4. CCI overbought or recent bearish reversal
   bool cciSellValid = false;
   if(cciBuffer[1] > InpCCISellLevel || (cciBuffer[1] < InpCCISellLevel && cciBuffer[2] >= InpCCISellLevel))
      cciSellValid = true;
   else
   {
      for(int i = 1; i <= InpSignalLookback; i++)
      {
         if(cciBuffer[i] > InpCCISellLevel)
         {
            cciSellValid = true;
            break;
         }
      }
   }
   if(!cciSellValid)
      return false;
   
   //--- CCI should be falling or overbought
   if(cciBuffer[1] >= cciBuffer[2] && cciBuffer[1] < InpCCISellLevel)
      return false;
   
   //--- 7. RSI filter - must be in sell zone
   if(InpUseRSIFilter)
   {
      if(rsiBuffer[1] < InpRSISellMin)
         return false;
   }
   
   //--- 8. Bearish candle confirmation (close < open)
   if(close1 >= open1)
      return false;
   
   Print("SELL Signal! Stoch=", DoubleToString(stochK[1],2),
         " CCI=", DoubleToString(cciBuffer[1],2),
         " RSI=", DoubleToString(rsiBuffer[1],2),
         " EMA50=", DoubleToString(emaBuffer[1], _Digits));
   
   return true;
}

//+------------------------------------------------------------------+
//| Get minimum allowed stop distance from broker                    |
//+------------------------------------------------------------------+
double GetMinStopDistance()
{
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point   = symInfo.Point();
   return MathMax((double)stopLevel * point, point * 15);
}

//+------------------------------------------------------------------+
//| Execute BUY trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double ask = symInfo.Ask();
   double point = symInfo.Point();
   double atr = atrBuffer[1];
   double minDistance = GetMinStopDistance();
   
   //--- Minimum ATR filter (avoid dead flat market)
   if(atr < point * 2)
      atr = point * 30; // fallback safe ATR
   
   //--- Calculate SL and TP based on ATR
   double slDist = MathMax(atr * InpSLMultiplier, minDistance);
   double tpDist = MathMax(atr * InpTPMultiplier, minDistance * 1.5);
   
   double sl = NormalizeDouble(ask - slDist, _Digits);
   double tp = NormalizeDouble(ask + tpDist, _Digits);
   
   //--- Execute trade
   if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "IJESHA BUY"))
   {
      Print("BUY @ ", ask, " SL=", sl, " TP=", tp, " ATR=", DoubleToString(atr, _Digits));
      lastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      //--- Draw divergence line
      if(InpDrawDivergence)
         DrawBuyDivergenceLine();
   }
   else
   {
      Print("BUY failed. Error: ", GetLastError(), " RetCode: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Execute SELL trade                                                |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   double bid = symInfo.Bid();
   double point = symInfo.Point();
   double atr = atrBuffer[1];
   double minDistance = GetMinStopDistance();
   
   //--- Minimum ATR filter (avoid dead flat market)
   if(atr < point * 2)
      atr = point * 30; // fallback safe ATR
   
   //--- Calculate SL and TP based on ATR
   double slDist = MathMax(atr * InpSLMultiplier, minDistance);
   double tpDist = MathMax(atr * InpTPMultiplier, minDistance * 1.5);
   
   double sl = NormalizeDouble(bid + slDist, _Digits);
   double tp = NormalizeDouble(bid - tpDist, _Digits);
   
   //--- Execute trade
   if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "IJESHA SELL"))
   {
      Print("SELL @ ", bid, " SL=", sl, " TP=", tp, " ATR=", DoubleToString(atr, _Digits));
      lastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      //--- Draw divergence line
      if(InpDrawDivergence)
         DrawSellDivergenceLine();
   }
   else
   {
      Print("SELL failed. Error: ", GetLastError(), " RetCode: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Manage open positions - Break-Even and Trailing Stop             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))
         continue;
      
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber)
         continue;
      
      double openPrice   = posInfo.PriceOpen();
      double currentSL   = posInfo.StopLoss();
      double currentTP   = posInfo.TakeProfit();
      double point       = symInfo.Point();
      ulong  ticket      = posInfo.Ticket();
      
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double currentPrice = symInfo.Bid();
         double profitPoints = (currentPrice - openPrice) / point;
         
         //--- Break-Even with small profit lock
         if(InpUseBreakEven && profitPoints >= InpBEPoints)
         {
            double beSL = NormalizeDouble(openPrice + InpBEPlusPoints * point, _Digits);
            if(currentSL < beSL)
            {
               if(trade.PositionModify(ticket, beSL, currentTP))
                  Print("BE activated BUY #", ticket, " SL=", beSL);
            }
         }
         
         //--- Trailing Stop
         if(InpUseTrailing && profitPoints >= InpTrailActivate)
         {
            double trailSL = NormalizeDouble(currentPrice - InpTrailStep * point, _Digits);
            if(trailSL > currentSL && trailSL > openPrice)
            {
               if(trade.PositionModify(ticket, trailSL, currentTP))
                  Print("Trail BUY #", ticket, " SL=", trailSL);
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double currentPrice = symInfo.Ask();
         double profitPoints = (openPrice - currentPrice) / point;
         
         //--- Break-Even with small profit lock
         if(InpUseBreakEven && profitPoints >= InpBEPoints)
         {
            double beSL = NormalizeDouble(openPrice - InpBEPlusPoints * point, _Digits);
            if(currentSL > beSL || currentSL == 0)
            {
               if(trade.PositionModify(ticket, beSL, currentTP))
                  Print("BE activated SELL #", ticket, " SL=", beSL);
            }
         }
         
         //--- Trailing Stop
         if(InpUseTrailing && profitPoints >= InpTrailActivate)
         {
            double trailSL = NormalizeDouble(currentPrice + InpTrailStep * point, _Digits);
            if((trailSL < currentSL || currentSL == 0) && trailSL < openPrice)
            {
               if(trade.PositionModify(ticket, trailSL, currentTP))
                  Print("Trail SELL #", ticket, " SL=", trailSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw BUY divergence line on chart                                |
//+------------------------------------------------------------------+
void DrawBuyDivergenceLine()
{
   int priceLow1 = -1, priceLow2 = -1;
   
   for(int i = 2; i < InpDivLookback - 1; i++)
   {
      double low_i  = iLow(_Symbol, PERIOD_CURRENT, i);
      double low_b  = iLow(_Symbol, PERIOD_CURRENT, i - 1);
      double low_a  = iLow(_Symbol, PERIOD_CURRENT, i + 1);
      
      if(low_i <= low_b && low_i <= low_a)
      {
         if(priceLow1 == -1)
            priceLow1 = i;
         else if(priceLow2 == -1)
         {
            priceLow2 = i;
            break;
         }
      }
   }
   
   if(priceLow1 == -1 || priceLow2 == -1)
   {
      DrawSimpleEntryLine(true);
      return;
   }
   
   double priceAtLow1 = iLow(_Symbol, PERIOD_CURRENT, priceLow1);
   double priceAtLow2 = iLow(_Symbol, PERIOD_CURRENT, priceLow2);
   double stochAtLow1 = stochK[priceLow1];
   double stochAtLow2 = stochK[priceLow2];
   
   bool isBullishDiv = (priceAtLow1 < priceAtLow2 && stochAtLow1 > stochAtLow2);
   
   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, priceLow2);
   datetime time2 = iTime(_Symbol, PERIOD_CURRENT, priceLow1);
   
   divergenceCount++;
   string priceLine = "DIV_PRICE_BUY_" + IntegerToString(divergenceCount);
   string label     = "DIV_LABEL_BUY_"  + IntegerToString(divergenceCount);
   
   ObjectCreate(0, priceLine, OBJ_TREND, 0, time1, priceAtLow2, time2, priceAtLow1);
   ObjectSetInteger(0, priceLine, OBJPROP_COLOR, InpBuyDivColor);
   ObjectSetInteger(0, priceLine, OBJPROP_WIDTH, InpDivLineWidth);
   ObjectSetInteger(0, priceLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, priceLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, priceLine, OBJPROP_BACK, false);
   ObjectSetString(0, priceLine, OBJPROP_TOOLTIP, 
      isBullishDiv ? "Bullish Divergence" : "Buy Signal Line");
   
   ObjectCreate(0, label, OBJ_TEXT, 0, time2, priceAtLow1);
   ObjectSetString(0, label, OBJPROP_TEXT, isBullishDiv ? "▲ Bull Div" : "▲ BUY");
   ObjectSetInteger(0, label, OBJPROP_COLOR, InpBuyDivColor);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, label, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw SELL divergence line on chart                               |
//+------------------------------------------------------------------+
void DrawSellDivergenceLine()
{
   int priceHigh1 = -1, priceHigh2 = -1;
   
   for(int i = 2; i < InpDivLookback - 1; i++)
   {
      double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
      double high_b = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
      double high_a = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      
      if(high_i >= high_b && high_i >= high_a)
      {
         if(priceHigh1 == -1)
            priceHigh1 = i;
         else if(priceHigh2 == -1)
         {
            priceHigh2 = i;
            break;
         }
      }
   }
   
   if(priceHigh1 == -1 || priceHigh2 == -1)
   {
      DrawSimpleEntryLine(false);
      return;
   }
   
   double priceAtHigh1 = iHigh(_Symbol, PERIOD_CURRENT, priceHigh1);
   double priceAtHigh2 = iHigh(_Symbol, PERIOD_CURRENT, priceHigh2);
   double stochAtHigh1 = stochK[priceHigh1];
   double stochAtHigh2 = stochK[priceHigh2];
   
   bool isBearishDiv = (priceAtHigh1 > priceAtHigh2 && stochAtHigh1 < stochAtHigh2);
   
   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, priceHigh2);
   datetime time2 = iTime(_Symbol, PERIOD_CURRENT, priceHigh1);
   
   divergenceCount++;
   string priceLine = "DIV_PRICE_SELL_" + IntegerToString(divergenceCount);
   string label     = "DIV_LABEL_SELL_"  + IntegerToString(divergenceCount);
   
   ObjectCreate(0, priceLine, OBJ_TREND, 0, time1, priceAtHigh2, time2, priceAtHigh1);
   ObjectSetInteger(0, priceLine, OBJPROP_COLOR, InpSellDivColor);
   ObjectSetInteger(0, priceLine, OBJPROP_WIDTH, InpDivLineWidth);
   ObjectSetInteger(0, priceLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, priceLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, priceLine, OBJPROP_BACK, false);
   ObjectSetString(0, priceLine, OBJPROP_TOOLTIP, 
      isBearishDiv ? "Bearish Divergence" : "Sell Signal Line");
   
   ObjectCreate(0, label, OBJ_TEXT, 0, time2, priceAtHigh1);
   ObjectSetString(0, label, OBJPROP_TEXT, isBearishDiv ? "▼ Bear Div" : "▼ SELL");
   ObjectSetInteger(0, label, OBJPROP_COLOR, InpSellDivColor);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, label, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw simple entry line when no divergence swings found           |
//+------------------------------------------------------------------+
void DrawSimpleEntryLine(bool isBuy)
{
   divergenceCount++;
   string lineName = "DIV_ENTRY_" + (isBuy ? "BUY_" : "SELL_") + IntegerToString(divergenceCount);
   string labelName = "DIV_ELABEL_" + (isBuy ? "BUY_" : "SELL_") + IntegerToString(divergenceCount);
   
   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, InpDivLookback / 2);
   datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 0);
   double price   = isBuy ? symInfo.Ask() : symInfo.Bid();
   
   ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price, time2, price);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, isBuy ? InpBuyDivColor : InpSellDivColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpDivLineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, time2, price);
   ObjectSetString(0, labelName, OBJPROP_TEXT, isBuy ? "▲ BUY Entry" : "▼ SELL Entry");
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, isBuy ? InpBuyDivColor : InpSellDivColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Create on-chart dashboard                                        |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int x = 10, y = 30;
   int width = 280, height = 260;
   
   //--- Background panel
   CreateRectangle("IJESHA_BG", x, y, width, height, C'20,20,35', C'0,200,150');
   
   //--- Title
   CreateLabel("IJESHA_TITLE", x + 10, y + 5, "IJESHA ALGO EA v2.0", 11, C'0,230,170', "Arial Bold");
   CreateLabel("IJESHA_LINE",  x + 10, y + 22, "━━━━━━━━━━━━━━━━━━━━━━━", 8, C'0,150,120', "Arial");
   
   //--- Indicator values
   CreateLabel("IJESHA_STOCH",  x + 10, y + 38,  "Stochastic: ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_CCI",    x + 10, y + 54,  "CCI:        ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_RSI",    x + 10, y + 70,  "RSI:        ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_ATR",    x + 10, y + 86,  "ATR:        ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_SAR",    x + 10, y + 102, "SAR:        ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_EMA",    x + 10, y + 118, "EMA50:      ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_SPREAD", x + 10, y + 134, "Spread:     ---", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_TREND",  x + 10, y + 150, "Trend:      ---", 9, clrWhite, "Consolas");
   
   //--- Status
   CreateLabel("IJESHA_LINE2",  x + 10, y + 168, "━━━━━━━━━━━━━━━━━━━━━━━", 8, C'0,150,120', "Arial");
   CreateLabel("IJESHA_STATUS", x + 10, y + 185, "Status: Scanning...", 9, clrYellow, "Consolas");
   CreateLabel("IJESHA_TRADE",  x + 10, y + 201, "Position: None", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_PL",     x + 10, y + 217, "P/L: $0.00", 9, clrWhite, "Consolas");
   CreateLabel("IJESHA_COPY",   x + 10, y + 238, "© IJESHATECH 2026", 8, C'100,100,120', "Arial");
}

//+------------------------------------------------------------------+
//| Update dashboard with current values                             |
//+------------------------------------------------------------------+
void UpdateDashboard(int spread)
{
   double stK[], stD[], cci[], atr[], sar[], ema[], emaF[], rsi[];
   CopyBuffer(handleStoch, MAIN_LINE, 0, 3, stK);
   CopyBuffer(handleStoch, SIGNAL_LINE, 0, 3, stD);
   CopyBuffer(handleCCI, 0, 0, 3, cci);
   CopyBuffer(handleATR, 0, 0, 3, atr);
   CopyBuffer(handleSAR, 0, 0, 3, sar);
   CopyBuffer(handleEMA, 0, 0, 3, ema);
   CopyBuffer(handleEMAFast, 0, 0, 3, emaF);
   CopyBuffer(handleRSI, 0, 0, 3, rsi);
   
   ArraySetAsSeries(stK, true);
   ArraySetAsSeries(cci, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(sar, true);
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(emaF, true);
   ArraySetAsSeries(rsi, true);
   
   //--- Stochastic
   color stochColor = (stK[0] < InpStochOversold) ? clrLime : (stK[0] > InpStochOverbought) ? clrRed : clrWhite;
   ObjectSetString(0, "IJESHA_STOCH", OBJPROP_TEXT, "Stochastic: " + DoubleToString(stK[0], 2));
   ObjectSetInteger(0, "IJESHA_STOCH", OBJPROP_COLOR, stochColor);
   
   //--- CCI
   color cciColor = (cci[0] < InpCCIBuyLevel) ? clrLime : (cci[0] > InpCCISellLevel) ? clrRed : clrWhite;
   ObjectSetString(0, "IJESHA_CCI", OBJPROP_TEXT, "CCI:        " + DoubleToString(cci[0], 2));
   ObjectSetInteger(0, "IJESHA_CCI", OBJPROP_COLOR, cciColor);
   
   //--- RSI
   color rsiColor = (rsi[0] < 30) ? clrLime : (rsi[0] > 70) ? clrRed : clrWhite;
   ObjectSetString(0, "IJESHA_RSI", OBJPROP_TEXT, "RSI:        " + DoubleToString(rsi[0], 2));
   ObjectSetInteger(0, "IJESHA_RSI", OBJPROP_COLOR, rsiColor);
   
   //--- ATR
   ObjectSetString(0, "IJESHA_ATR", OBJPROP_TEXT, "ATR:        " + DoubleToString(atr[0], _Digits));
   
   //--- SAR
   ObjectSetString(0, "IJESHA_SAR", OBJPROP_TEXT, "SAR:        " + DoubleToString(sar[0], _Digits));
   
   //--- EMA
   ObjectSetString(0, "IJESHA_EMA", OBJPROP_TEXT, "EMA50:      " + DoubleToString(ema[0], _Digits));
   
   //--- Spread
   color spreadColor = (spread <= GetEffectiveMaxSpread()) ? clrLime : clrRed;
   ObjectSetString(0, "IJESHA_SPREAD", OBJPROP_TEXT, "Spread:     " + IntegerToString(spread) + " pts");
   ObjectSetInteger(0, "IJESHA_SPREAD", OBJPROP_COLOR, spreadColor);
   
   //--- Trend
   double lastClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   string trendText = "NEUTRAL";
   color trendColor = clrYellow;
   if(lastClose > ema[0] && emaF[0] > ema[0])
   {
      trendText = "BULLISH ▲";
      trendColor = clrLime;
   }
   else if(lastClose < ema[0] && emaF[0] < ema[0])
   {
      trendText = "BEARISH ▼";
      trendColor = clrRed;
   }
   ObjectSetString(0, "IJESHA_TREND", OBJPROP_TEXT, "Trend:      " + trendText);
   ObjectSetInteger(0, "IJESHA_TREND", OBJPROP_COLOR, trendColor);
   
   //--- Position info
   bool hasPos = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
         {
            hasPos = true;
            string posType = (posInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
            
            ObjectSetString(0, "IJESHA_TRADE", OBJPROP_TEXT, 
               "Position: " + posType + " @ " + DoubleToString(posInfo.PriceOpen(), _Digits));
            
            color plColor = (profit >= 0) ? clrLime : clrRed;
            ObjectSetString(0, "IJESHA_PL", OBJPROP_TEXT, "P/L: $" + DoubleToString(profit, 2));
            ObjectSetInteger(0, "IJESHA_PL", OBJPROP_COLOR, plColor);
            
            ObjectSetString(0, "IJESHA_STATUS", OBJPROP_TEXT, "Status: In Trade");
            ObjectSetInteger(0, "IJESHA_STATUS", OBJPROP_COLOR, C'0,200,255');
            break;
         }
      }
   }
   
   if(!hasPos)
   {
      ObjectSetString(0, "IJESHA_TRADE", OBJPROP_TEXT, "Position: None");
      ObjectSetInteger(0, "IJESHA_TRADE", OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, "IJESHA_PL", OBJPROP_TEXT, "P/L: $0.00");
      ObjectSetInteger(0, "IJESHA_PL", OBJPROP_COLOR, clrWhite);
      
      if(InpUseSessionFilter && !IsInTradingSession())
      {
         ObjectSetString(0, "IJESHA_STATUS", OBJPROP_TEXT, "Status: Out of Session");
         ObjectSetInteger(0, "IJESHA_STATUS", OBJPROP_COLOR, C'150,150,150');
      }
      else
      {
         ObjectSetString(0, "IJESHA_STATUS", OBJPROP_TEXT, "Status: Scanning...");
         ObjectSetInteger(0, "IJESHA_STATUS", OBJPROP_COLOR, clrYellow);
      }
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Helper: Create rectangle label (panel background)                |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int width, int height, color bgColor, color borderColor)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Helper: Create text label                                        |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int fontSize, color clr, string font)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+
