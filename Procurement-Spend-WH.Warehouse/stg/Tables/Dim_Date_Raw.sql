CREATE TABLE [stg].[Dim_Date_Raw] (
    [DateKey]       VARCHAR (20) NULL,
    [FullDate]      VARCHAR (20) NULL,
    [Year]          VARCHAR (10) NULL,
    [Quarter]       VARCHAR (2)  NULL,
    [QuarterNum]    VARCHAR (10) NULL,
    [Month]         VARCHAR (20) NULL,
    [MonthNum]      VARCHAR (10) NULL,
    [YearMonth]     VARCHAR (7)  NULL,
    [WeekNum]       VARCHAR (10) NULL,
    [DayOfWeek]     VARCHAR (10) NULL,
    [IsWeekend]     VARCHAR (5)  NULL,
    [FiscalYear]    VARCHAR (6)  NULL,
    [FiscalQuarter] VARCHAR (4)  NULL
);


GO