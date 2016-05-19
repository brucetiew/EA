//+------------------------------------------------------------------+
//|                                                  Pipochan-TS.mq4 |
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
extern int     TrailingDistMultiplier = 3;  // trailing stop distance multiplier in units of volatility
extern int     TrailingBuffMutiplier = 1;   // trailing stop buffer multiplier in units of volatility
extern int     TPMultiplier = 2;    // take profit amount in units of valatility
extern double  RiskPerTrade = 1.0;  // value in percentage
extern string  Separator2 = "----------Expert Advisor General Settings-----";
extern bool    IsECNBroker = true;
extern bool    IsUSDepositAcoount = true;
extern bool    UseHiddenTrailingStop = true;
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
bool LockEntry = false;
double TrailingStopList[][3]; // col 0 - order number, col 1 - volatility trailing stop level in decmal, col 2 - volatility measure in pip

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
   
   // allocate trailing Stop List
   ArrayResize(TrailingStopList, MaximumPosition, MaximumPosition); 
   
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
   // Initialize globals for desiree strategies
   double entry_hi = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsEntry, DonchianStartShift, NumberofBars, DonchianHiBufferIdx, 1);
   double entry_lo = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsEntry, DonchianStartShift, NumberofBars, DonchianLoBufferIdx, 1);
   double exit_hi = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsExit, DonchianStartShift, NumberofBars, DonchianHiBufferIdx, 1);
   double exit_lo = iCustom(NULL, 0, "Donchian Channels", DonchianPeriodsExit, DonchianStartShift, NumberofBars, DonchianLoBufferIdx, 1);
   
   // get last closing price
   double close = iClose(NULL, 0, 1);
   
   // get stop loss and take profit values
   double N = iATR(NULL, 0, ATRPeriod, ATRStartShift);
   double SL = (TrailingDistMultiplier * N)/DecimalPerPip; // SL is a volatility trailing stop distance in pip
   double TP= (TPMultiplier * N)/DecimalPerPip;  // convert value to pip
   
   // get lot size
   double lot_size = GetLotSize(SL, true);
   
   // An entry signal is defined as a breakout of the closing price above the entry high for a long position, and below the tnry low for a short position.
   bool long_entry_breakout = EntryHighCrossing(close, entry_hi) == 1 ? true : false;
   bool short_entry_breakout = EntryLowCrossing(close, entry_lo) == 2 ? true : false;
   
   // An exit signal is defined as a breakout of a long position's closing price cross below exit low and a short position's closing price cross above exit high
   bool long_exit_breakout = ExitLoCrossing(close, exit_lo) == 2 ? true : false;
   bool short_exit_breakout = ExitHiCrossing(close, exit_hi) == 1 ? true : false;
   
   // Trailing Stops handling
   UpdateTrailingStopList();
   CloseOrAdjustTrailingStop();
   
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
      int order_number;

      if (long_entry_breakout)
      {
         // Create a new position and immediately add 3 pending positions
         order_number = (UseHiddenTrailingStop) ? OpenMarketPosition(OP_BUY, lot_size, 0, TP) : OpenMarketPosition(OP_BUY, lot_size, SL, TP);         
         if (order_number > -1)
         {
            SetVolatilityTrailingStop(order_number, (UseHiddenTrailingStop) ? SL : 0, N);
            
            // create first pending position
            order_number = OpenPendingOrder(OP_BUYSTOP, Ask + 0.5 * N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // create second pending position
            order_number = OpenPendingOrder(OP_BUYSTOP, Ask + N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // create third pending position
            order_number = OpenPendingOrder(OP_BUYSTOP, Ask + 1.5 * N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // set lock entry to true to prevent violating maximum position
            LockEntry = true;
         }
      }
   
      if (short_entry_breakout)
      {
         // Create a new position and immediately add 3 pending positions
         order_number = (UseHiddenTrailingStop) ? OpenMarketPosition(OP_SELL, lot_size, 0, TP) : OpenMarketPosition(OP_SELL, lot_size, SL, TP);
         if (order_number > -1)
         {
            SetVolatilityTrailingStop(order_number, (UseHiddenTrailingStop) ? SL : 0, N);
            
            // create first pending position
            order_number = OpenPendingOrder(OP_SELLSTOP, Bid - 0.5 * N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // create second pending position
            OpenPendingOrder(OP_SELLSTOP, Bid - 1.0 * N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // create third pending position
            OpenPendingOrder(OP_SELLSTOP, Bid - 1.5 * N, lot_size, 0, 0);
            SetVolatilityTrailingStop(order_number, 0, N);
            
            // set lock entry to true to prevent violating maximum position
            LockEntry = true;
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
         LockEntry = false;
      }
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
               Print("Pending ticket %d was successfully deleted", currentOrderTicket);
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
      return(-1);
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
         
         // modify open position for stop loss and take profit if not using hidden trailing stop
         if (!UseHiddenTrailingStop)
         {
            bool isPendingOrderModified = false;
            count = 0;
            while(!isPendingOrderModified && count++ < MaximumAttemptPerTick)
            {
               PrepareTradingContext();
               isPendingOrderModified = OrderModify(ticket, OrderOpenPrice(), stop_loss, take_profit, 0, arrow_color);
               Print("Order ", OrderTicket(), " modified stop_loss and take_profit to ", stop_loss, take_profit); // brc
            }
            
            if(!isPendingOrderModified)
               Print("Error modifying take profit and stop loss, caused by error ", GetLastError());
         }
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
 * Set initial volatility trailing stop level
 *
 * order_nunmber    order number of the open or trailing position
 * stop_distance    volatility trailing stop distance in pip
 * N                ATR at the point when the position is placed
 *
 * x                index of TrailingStopList where order_number is placed
 */
int SetVolatilityTrailingStop(int order_number, double stop_distance, double N)
{
   int x = -1;
   
   if (OrderSelect(order_number, SELECT_BY_TICKET) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
   {
      int type = OrderType();
      for (int i = 0; i < ArrayRange(TrailingStopList, 0); ++i)
      {
         if (TrailingStopList[i, 0] == 0) // look for first empty spot
         {
            x = i;
            
            // set order number
            TrailingStopList[i, 0] = order_number;
            
            // record volatility trailing stop level if user select to hide trailing stop
            if (stop_distance > 0)
            {
               if (type == OP_BUY || type == OP_BUYSTOP)
               {
                  TrailingStopList[i, 1] = (MathMax(Bid, OrderOpenPrice()) - stop_distance * DecimalPerPip);
               }
            
               if (type == OP_SELL || type == OP_SELLSTOP)
               {
                  TrailingStopList[i, 1] = (MathMax(Ask, OrderOpenPrice()) + stop_distance * DecimalPerPip);
               }
               
               Print("Order ", TrailingStopList[x,0], " assigned with a hidden volatility trailing stop level of ", NormalizeDouble(TrailingStopList[x,1],Digits));
            }
            // do not record volatility trailing stop level if user select to show trailing stop
            else
            {
               TrailingStopList[i, 1] = 0;
            }
            
            // set volatility measure
            TrailingStopList[i, 2] = N/DecimalPerPip;
         
            break;
         }
      }      
   }
   else
   {
      Print("Failed to select an order by order number ", order_number);
   }
   
   return x;
}
 
/**
 * Update volatility trailing stop list.  For each trade that has been closed, reset its corresponding list element
 */
void UpdateTrailingStopList()
{
   int array_size = ArrayRange(TrailingStopList, 0);
   int totalTrades = OrdersTotal();
   bool is_order_valid;
   
   for (int i = 0; i < array_size; ++i)
   {
      if (TrailingStopList[i, 0] != 0)
      {
         is_order_valid = false;
         
         for (int j = 0; j < totalTrades; ++j)
         {
            if (OrderSelect(j, SELECT_BY_POS) == false)
               continue;
               
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderTicket() == TrailingStopList[i, 0])
            {
               is_order_valid = true;
               break;
            }
         }
         
         // reset array elements if order no longer valid
         if (!is_order_valid)
         {
            TrailingStopList[i, 0] = 0;
            TrailingStopList[i, 1] = 0;
            TrailingStopList[i, 2] = 0;
         }
      }
   }
}

/**
 * Close or adjust an opened positions when its volatility trailing stop level has been breached or market condition has moved in its favour
 * by a distance of more than its trailing stop buffer.
 */
void CloseOrAdjustTrailingStop()
{
   int totalTrades = OrdersTotal();
   bool order_has_trailing_stop;
   double current_price_displacement;
   double noise_level;
   double new_trailing_stop_level;
   
   for (int i = 0; i < totalTrades; ++i)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false)
         continue;
         
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         order_has_trailing_stop = false;
         
         // look for the corresponding order in Trailing Stop List
         for (int j = 0; j < ArrayRange(TrailingStopList, 0); ++j)
         {
            if (OrderTicket() == TrailingStopList[j, 0])
            {
               order_has_trailing_stop = true;
               
               // if the condition is true, it means the position has a hidden volatility trailing stop level attached to it
               if (TrailingStopList[j, 1] != 0)
               {
                  if (OrderType() == OP_BUY)
                  {
                     // if Bid price goes below the hidden volatility trailing stop level, close the Buy position
                     if (Bid <= TrailingStopList[j, 1])
                     {
                        PrepareTradingContext();
                        if (OrderClose(OrderTicket(), OrderLots(), Bid, 0, Blue))
                        {
                           Print("Position for order ", OrderTicket(), " has been successfully closed due to hidden volatility trailing stop.");
                        }
                        else
                        {
                           Print("Unexpected Error has happened while attempting to close order ", OrderTicket(), " due to error Description: ", GetLastError());
                        }
                     }
                     // if not close, check if volatility trailing stop need to be adjusted
                     else
                     {
                        current_price_displacement = Bid - TrailingStopList[j, 1];
                        noise_level = (TrailingDistMultiplier * TrailingStopList[j, 2] + TrailingBuffMutiplier * TrailingStopList[j, 2]) * DecimalPerPip;
                  
                        // adjust trailing stop level
                        if (current_price_displacement > noise_level)
                        {
                           TrailingStopList[j, 1] = Bid - TrailingDistMultiplier * TrailingStopList[j, 2] * DecimalPerPip;
                        }
                     }
                  }
                  else if (OrderType() == OP_SELL)
                  {
                     // if Ask price goes above the hidden volatility trailing stop level, close the Sell position
                     if (Ask >= TrailingStopList[j, 1])
                     {
                        PrepareTradingContext();
                        if (OrderClose(OrderTicket(), OrderLots(), Ask, 0, Red))
                        {
                           Print("Position for order ", OrderTicket(), " has been successfully closed due to hidden volatility trailing stop.");
                        }
                        else
                        {
                           Print("Unexpected Error has happened while attempting to close order ", OrderTicket(), " due to error Description: ", GetLastError());
                        }
                     }
                     // if not close, check if volatility trailing stop need to be adjusted
                     else
                     {
                        current_price_displacement = TrailingStopList[j, 1] - Ask;
                        noise_level = (TrailingDistMultiplier * TrailingStopList[j, 2] + TrailingBuffMutiplier * TrailingStopList[j, 2]) * DecimalPerPip;
                  
                        // adjust trailing stop level
                        if (current_price_displacement > noise_level)
                        {
                           TrailingStopList[j, 1] = Ask + TrailingDistMultiplier * TrailingStopList[j, 2] * DecimalPerPip;
                        }
                     }
                  }
               }
               // if the condition is true, it means the position doesn't have a hidden volatility trailing stop level attached to it
               else
               {
                  if (OrderType() == OP_BUY)
                  {
                     current_price_displacement = Bid - OrderStopLoss();
                     noise_level = (TrailingDistMultiplier * TrailingStopList[j, 2] + TrailingBuffMutiplier * TrailingStopList[j, 2]) * DecimalPerPip;
                        
                     // adjust trailing stop level
                     if (current_price_displacement > noise_level)
                     {
                        new_trailing_stop_level = NormalizeDouble(Bid - TrailingDistMultiplier * TrailingStopList[j, 2] * DecimalPerPip, Digits);
                        PrepareTradingContext();
                        if (OrderModify(OrderTicket(), OrderOpenPrice(), new_trailing_stop_level, OrderTakeProfit(), 0, CLR_NONE))
                        {
                           Print("Order ", OrderTicket(), " has successfully modified, volatility trailing stop changed to ", new_trailing_stop_level);
                        }
                        else
                        {
                           Print("Unexpected Error has happened. Error Description: ", GetLastError());
                        }
                     }
                  }
                  else if (OrderType() == OP_SELL)
                  {
                     current_price_displacement = OrderStopLoss() - Ask;
                     noise_level = (TrailingDistMultiplier * TrailingStopList[j, 2] + TrailingBuffMutiplier * TrailingStopList[j, 2]) * DecimalPerPip;
                     
                     // adjust trailing stop level
                     if (current_price_displacement > noise_level)
                     {
                        new_trailing_stop_level = NormalizeDouble(Ask + TrailingDistMultiplier * TrailingStopList[j, 2] * DecimalPerPip, Digits);
                        PrepareTradingContext();
                        if (OrderModify(OrderTicket(), OrderOpenPrice(), new_trailing_stop_level, OrderTakeProfit(), 0, CLR_NONE))
                        {
                           Print("Order ", OrderTicket(), " has successfully modified, volatility trailing stop changed to ", new_trailing_stop_level);
                        }
                        else
                        {
                           Print("Unexpected Error has happened. Error Description: ", GetLastError());
                        }
                     }
                  }
               }
               
               if (!order_has_trailing_stop)
               {
                  Print("Order ", OrderTicket(), " does not have volatility trailing stop attached to it.");
               }
               
               break;
            }
         }
      }
   }
}