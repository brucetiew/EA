//+------------------------------------------------------------------+
//|                                            Donchian Channels.mq4 |
//|                                                       Bruce Tiew |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Bruce Tiew"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Property Area
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Gold
#property indicator_color2 Gold

// Indicator paramaters
extern int  Periods = 10;
extern int  StartShift = 1;
extern int  NumberofBars = 200;


// Indicator buffers and variables
double DochianHigh[];
double DochianLow[];


/**
 * Dochian indicator initialization.
 */
int init()
{
   SetIndexStyle(0,DRAW_LINE,1,2);
   SetIndexBuffer(0,DochianHigh);
   SetIndexStyle(1,DRAW_LINE,1,2);
   SetIndexBuffer(1,DochianLow);

   return(0);
}

/**
 * Dochian indicator deinitialization.
 */
int deinit()
{
   return(0);
}

/**
 * Dochian indicator entry.
 */
int start()
{
   int hiIdx;
   int loIdx;

   for (int shift = 0; shift < NumberofBars; shift++)
   {
      if (((hiIdx = iHighest(NULL, 0, MODE_HIGH, Periods, shift + StartShift)) != -1) &&
          ((loIdx = iLowest(NULL, 0, MODE_LOW, Periods, shift + StartShift))) != -1)
      {
         DochianHigh[shift] = High[hiIdx];
         DochianLow[shift] = Low[loIdx];
      }
      else
      {
         DochianHigh[shift] = -1;
         DochianLow[shift] = -1;
         Print("Error getting Dochian high or low value");
      }
   }
   
   return(0);
}
