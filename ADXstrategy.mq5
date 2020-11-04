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
input string             Expert_Title         ="ADXstrategy";  // Document name
ulong                    Expert_MagicNumber   =26860;          // Magic Namber

//--- inputs for money
input group "Money";
input double             Money_FixLot_Percent =10.0;           // Percent
input double             Money_FixLot_Lots    =0.1;            // Fixed volume
input group "Indicator parameters";
input int                adx_period           =14;             // ADX period
input int                cci_period           =20;             // CCI period
input int                ma_slow_period       =200;            // Slow Moving Average period
input int                ma_fast_period       =20;             // Fast Moving Average period
input ENUM_APPLIED_PRICE cci_applied_price    =PRICE_TYPICAL;  // type of price

input group "BUY conditions";
input int                adx_limit_buy        =25;             // BUY Condition for ADX (ADX>x)
input int                cci_limit_buy        =100;            // BUY Condition for CCI (CCI>x)


input group "SELL conditions";
input int                adx_limit_sell       =25;             // SELL Condition for ADX (ADX>x)
input int                cci_limit_sell       =-100;           // SELL Condition for CCI (CCI>x)



input group "Market Time";
input int StartTime = 7;                                       // Time to allow trading to start
input int EndTime = 20;                                        // Time to stop trading
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+

int adx_handle;
int cci_handle;
   
int slow_ma_handle;
int fast_ma_handle;

//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit()
  {

      slow_ma_handle = iMA(_Symbol, _Period,ma_slow_period,0,MODE_SMA,PRICE_CLOSE);
      fast_ma_handle = iMA(_Symbol, _Period,ma_fast_period,0,MODE_SMA,PRICE_CLOSE);
      //--- Initializing expert
      cci_handle = iCCI(_Symbol, _Period,cci_period,cci_applied_price);
      //--- Initializing expert
      adx_handle = iADX(_Symbol, _Period, adx_period);

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
  }
//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
  
  MqlDateTime dt_struct;
  datetime dtSer=TimeCurrent(dt_struct);
  if( (dt_struct.hour<=StartTime) || (dt_struct.hour>=EndTime) || dt_struct.day_of_week==0 /* Sunday*/|| dt_struct.day_of_week==6 /*Saturday*/){
         CloseAllPositions();
         return; //Preferd Trading Hours
  }
  
  int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); // number of decimal places
  double price_value=SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
  double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point value of 1 pip
  
   int calculated=BarsCalculated(cci_handle);
   if(calculated<=0)
     {
      PrintFormat("BarsCalculated() returned %d, error code %d",calculated,GetLastError());
      return;
     }
   
   int cnt, ticket;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double ma_fast_value = iIndicatorGetLast(fast_ma_handle,1,digits);
   double ma_slow_value = iIndicatorGetLast(slow_ma_handle,1,digits);
   double adx_value     = iIndicatorGetLast(adx_handle,1,digits);
   double cci_value     = iIndicatorGetLast(cci_handle,1,digits);

   if(price_value>ma_fast_value &&
      price_value>ma_slow_value+100*point &&
      adx_value>adx_limit_buy &&
      cci_value>cci_limit_buy && 
      price_value>iHigh(NULL,0,1) && 
      PositionsTotal()==0
   ){
      //LONG
      
      double sl=iLow(NULL,0,1);
      double tp = price_value+(((int)((price_value - sl)/point)*2)*point);
            
      ulong ticket_order=OpenOrder(Expert_MagicNumber, ORDER_TYPE_BUY,sl,tp,"[EA] Enter Buy");
      PrintFormat("[EA] long #%I64d: price=%.6f  ma_slow=%.6f ma_fast=%.6f adx=%.6f cci=%.6f sl=%f tp=%f",ticket_order,price_value,ma_slow_value,ma_fast_value,adx_value,cci_value,sl,tp);
   }

   if(price_value<ma_fast_value &&
      price_value<ma_slow_value-100*point &&
      adx_value>adx_limit_sell &&
      cci_value<cci_limit_sell &&
      price_value<iLow(NULL,0,1) && 
      PositionsTotal()==0
   ){
      //SHORT
      
      double sl=iHigh(NULL,0,1);
      double tp = price_value-(((int)((sl - price_value)/point)*2)*point);
      
      ulong ticket_order=OpenOrder(Expert_MagicNumber, ORDER_TYPE_SELL,sl,tp,"[EA] Enter Sell");
      PrintFormat("[EA] short #%I64d: price=%.6f ma_slow=%.6f ma_fast=%.6f adx=%.6f cci=%.6f sl=%f tp=%f",ticket_order,price_value,ma_slow_value,ma_fast_value,adx_value,cci_value,sl,tp);

   }
   
   int total_pos=PositionsTotal(); // number of open positions 
   
   if(total_pos!=0){
      ClosePositions(total_pos);
   }

}
//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {

  }
//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {

  }
//+------------------------------------------------------------------+

double iIndicatorGetLast(int handle,int index, int digits)
{
   double indicator_values[];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iRSI array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle,0,0,index+1,indicator_values)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(EMPTY_VALUE);
     }
   return(NormalizeDouble(indicator_values[index], digits));
}
  
ulong OpenOrder(long const magic_number, ENUM_ORDER_TYPE typeOrder, double sl, double tp, string order_comment)
{

      double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point
      double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);             // current price for closing LONG
      double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);             

      MqlTradeRequest request={0};
      request.action=TRADE_ACTION_DEAL;         // setting a pending order
      request.magic=Expert_MagicNumber;            // ORDER_MAGIC
      request.symbol=Symbol();                      // symbol
      request.volume=Money_FixLot_Lots;                          // volume in 0.1 lots
      request.sl=sl;                                // Stop Loss is not specified
      request.tp=tp;                                // Take Profit is not specified
      request.type=typeOrder;                        // order type 
      request.deviation=5;                                     // allowed deviation from the price
      request.type_filling = SYMBOL_FILLING_FOK;///
      
      request.comment=order_comment;
      
      //--- form the order type
      
      //--- send a trade request
      MqlTradeResult result={0};

//--- reset the last error code to zero
   ResetLastError();
//--- send request
   bool success=OrderSend(request,result);
//--- if the result fails - try to find out why
   if(!success)
     {
      int answer=result.retcode;
      Print("[EA] TradeLog: Trade request failed. Error = ",GetLastError());
      switch(answer)
        {
         //--- requote
         case 10004:
           {
            Print("[EA] TRADE_RETCODE_REQUOTE");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- order is not accepted by the server
         case 10006:
           {
            Print("[EA] TRADE_RETCODE_REJECT");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid price
         case 10015:
           {
            Print("[EA] TRADE_RETCODE_INVALID_PRICE");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid SL and/or TP
         case 10016:
           {
            Print("[EA] TRADE_RETCODE_INVALID_STOPS");
            Print("[EA] request.sl = ",request.sl," request.tp = ",request.tp);
            Print("[EA] result.ask = ",result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid volume
         case 10014:
           {
            Print("[EA] TRADE_RETCODE_INVALID_VOLUME");
            Print("[EA] request.volume = ",request.volume,"   result.volume = ",
                  result.volume);
            break;
           }
         //--- not enough money for a trade operation 
         case 10019:
           {
            Print("[EA] TRADE_RETCODE_NO_MONEY");
            Print("[EA] request.volume = ",request.volume,"   result.volume = ",
                  result.volume,"   result.comment = ",result.comment);
            break;
           }
         //--- some other reason, output the server response code 
         default:
           {
            Print("[EA] Other answer = ",answer);
           }
        }
     }
        
     return result.deal;

}

void ClosePositions(int total_pos){

   double price_value=SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   
   for(int i=total_pos-1; i>=0; i--)
   {
   
      ulong ticket=OrderGetTicket(i);
      
      //--- parameters of the order
      ulong  position_ticket=PositionGetTicket(i);                                      // ticket of the position
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbol 
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
      double volume=PositionGetDouble(POSITION_VOLUME);                                 // volume of the position

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position

      //--- if the MagicNumber matches
      if(magic==Expert_MagicNumber)
        {
         //--- zeroing the request and result values
         MqlTradeRequest request={0};
         MqlTradeResult result={0};
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action   = TRADE_ACTION_DEAL;        // type of trade operation
         request.position = position_ticket;          // ticket of the position
         request.symbol   = position_symbol;          // symbol 
         request.volume   = volume;                   // volume of the position
         request.deviation= 5;                        // allowed deviation from the price
         request.magic    = Expert_MagicNumber;       // MagicNumber of the position
         request.type_filling = SYMBOL_FILLING_FOK;///

         //--- set the price and order type depending on the position type
         if(type==POSITION_TYPE_BUY && price_value<iLow(NULL,0,1))
         {
               request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
               request.type =ORDER_TYPE_SELL;
               //request.comment=StringFormat("Close long #%I64d price %f low %f", position_ticket,price_value,iLow(NULL,0,1));
               //--- output information about the closure
               
               //--- send the request
               if(!OrderSend(request,result))
                  PrintFormat("[EA] OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
               
               PrintFormat("[EA] Close long #%I64d price: %.6f Low: %.6f",position_ticket,price_value,iLow(NULL,0,1));
               
         } else if(type==POSITION_TYPE_SELL && price_value>iHigh(NULL,0,1))
         {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
            //request.comment=StringFormat("Close short #%I64d price %f high %f", position_ticket,price_value,iHigh(NULL,0,1));
            //--- output information about the closure
            
            //--- send the request
            if(!OrderSend(request,result))
               PrintFormat("[EA] OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
               
            PrintFormat("[EA] Close short #%I64d price: %.6f High: %.6f",position_ticket,price_value,iHigh(NULL,0,1));
        }        
    }
  }
}

void CloseAllPositions(){

   int total_pos=PositionsTotal(); // number of open positions 
   
   double price_value=SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   
   for(int i=total_pos-1; i>=0; i--)
   {
   
      ulong ticket=OrderGetTicket(i);
      
      //--- parameters of the order
      ulong  position_ticket=PositionGetTicket(i);                                      // ticket of the position
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbol 
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
      double volume=PositionGetDouble(POSITION_VOLUME);                                 // volume of the position
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position
      
      
      //--- output information about the position
      /*
      PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                  position_ticket,
                  position_symbol,
                  EnumToString(type),
                  volume,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
                  magic);
                  */
                  
      //--- if the MagicNumber matches
      if(magic==Expert_MagicNumber)
        {
         //--- zeroing the request and result values
         MqlTradeRequest request={0};
         MqlTradeResult result={0};
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action   = TRADE_ACTION_DEAL;        // type of trade operation
         request.position = position_ticket;          // ticket of the position
         request.symbol   = position_symbol;          // symbol 
         request.volume   = volume;                   // volume of the position
         request.deviation= 5;                        // allowed deviation from the price
         request.magic    = Expert_MagicNumber;       // MagicNumber of the position
         request.type_filling = SYMBOL_FILLING_FOK;///
         //--- set the price and order type depending on the position type
         if(type==POSITION_TYPE_BUY)
         {
               request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
               request.type =ORDER_TYPE_SELL;
               //request.comment=StringFormat("Close long #%I64d price %f low %f", position_ticket,price_value,iLow(NULL,0,1));
               //--- output information about the closure
               
               //--- send the request
               if(!OrderSend(request,result))
                  PrintFormat("[EA] OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
               
               PrintFormat("[EA] Close long #%I64d price: %.6f Low: %.6f",position_ticket,price_value,iLow(NULL,0,1));
               
         } else if(type==POSITION_TYPE_SELL)
         {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
            //request.comment=StringFormat("Close short #%I64d price %f high %f", position_ticket,price_value,iHigh(NULL,0,1));
            //--- output information about the closure
            
            //--- send the request
            if(!OrderSend(request,result))
               PrintFormat("[EA] OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
               
            PrintFormat("[EA] Close short #%I64d price: %.6f High: %.6f",position_ticket,price_value,iHigh(NULL,0,1));
        }        
    }
  }
}