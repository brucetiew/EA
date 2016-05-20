//+------------------------------------------------------------------+
//|                                                     Pipochan.mq4 |
//|                            https://www.linkedin.com/in/brucetiew |
//+------------------------------------------------------------------+
#property copyright "Bruce Tiew"
#property link      "https://www.linkedin.com/in/brucetiew"
#property version   "1.00"
#property strict

// Pipochan Paramaters
extern string  Separator1 = "----------Trading Rules Variables -----------";
extern int     DonchianPeriodsEntry = 20;
extern int     DonchianPeriodsExit = 10;
extern int     DonchianHiBufferIdx = 0;
extern int     DonchianLoBufferIdx = 1;
extern int     MaximumPosition = 4;
extern int     ATRPeriod = 20;
extern int     SLMultiplier = 2;    // stop loss amount in units of volatility
extern int     TPMultiplier = 2;    // take profit amount in units of valatility
extern double  RiskPerTrade = 1.0;  // value in percentage
extern string  Separator2 = "----------Expert Advisor General Settings-----";
extern bool    IsECNBroker = true;
extern bool    IsUSDepositAcoount = true;
extern int     MagicNumber = 1688;
extern int     DonchianStartShift = 1;
extern int     ATRStartShift = 1;
extern int     NumberofBars = 50;
extern int     Slippage = 3;        // value in pips
extern int     SleepInterval = 50;  // value in milliseconds
extern int     MaximumAttemptPerTick = 4;

// Internal Global Variables
int PointPerPip = 1;
double DecimalPerPip = Point;
double YenPairMultiplier = 1;
double FirstN;
double FirstStop;
bool LockEntry = false;

enum pos_status
{
   pos_increase,
   pos_decrease,
   pos_unchange
};

/**
 * Pipochan initialization
 */
int OnInit()
{
   // change pip to point multiplier for 5 digits broker
   if (Digits == 5 || Digits == 3)
   {
      PointPerPip = 10;
      DecimalPerPip *= 10;
   }
   
   // change Yen Pair multiplier for 5 digits broker
   if (Digits == 3 || Digits == 2)
   {
      YenPairMultiplier = 100;
   }
   
   return 0;
}

/**
 * Pipochan deinitialization
 */
void OnDeinit(const int reason)
{
}

/**
 * Pipochan entry
 */
int start()
{
   // Initialize globals for pipochan strategies
   double entry_hi = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsEntry, DonchianStartShift, NumberofBars, DonchianHiBufferIdx, 1);
   double entry_lo = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsEntry, DonchianStartShift, NumberofBars, DonchianLoBufferIdx, 1);
   double exit_hi = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsExit, DonchianStartShift, NumberofBars, DonchianHiBufferIdx, 1);
   double exit_lo = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsExit, DonchianStartShift, NumberofBars, DonchianLoBufferIdx, 1);
   
   // get last closing price
   double close = iClose(NULL, 0, 1);
   
   // get stop loss and take profit values
   double N = iATR(NULL, 0, ATRPeriod, ATRStartShift);
   double SL = (SLMultiplier * N)/DecimalPerPip; // convert value to pip
   double TP= (TPMultiplier * N)/DecimalPerPip;  // convert value to pip
   
   // get lot size
   double lot_size = GetLotSize(SL, true);
   
   // An entry signal is defined as a breakout of the closing price above the entry high for a long position, and below the tnry low for a short position.
   bool long_entry_breakout = EntryHighCrossing(close, entry_hi) == 1 ? true : false;
   bool short_entry_breakout = EntryLowCrossing(close, entry_lo) == 2 ? true : false;
   
   // An exit signal is defined as a breakout of a long position's closing price cross below exit low and a short position's closing price cross above exit high
   bool long_exit_breakout = ExitLoCrossing(close, exit_lo) == 2 ? true : false;
   bool short_exit_breakout = ExitHiCrossing(close, exit_hi) == 1 ? true : false;
   
   // Exit rules for all opened positions
   if (long_exit_breakout && CountPositions(OP_BUY) > 0) // exit long trades
   {
      CloseOrderPosition(OP_BUY);
   }
   
   if (short_exit_breakout && CountPositions(OP_SELL) > 0) // exit short trades
   {
      CloseOrderPosition(OP_SELL);
   }
   
   // Entry rules for all market and pending orders
   if (!LockEntry && CountPositions(OP_BUY) + CountPositions(OP_SELL) < MaximumPosition)
   {
      if (long_entry_breakout)
      {
         // Create a new position and immediately add 3 pending positions         
         if (OpenMarketPosition(OP_BUY, lot_size, SL, TP) != -1)
         {
            OpenPendingOrder(OP_BUYSTOP, Ask + 0.5 * N, lot_size, 0, 0);
            OpenPendingOrder(OP_BUYSTOP, Ask + 1.0 * N, lot_size, 0, 0);
            OpenPendingOrder(OP_BUYSTOP, Ask + 1.5 * N, lot_size, 0, 0);
         
            // set lock entry to true to prevent violating maximum position
            LockEntry = true;
         
            // store First N and First Stop for managing stop when subsequent pending orders became open position
            FirstN = N;
            FirstStop = NormalizeDouble(Ask - SL * DecimalPerPip, Digits);
         }
      }
   
      if (short_entry_breakout)
      {
         // Create a new position and immediately add 3 pending positions
         if (OpenMarketPosition(OP_SELL, lot_size, SL, TP) != -1)
         {
            OpenPendingOrder(OP_SELLSTOP, Bid - 0.5 * N, lot_size, 0, 0);
            OpenPendingOrder(OP_SELLSTOP, Bid - 1.0 * N, lot_size, 0, 0);
            OpenPendingOrder(OP_SELLSTOP, Bid - 1.5 * N, lot_size, 0, 0);
         
            // set lock entry to true to prevent violating maximum position
            LockEntry = true;
         
            // store First N and First Stop for managing stop when subsequent pending orders became open position
            FirstN = N;
            FirstStop = NormalizeDouble(Bid + SL * DecimalPerPip, Digits);
         }
      }
   }
   
   // delete all pending orders when a SL or TP has occured
   if(GetPositionStatus() == pos_decrease)
   {
      CloseOrderPosition(OP_BUYSTOP);
      CloseOrderPosition(OP_SELLSTOP);
      if(CountPositions(OP_BUY) + CountPositions(OP_SELL)==0)
      {
         FirstN = 0;
         FirstStop = 0;
         LockEntry = false;
      }
   }
   
   // Stop placement
   if(GetPositionStatus() == pos_increase)
   {
      StopPlacement(FirstStop, FirstN);
   }
   
   return 0;
}

/**
 * Prepare trading context so the Expert Advisor is allowed to trade
 */
void PrepareTradingContext()
{
   if(!IsConnected())
   {
      Print("No connection between client terminal and server");
      return;
   }
   
   if (IsTradeAllowed())
      return;
   else
   {
      // wait until trade context is ready
      bool isMessagePrinted = false;
      while(IsTradeContextBusy())
      {
         if(!isMessagePrinted)
         {
            Print("Please wait, trading context is busy...");
            Sleep(SleepInterval);
         }
      }
      Print("Trading context is ready");
      RefreshRates();
   }  
}

/**
 * Check if line1 and line2 are crossing.
 *
 * line1    current price line
 * line2    dochian upper line
 *
 * Return   0 when no cross
 *          1 when line 1 crosses line2 from bottom, bullish signal
 *          2 when line 1 crosses line2 from top, bearish signal
 */
int EntryHighCrossing(double line1, double line2)
 {
   static bool isFirstTime = true;
   static int last_direction = 0;
   static int curr_direction = 0;
   
   // quantize double to digits
   line1 = NormalizeDouble(line1, Digits);
   line2 = NormalizeDouble(line2, Digits);
   
   // get direction
   double diff = line1 - line2;
   if (diff > 0.0)
      curr_direction = 1;  // line 1 is on top
   else if (diff < 0.0)
      curr_direction = 2;  // line 2 is ontop 
   else
      curr_direction = 0;  // line 1 and line 2 overlap
      
   // function is called the first time, set direction to no crossing
   if (isFirstTime)
   {
      isFirstTime = false;
      last_direction = curr_direction;
      return 0;
   }
   
   // check for crossing
   if (last_direction != curr_direction)
   {
      last_direction = curr_direction;
      return curr_direction;
   }
   
   return 0;
 }
 
/**
 * Check if line1 and line2 are crossing.
 *
 * line1    current price line
 * line2    Donchian lower line
 *
 * Return   0 when no cross
 *          1 when line 1 crosses line2 from bottom, bullish signal
 *          2 when line 1 crosses line2 from top, bearish signal
 */
int EntryLowCrossing(double line1, double line2)
 {
   static bool isFirstTime = true;
   static int last_direction = 0;
   static int curr_direction = 0;
   
   // quantize double to digits
   line1 = NormalizeDouble(line1, Digits);
   line2 = NormalizeDouble(line2, Digits);
   
   // get direction
   double diff = line1 - line2;
   if (diff > 0.0)
      curr_direction = 1;  // line 1 is on top
   else if (diff < 0.0)
      curr_direction = 2;  // line 2 is ontop 
   else
      curr_direction = 0;  // line 1 and line 2 overlap
   
   // function is called the first time, set direction to no crossing
   if (isFirstTime)
   {
      isFirstTime = false;
      last_direction = curr_direction;
      return 0;
   }
   
   // check for crossing
   if (last_direction != curr_direction)
   {
      last_direction = curr_direction;
      return curr_direction;
   }
   
   return 0;
 }
 
/**
 * Check if line1 and line2 crossing.
 *
 * line1   current price line
 * line2   Donchian upper line
 * 
 * Return  0 when no crossing
 *         1 when line1 crosses line1 from top
 *         2 when line1 crosses line2 from bottom
 */
int ExitHiCrossing(double line1, double line2)
{
   static bool isFirstTime = true;
   static int last_direction = 0;
   static int curr_direction = 0;
   
   // quantize double
   line1 = NormalizeDouble(line1, Digits);
   line2 = NormalizeDouble(line2, Digits);
   
   // get direction
   double diff = line1 - line2;
   if (diff > 0.0)
   {
      curr_direction = 1; // line 1 crosses line 2 from bottom
   }
   else if (diff < 0.0)
   {
      curr_direction = 2; // line 1 crosses line 2 from top
   }
   else
   {
      curr_direction = 0; // no crossing
   }
   
   // function is called the first time, set direction to no crossing
   if (isFirstTime)
   {
      isFirstTime = false;
      last_direction = curr_direction;
      return curr_direction;
   }
   
   // check for crossing
   if (curr_direction != last_direction)
   {
      last_direction = curr_direction;
      return curr_direction;
   }
   
   return 0;
}

/**
  * Check if line1 and line2 crossing.
  *
  * line1   current price line
  * line2   Donchian lower line
  *
  * Return  0 when no crossing
  *         1 when line1 crosses line1 from top
  *         2 when line1 crosses line2 from bottom
  */
int ExitLoCrossing(double line1, double line2)
{
   static bool isFirstTime = true;
   static int last_direction = 0;
   static int curr_direction = 0;
   
   // quantize double
   line1 = NormalizeDouble(line1, Digits);
   line2 = NormalizeDouble(line2, Digits);
   
   // get direction
   double diff = line1 - line2;
   if (diff > 0.0)
   {
      curr_direction = 1; // line 1 crosses line 2 from bottom
   }
   else if (diff < 0.0)
   {
      curr_direction = 2; // line 1 crosses line 2 from top
   }
   else
   {
      curr_direction = 0; // no crossing
   }
   
   // function is called the first time, set direction to no crossing
   if (isFirstTime)
   {
      isFirstTime = false;
      last_direction = curr_direction;
      return curr_direction;
   }
   
   // check for crossing
   if (curr_direction != last_direction)
   {
      last_direction = curr_direction;
      return curr_direction;
   }
   
   return 0;
}

/**
 * Count total number of open positions of the given type
 *
 * type  order type of which its position count is to be calculated
 *
 * Returns total number of open postion
 */
int CountPositions(int type)
{
   int count = 0;
   int totalTrades = OrdersTotal();
   
   for (int i = 0; i < totalTrades; ++i)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false)
         continue;
         
      if (OrderType() == type && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
      {
         ++count;
      }
   }
   
   return count;
}


/**
 * Close open positions or pending orders.
 *
 * type  order type of which its open position or pending order is to be closed
 *
 * Returns true if position or order has been closed successfully; false if otherwise
 */
bool CloseOrderPosition(int type)
{
   int totalTrades = OrdersTotal();
   double currentPrice;
   int slippageInPoint = Slippage * PointPerPip;
   color arrow_color = (type == OP_BUY) ? Aqua : Magenta;
   int currentOrderTicket;
   
   for (int i = 0; i < totalTrades; ++i)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false)
         continue;
      
      if (OrderType() == type && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
      {
         currentOrderTicket = OrderTicket();
         if (type == OP_BUY || type == OP_SELL) // close open position
         {
            PrepareTradingContext();
            currentPrice = (type == OP_BUY) ? Bid : Ask;
            if (OrderClose(currentOrderTicket, OrderLots(), currentPrice, slippageInPoint, arrow_color))
            {
               Print("Open ticket ", currentOrderTicket, " was successfully closed at ", currentPrice);
            }
            else
            {
               Print("Ticket ", currentOrderTicket, " was not closed due to unexpected error ", GetLastError());
            }
         }
         else // close pending order
         {
            PrepareTradingContext();
            if (OrderDelete(currentOrderTicket, clrNONE))
            {
               Print("Pending ticket ", currentOrderTicket, " was successfully deleted", currentOrderTicket);
            }
            else
            {
               Print("Pending ticket ", currentOrderTicket, " was not closed due unexpected error ", GetLastError());
            }
         }
      }
   }
   
   return (CountPositions(type) == 0);
}

/**
 * Get Lot Size.
 *
 * stop_loss         value in pip.
 * check_lot_size    true to check if calculated lot size satisfies broker's lot size limitation
 *
 * Returns  lot size
 */
double GetLotSize(double stop_loss, bool check_lot_size)
{
   double lot_size;
   double tick_value = (IsUSDepositAcoount) ? 1.0 : MarketInfo(Symbol(), MODE_TICKVALUE);
   string symbol = Symbol(); 
   
   lot_size = (RiskPerTrade * 0.01 * AccountBalance())/(stop_loss * DecimalPerPip * MarketInfo(symbol, MODE_LOTSIZE) * tick_value);
   lot_size *= YenPairMultiplier;
   
   // rounded lot size and check if its value satisfies broker's lot size constraint
   double adjusted_lot_size = MathFloor(NormalizeDouble(lot_size, 2) / MarketInfo(Symbol(),MODE_LOTSTEP)) * MarketInfo(Symbol(),MODE_LOTSTEP);
   double minimum_lot_size = MarketInfo(Symbol(), MODE_MINLOT);
   double maximum_lot_size = MarketInfo(Symbol(),MODE_MAXLOT);
   
   if (adjusted_lot_size < minimum_lot_size)
   {
      adjusted_lot_size = minimum_lot_size;      
   }
   else if (adjusted_lot_size > maximum_lot_size)
   {
      adjusted_lot_size = maximum_lot_size;
   }   
   lot_size = NormalizeDouble(adjusted_lot_size, 2);
   
   return lot_size;
}

/**
 * Open market position
 *
 * type        type of order
 * SL          stop loss value in pip
 * TP          take profit value in pip
 *
 * Returns ticket number if successful; -1 otherwise
 */
int OpenMarketPosition(int type, double lot, double SL, double TP)
{
   bool validType = (type == OP_BUY || type == OP_SELL) ? true : false;
   int ticket = -1;
   int count = 0;
   string symbol = Symbol();
   string comment = StringFormat(" %d (#%d)", type, MagicNumber);
   int slippageInPoint = Slippage * PointPerPip;
   double price;
   color arrow_color = (type == OP_BUY) ? Aqua : Magenta;
   double stop_level, stop_loss, take_profit;
   
   // domain check
   if (!validType)
   {
      Print("Invalid order type ", type);
      return (-1);
   }
   
   if(MarketInfo(symbol,MODE_MARGINREQUIRED) * lot > AccountFreeMargin())
   {
      Print("Insufficient free margin to open ", lot, " on ", symbol);
      return(-1);
   }
   
   // handle market execution
   if (IsECNBroker)
   {
      // open a new position with a market execution
      while(ticket < 0 && count++ < MaximumAttemptPerTick)
      {
         PrepareTradingContext();
         price = (type == OP_BUY) ? Ask : Bid;
         ticket = OrderSend(NULL, type, lot, price, slippageInPoint, 0, 0, comment, MagicNumber, 0, arrow_color);
      }
      
      // ECN broker does not allow SL and TP when placing an order, so need to input them after the order is opened
      if (ticket != -1 && OrderSelect(ticket, SELECT_BY_TICKET) && (SL != 0.0 || TP != 0.0))
      {
         stop_level = MarketInfo(symbol, MODE_STOPLEVEL) * Point; // value in point
         stop_loss = 0.0;
         take_profit = 0.0;
         
         // Check against Stop Level Minimum Distance.
         if(type == OP_BUY)
         {
            if (SL != 0.0)
            {
               // normalize stop loss in decimal
               stop_loss = NormalizeDouble(OrderOpenPrice() - SL * DecimalPerPip, Digits);
               
               // adjust stop loss if its value has violated stop level minimum distance constraint
               if(Bid - stop_loss <= stop_level)
               {
                  stop_loss = NormalizeDouble(Bid - stop_level, Digits);
                  Print("Stop level violation!  EA changed stop loss from ", SL, " to ", (OrderOpenPrice() - stop_loss)/DecimalPerPip, " pips");
               }
            }
            
            if (TP != 0.0)
            {
               // normalize take profit in decimal
               take_profit = NormalizeDouble(OrderOpenPrice() + TP * DecimalPerPip, Digits);
               
               // adjust take profit if its value has violated stop level minimum distance constraint
               if(take_profit - Bid <= stop_level)
               {
                  take_profit = NormalizeDouble(Ask + stop_level, Digits);
                  Print("Stop level violation!  EA changed take profit from ", TP, " to ", (take_profit - OrderOpenPrice())/DecimalPerPip, " pips");
               }
            }
         }
         else
         {
            if (SL != 0.0)
            {
               // normalize stop loss in decimal
               stop_loss = NormalizeDouble(OrderOpenPrice() + SL * DecimalPerPip, Digits);
               
               // adjust stop loss if its value has violated stop level minimum distance constraint
               if (stop_loss - Ask <= stop_level)
               {
                  stop_loss = NormalizeDouble(Ask + stop_level, Digits);
                  Print("Stop level violation!  EA changed stop loss from ", SL, " to ", (stop_loss - OrderOpenPrice())/DecimalPerPip, " pips");
               }
            }
            
            if (TP != 0.0)
            {
               // normalize take profit in decimal
               take_profit = NormalizeDouble(OrderOpenPrice() - TP * DecimalPerPip, Digits);
               
               // adjust take profit if its value has violated stop level minimum distance constraint
               if(Ask - take_profit <= stop_level)
               {
                  take_profit = NormalizeDouble(Bid - stop_level, Digits);
                  Print("Stop level violation!  EA changed take profit from ", TP, " to ", (OrderOpenPrice()-take_profit) / DecimalPerPip, " pips");
               }
            }
         }
         
         // modify open position for stop loss and take profit
         bool isPendingOrderModified = false;
         count = 0;
         while(!isPendingOrderModified && count++ < MaximumAttemptPerTick)
         {
            PrepareTradingContext();
            isPendingOrderModified = OrderModify(ticket, OrderOpenPrice(), stop_loss, take_profit, 0, arrow_color);
         }
         
         if(!isPendingOrderModified)
            Print("Error modifying take profit and stop loss, caused by error ", GetLastError());
      }
   }
   // handle instant execution
   else
   {
      stop_level = MarketInfo(symbol, MODE_STOPLEVEL) * Point; // convert point to decimal i.e 8.0 * 0.00001 for 5 digits broker
      stop_loss = 0.0;
      take_profit = 0.0;
      
      // open a position with instant execution
      while(ticket < 0 && count++ < MaximumAttemptPerTick)
      {
         RefreshRates();
         price = (type == OP_BUY) ? Ask : Bid;
         
         // Check against Stop Level Minimum Distance.
         if (type == OP_BUY)
         {
            if(SL != 0.0)
            {
               // normalize stop loss in decimal
               stop_loss = NormalizeDouble(Ask - SL*DecimalPerPip, Digits);
               
               // adjust stop loss if its value has violated stop level minimum distance constraint
               if(Bid - stop_loss <= stop_level)
               {
                  stop_loss = NormalizeDouble(Bid - stop_level, Digits);
                  Print("Stop Level Violation!  EA changed stop loss from ", SL, " to ", MarketInfo(Symbol(),MODE_STOPLEVEL)/PointPerPip, " pips");
               }
            }
            
            if(TP != 0.0)
            {
               // normalize take profit in decimal
               take_profit = NormalizeDouble(Ask + TP*DecimalPerPip, Digits);
               
               // adjust take profit if its value has violated stop level minimum distance constraint
               if(take_profit - Bid <= stop_level)
               {
                  take_profit = NormalizeDouble(Ask + stop_level, Digits);
                  Print("Stop Level Violation!  EA changed take profit from ", TP, " to ", MarketInfo(Symbol(),MODE_STOPLEVEL)/PointPerPip, " pips");
               }
            }
         }
         else
         {
            if(SL != 0.0)
            {
               // normalize stop loss in decimal
               stop_loss = NormalizeDouble(Bid + SL*DecimalPerPip, Digits);
               
               // adjust stop loss if its value has violated stop level minimum distance constraint
               if(stop_loss - Ask <= stop_level)
               {
                  stop_loss = NormalizeDouble(Ask + stop_level, Digits);
                  Print("Stop Level Violation!  EA changed stop loss from ", SL, " to ", MarketInfo(Symbol(),MODE_STOPLEVEL)/PointPerPip, " pips");
               }
            }
            
            if(TP != 0.0)
            {
               // normalize take profit in decimal
               take_profit = NormalizeDouble(Bid - TP*DecimalPerPip, Digits);
               
               // adjust take profit if its value has violated stop level minimum distance constraint
               if(Ask - take_profit <= stop_level)
               {
                  take_profit = NormalizeDouble(Bid - stop_level, Digits);
                  Print("Stop Level Violation!  EA changed take profit from ", TP, " to ", MarketInfo(Symbol(),MODE_STOPLEVEL)/PointPerPip, " pips");
               }
            }
         }
         
         // Open a market position 
         PrepareTradingContext();
         ticket = OrderSend(NULL, type, lot, price, slippageInPoint, stop_loss, take_profit, comment, MagicNumber, 0, arrow_color);
      }
   }
   
   return ticket;   
}

/**
 * Open pending order
 *
 * type        type of order
 * SL          stop loss value in pip
 * TP          take profit value in pip
 *
 * Returns ticket number if successful; -1 otherwise
 */
int OpenPendingOrder(int type, double open_price, double lot, double SL, double TP)
{
   string symbol = Symbol();
   
   // domain check
   if (type == OP_BUY || type == OP_SELL)
   {
      Print("Invalid order type ", type);
      return (-1);
   }
   
   if(MarketInfo(symbol,MODE_MARGINREQUIRED) * lot > AccountFreeMargin())
   {
      Print("Insufficient free margin to open ", lot, " on ", symbol);
      return(-1);
   }
   
   // local variables declaration and initialization
   string comment = StringFormat(" %d (#%d)", type, MagicNumber);
   int ticket_number = -1;
   int count = 0;
   int slippageInPoint = Slippage * PointPerPip;
   color arrow_color = (type == OP_BUYLIMIT || type == OP_BUYSTOP) ? ForestGreen : OrangeRed;
   double stop_level = MarketInfo(symbol, MODE_STOPLEVEL) * Point; // convert stop level in point to decimal i.e 8.0 * 0.00001 for 5 digits broker
   double stop_loss = 0;
   double take_profit = 0;
   
   // normalize open price so the price can be accepted by broker
   open_price = NormalizeDouble(open_price, Digits);
   
   // open pending order
   while(ticket_number < 0 && count++ < MaximumAttemptPerTick)
   {
      RefreshRates();
      
      // Check against Stop Level Minimum Distance.
      if (type == OP_BUYLIMIT || type == OP_BUYSTOP)
      {
         if (SL != 0.0)
         {
             // normalize stop loss in decimal
             stop_loss = NormalizeDouble(open_price - SL * DecimalPerPip, Digits);
             
             // adjust stop loss if its value has violated stop level minimum distance constraint
             if (open_price - stop_loss <= stop_level)
             {
               stop_loss = NormalizeDouble(open_price - stop_level, Digits);
               Print("Stop Level Violation!  EA changed stop loss from ", SL, " to ", (open_price - stop_loss)/DecimalPerPip, " pips");
             }
         }
         
         if (TP != 0.0)
         {
            // normalize take profit in decimal
            take_profit = NormalizeDouble(open_price + TP * DecimalPerPip, Digits);
            
            // adjust take profit if its value has violated stop level minimum distance constraint
            if (take_profit - open_price <= stop_level)
            {
               take_profit = NormalizeDouble(open_price + stop_level, Digits);
               Print("Stop Level Violation!  EA changed take profit from ", TP, " to ", (take_profit - open_price)/DecimalPerPip, " pips");
            }
         }
      }
      else // (type == OP_SELLLIMIT || type == OP_SELLSTOP)
      {
         if (SL != 0.0)
         {
            // normalize stop loss in decimal
            stop_loss = NormalizeDouble(open_price + SL * DecimalPerPip, Digits);
            
            // adjust stop loss if its value has violated stop level minimum distance constraint
            if (stop_loss - open_price <= stop_level)
            {
               stop_loss = NormalizeDouble(open_price + stop_level, Digits);
               Print("Stop Level Violation!  EA changed stop level from ", SL, " to ", (OrderOpenPrice() + stop_loss)/DecimalPerPip, " pips");
            }
         }
         
         if (TP != 0.0)
         {
            // normalize take profit in decimal
            take_profit = NormalizeDouble(open_price - TP * DecimalPerPip, Digits);
            
            // adjust take profit if its value has violated stop level minimum distance constraint
            if (open_price - take_profit <= stop_level)
            {
               take_profit = NormalizeDouble(open_price - stop_level, Digits);
               Print("Stop Level Violation!  EA changed take profit from ", TP, " to ", (OrderOpenPrice() - take_profit)/DecimalPerPip, " pips");
            }
         }
      }
      
      PrepareTradingContext();
      ticket_number = OrderSend(symbol, type, lot, open_price, slippageInPoint, stop_loss, take_profit, comment, MagicNumber, 0, arrow_color);
   }
   
   return ticket_number;
}

/**
 * Get position status.
 *
 * Returns  pos_increase when a new position is added
 *          pos_decrease when an opened postion is closed
            pos_unchange when no position change
 */
pos_status GetPositionStatus()
{
   static int lastPos = 0;
   static int currentPos = 0;
   pos_status status;
   
   
   currentPos = CountPositions(OP_BUY) + CountPositions(OP_SELL);
   
   if(currentPos > lastPos)
   { 
      status = pos_increase;
   }
   else if (currentPos < lastPos)
   {
      status = pos_decrease;
   }
   else
   {
      status = pos_unchange;
   }
   
   lastPos = currentPos;
   
   return(status);
}

/**
 * Adjust stop when a new position is added. The stop is based on position risk.
 * In order to keep total position risk at minimum, if addditional units were added,
 * the stop of earlier units were raised by 0.5N.
 *
 * stop  first stop loss in decimal
 * N     volatility of a particular market
 *
 */
 void StopPlacement(double stop, double N)
 {
   int order_type = -1;
   int position_count;
   double new_stop = 0.0;
   // adjust stop for long position
   if ((position_count = CountPositions(OP_BUY)) > 0)
   {
      order_type = OP_BUY;
      new_stop =  (position_count == 2) ? (stop + 0.5 * N) :
                  (position_count == 3) ? (stop + 1.0 * N) :
                  (position_count == 4) ? (stop + 1.5 * N) : 0.0;
   }
   // adjust stop for short position
   else if ((position_count = CountPositions(OP_SELL)) > 0)
   {
      order_type = OP_SELL;
      new_stop =  (position_count == 2) ? (stop - 0.5 * N) :
                  (position_count == 3) ? (stop - 1.0 * N) :
                  (position_count == 4) ? (stop - 1.5 * N) : 0.0;
   }
   
   if (new_stop > 0.0)
   {
      int total = OrdersTotal();
      for (int i = 0;  i < total; ++i)
      {
         if (!OrderSelect(i, SELECT_BY_POS))
            continue;
            
         if (OrderSymbol() == Symbol() && OrderMagicNumber()  == MagicNumber && OrderType() == order_type)
         {
            if (!OrderModify(OrderTicket(), OrderOpenPrice(), new_stop, 0, 0, Gold))
            {
               Print("Failed to change stop for ", Symbol(), " to ", new_stop);
            }
         }
      }
   }
 }