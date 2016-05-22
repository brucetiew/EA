//+------------------------------------------------------------------+
//|                                     Safe Entry Exit Channels.mq4 |
//|                                                       Bruce Tiew |
//|                            https://www.linkedin.com/in/brucetiew |
//+------------------------------------------------------------------+
#property copyright "Bruce Tiew"
#property link      "https://www.linkedin.com/in/brucetiew"
#property version   "1.00"
#property strict


// Property Area
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_color1 Black
#property indicator_color2 Black
#property indicator_color3 Gold
#property indicator_color4 Gold
#property indicator_color5 Red
#property indicator_color6 Red

// Indicator paramaters
extern string  Separator1 = "--------General Indicator Parameters----------------";
extern int  NumberofBars = 200;
extern int  StartShift = 0;
extern string  Separator2 = "----------Safe Early Entry and Exit channels--------";
extern int  safe_entry_period = 52;
extern int  early_entry_period = 21;
extern int  early_exit_period = 10;
extern bool  safe_entry_channel_on = true;
extern bool  early_entry_channel_on = true;
extern bool  early_exit_channel_on = true;

// Indicator buffers and variables
double SafeEntryHigh[];
double SafeEntryLow[];
double EarlyEntryHigh[];
double EarlyEntryLow[];
double EarlyExitHigh[];
double EarlyExitLow[];

/**
 * SEE indicator initialization.
 */
int init()
{
   SetIndexStyle(0,DRAW_LINE,1,2);
   SetIndexBuffer(0,SafeEntryHigh);
   SetIndexStyle(1,DRAW_LINE,1,2);
   SetIndexBuffer(1,SafeEntryLow);
   
   SetIndexStyle(2,DRAW_LINE,1,2);
   SetIndexBuffer(2,EarlyEntryHigh);
   SetIndexStyle(3,DRAW_LINE,1,2);
   SetIndexBuffer(3,EarlyEntryLow);
   
   SetIndexStyle(4,DRAW_LINE,1,2);
   SetIndexBuffer(4,EarlyExitHigh);
   SetIndexStyle(5,DRAW_LINE,1,2);
   SetIndexBuffer(5,EarlyExitLow);

   return(0);
}

/**
 * SEE indicator deinitialization.
 */
int deinit()
{
   return(0);
}

/**
 * SEE indicator entry.
 */
int start()
{
   int hiIdx;
   int loIdx;
   
   for (int shift = 0; shift < NumberofBars; shift++)
   {
      if (safe_entry_channel_on)
      {
         if (((hiIdx = iHighest(NULL, 0, MODE_HIGH, safe_entry_period, shift + StartShift)) != -1) &&
             ((loIdx = iLowest(NULL, 0, MODE_LOW, safe_entry_period, shift + StartShift))) != -1)
         {
            SafeEntryHigh[shift] = High[hiIdx];
            SafeEntryLow[shift] = Low[loIdx];
         }
         else
         {
            SafeEntryHigh[shift] = -1;
            SafeEntryLow[shift] = -1;
            Print("Error getting Safe Entry Channel Value");
         }
      }
      
      if (early_entry_channel_on)
      {
         if (((hiIdx = iHighest(NULL, 0, MODE_HIGH, early_entry_period, shift + StartShift)) != -1) &&
            ((loIdx = iLowest(NULL, 0, MODE_LOW, early_entry_period, shift + StartShift))) != -1)
         {
            EarlyEntryHigh[shift] = High[hiIdx];
            EarlyEntryLow[shift] = Low[loIdx];
         }
         else
         {
            EarlyEntryHigh[shift] = -1;
            EarlyEntryLow[shift] = -1;
            Print("Error getting Early Entry Channel Value");
         }
      }
      
      if (early_exit_channel_on)
      {
         if (((hiIdx = iHighest(NULL, 0, MODE_HIGH, early_exit_period, shift + StartShift)) != -1) &&
            ((loIdx = iLowest(NULL, 0, MODE_LOW, early_exit_period, shift + StartShift))) != -1)
         {
            EarlyExitHigh[shift] = High[hiIdx];
            EarlyExitLow[shift] = Low[loIdx];
         }
         else
         {
            EarlyExitHigh[shift] = -1;
            EarlyExitLow[shift] = -1;
            Print("Error getting Early Exit Channel Value");
         }
      }
   }
   
   return(0);
}
