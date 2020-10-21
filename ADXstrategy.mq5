//+------------------------------------------------------------------+
//|                                                  ADXstrategy.mq5 |
//|                                     Copyright 2020, Deepware Srl |
//|                                          https://www.deepware.it |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Deepware Srl"
#property link      "https://www.deepware.it"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
//--- available signals
#include <Expert\Signal\SignalCCI.mqh>
//--- available trailing
#include <Expert\Trailing\TrailingNone.mqh>
//--- available money management
#include <Expert\Money\MoneyFixedLot.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string             Expert_Title         ="ADXstrategy"; // Document name
ulong                    Expert_MagicNumber   =26860;         //
bool                     Expert_EveryTick     =false;         //
//--- inputs for main signal
input int                Signal_ThresholdOpen =10;            // Signal threshold value to open [0...100]
input int                Signal_ThresholdClose=10;            // Signal threshold value to close [0...100]
input double             Signal_PriceLevel    =0.0;           // Price level to execute a deal
input double             Signal_StopLevel     =50.0;          // Stop Loss level (in points)
input double             Signal_TakeLevel     =50.0;          // Take Profit level (in points)
input int                Signal_Expiration    =4;             // Expiration of pending orders (in bars)
input int                Signal_CCI_PeriodCCI =20;            // Commodity Channel Index(20,...) Period of calculation
input ENUM_APPLIED_PRICE Signal_CCI_Applied   =PRICE_CLOSE;   // Commodity Channel Index(20,...) Prices series
input double             Signal_CCI_Weight    =1.0;           // Commodity Channel Index(20,...) Weight [0...1.0]
//--- inputs for money
input double             Money_FixLot_Percent =10.0;          // Percent
input double             Money_FixLot_Lots    =0.1;           // Fixed volume
input group "Custom Parameters";
input int                adx_period           =14;
input int                cci_period           =20;
input int                ma_slow_period       =200;
input int                ma_fast_period       =20;
input ENUM_APPLIED_PRICE cci_applied_price    =PRICE_TYPICAL;  // type of price
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;

//--- Moving Averages
// FAST - shorter period
double ma_fast_Buffer[]; // Buffer Fast Moving Average

// SLOW - longer period
double ma_slow_Buffer[]; // Buffer Slow Moving Average

// ADX
double adx_Buffer[]; // ADX buffer

// CCI
double cci_Buffer[]; // ADX buffer

int adx_handle;
int cci_handle;
   
int slow_ma_handle;
int fast_ma_handle;

//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing expert");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Creating signal
   CExpertSignal *signal=new CExpertSignal;
   if(signal==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating signal");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//---
   ExtExpert.InitSignal(signal);
   signal.ThresholdOpen(Signal_ThresholdOpen);
   signal.ThresholdClose(Signal_ThresholdClose);
   signal.PriceLevel(Signal_PriceLevel);
   signal.StopLevel(Signal_StopLevel);
   signal.TakeLevel(Signal_TakeLevel);
   signal.Expiration(Signal_Expiration);
//--- Creating filter CSignalCCI
   CSignalCCI *filter0=new CSignalCCI;
   if(filter0==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating filter0");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter0);
//--- Set filter parameters
   filter0.PeriodCCI(Signal_CCI_PeriodCCI);
   filter0.Applied(Signal_CCI_Applied);
   filter0.Weight(Signal_CCI_Weight);
//--- Creation of trailing object
   CTrailingNone *trailing=new CTrailingNone;
   if(trailing==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Add trailing to expert (will be deleted automatically))
   if(!ExtExpert.InitTrailing(trailing))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Set trailing parameters
//--- Creation of money object
   CMoneyFixedLot *money=new CMoneyFixedLot;
   if(money==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating money");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Add money to expert (will be deleted automatically))
   if(!ExtExpert.InitMoney(money))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing money");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Set money parameters
   money.Percent(Money_FixLot_Percent);
   money.Lots(Money_FixLot_Lots);
//--- Check all trading objects parameters
   if(!ExtExpert.ValidationSettings())
     {
      //--- failed
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators())
     {
      //--- failed
      printf(__FUNCTION__+": error initializing indicators");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
      adx_handle = iADX(_Symbol, _Period,adx_period);
      cci_handle = iCCI(_Symbol, _Period,cci_period,cci_applied_price);
   
      slow_ma_handle = iMA(_Symbol, _Period,ma_slow_period,0,MODE_SMA,PRICE_CLOSE);
      fast_ma_handle = iMA(_Symbol, _Period,ma_fast_period,0,MODE_SMA,PRICE_CLOSE);
//--- ok
   ChartIndicatorAdd(0,0,slow_ma_handle); 
   ChartIndicatorAdd(0,0,fast_ma_handle);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  
   IndicatorRelease(adx_handle);
   IndicatorRelease(cci_handle);
   IndicatorRelease(slow_ma_handle);
   IndicatorRelease(fast_ma_handle);
  
   ExtExpert.Deinit();
  }
//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   int cnt, ticket, total;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   ArraySetAsSeries(ma_fast_Buffer, true);
   ArraySetAsSeries(ma_slow_Buffer, true);
   ArraySetAsSeries(adx_Buffer, true);
   ArraySetAsSeries(cci_Buffer, true);
   
   CopyBuffer(fast_ma_handle,0,0,4,ma_fast_Buffer);
   CopyBuffer(slow_ma_handle,0,0,4,ma_slow_Buffer);
   
   CopyBuffer(adx_handle,0,0,4,adx_Buffer);
   CopyBuffer(cci_handle,0,0,4,cci_Buffer);
   
   double ma_fast_value = NormalizeDouble(ma_fast_Buffer[0], 4);
   double ma_slow_value = NormalizeDouble(ma_slow_Buffer[0], 4);
   double adx_value     = NormalizeDouble(adx_Buffer[0]    , 4);
   double cci_value     = NormalizeDouble(cci_Buffer[0]    , 4);
   
    //--- Feed candle buffers with data:
    //CopyRates(_Symbol,_Period,0,4,candle);
    //ArraySetAsSeries(candle,true);
    
   //MqlTick Latest_Price; // Structure to get the latest prices      
   //SymbolInfoTick(Symbol() ,Latest_Price); // Assign current prices to structure 
   //double price_value=Latest_Price.last;
   //double price_value=Latest_Price.bid; // depart from price Bid
   
   double price_value=SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   
   if(price_value>ma_fast_value &&
      price_value>ma_slow_value &&
      adx_value>25 &&
      cci_value>100
   ){
      //LONG
      MqlTradeRequest request={0};
      request.action=TRADE_ACTION_DEAL;         // setting a pending order
      request.magic=Expert_MagicNumber;            // ORDER_MAGIC
      request.symbol=Symbol();                      // symbol
      request.volume=0.1;                          // volume in 0.1 lots
      request.sl=0;                                // Stop Loss is not specified
      request.tp=0;                                // Take Profit is not specified    
      request.type=ORDER_TYPE_BUY;                        // order type 
      request.deviation=5;                                     // allowed deviation from the price
      request.type_filling = SYMBOL_FILLING_FOK;///
      //--- form the order type
      
      //--- send a trade request
      MqlTradeResult result={0};
      //if(!OrderSend(request,result))
            //PrintFormat("OrderSend error %d",GetLastError());     // if unable to send the request, output the error code
            
      //--- information about the operation
      PrintFormat("long: price=%.4f  ma_slow=%.4f  ma_fast=%.4f adx=%.4f cci=%.4f",ma_slow_value,ma_fast_value,adx_value,cci_value);
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   }

   if(price_value<ma_fast_value &&
      price_value<ma_slow_value &&
      adx_value>25 &&
      cci_value<-100
   ){
      //SHORT
      MqlTradeRequest request={0};
      request.action=TRADE_ACTION_DEAL;         // setting a pending order
      request.magic=Expert_MagicNumber;            // ORDER_MAGIC
      request.symbol=Symbol();                      // symbol
      request.volume=0.1;                          // volume in 0.1 lots
      request.sl=0;                                // Stop Loss is not specified
      request.tp=0;                                // Take Profit is not specified
      request.type=ORDER_TYPE_SELL;                        // order type 
      request.deviation=5;                                     // allowed deviation from the price
      request.type_filling = SYMBOL_FILLING_FOK;///
      //--- form the order type
      
      //--- send a trade request
      MqlTradeResult result={0};
      //if(!OrderSend(request,result))
            //PrintFormat("OrderSend error %d",GetLastError());     // if unable to send the request, output the error code
            
      PrintFormat("short: price=%.4f  ma_slow=%.4f  ma_fast=%.4f adx=%.4f cci=%.4f",ma_slow_value,ma_fast_value,adx_value,cci_value);
      //--- information about the operation
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   }
   
   ExtExpert.OnTick();
  }
//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ExtExpert.OnTrade();
  }
//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ExtExpert.OnTimer();
  }
//+------------------------------------------------------------------+
