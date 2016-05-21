//+------------------------------------------------------------------+
//|                                                         VWAP.mq4 |
//|                                                       Bruce Tiew |
//|                            https://www.linkedin.com/in/brucetiew |
//+------------------------------------------------------------------+
#property copyright "Bruce Tiew"
#property link      "https://www.linkedin.com/in/brucetiew"
#property version   "1.00"
#property strict

// Indicator paramaters
extern int NumberofBars = 50;

// Property Area
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Gold

// Indicator buffers and variables
double VWAP[];
double tmp_buffer[];


/**
 * VWAP indicator initialization.
 */
int init()
{
   SetIndexStyle(0,DRAW_LINE,1,2);
   SetIndexBuffer(0,VWAP);
   
   // allocate temporary buffer to store VWAP
   ArrayResize(tmp_buffer, NumberofBars, NumberofBars);
   
   return(0);
}

/**
 * VWAP indicator deinitialization.
 */
int deinit()
{
   return(0);
}

/**
 * VWAP indicator entry.
 */
 
 int start()
 {
   double typical_price = 0;
   double cumulative_vol_price = 0;
   long volumn = 0;   
   long cumulative_vol = 0;
   
   // store VWAP in a temporary buffer
   for (int i = 1; i <= NumberofBars; ++i)
   {
      typical_price = (iHigh(NULL, 0, NumberofBars - i) +  iLow(NULL, 0, NumberofBars - i) + iClose(NULL, 0, NumberofBars - i))/3;
      volumn = iVolume(NULL, 0, NumberofBars - i);      
      cumulative_vol_price += (typical_price * volumn);
      cumulative_vol += volumn;
      tmp_buffer[NumberofBars - i] = NormalizeDouble((cumulative_vol_price/cumulative_vol), Digits);
   }
   
   // copy tmp_buffer to VWAP indicator array for display
   for (int i = 0; i < ArrayRange(tmp_buffer, 0); ++i)
      VWAP[i] = tmp_buffer[i];
      
   return(0);
 }