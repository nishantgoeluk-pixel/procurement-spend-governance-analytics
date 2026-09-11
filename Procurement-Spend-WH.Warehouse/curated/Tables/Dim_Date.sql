CREATE TABLE [curated].[Dim_Date] (
    [DateKey]       INT          NOT NULL,
    [FullDate]      DATE         NOT NULL,
    [CalendarYear]  INT          NOT NULL,
    [Quarter]       VARCHAR (2)  NOT NULL,
    [QuarterNum]    INT          NOT NULL,
    [MonthName]     VARCHAR (20) NOT NULL,
    [MonthNum]      INT          NOT NULL,
    [YearMonth]     VARCHAR (7)  NOT NULL,
    [WeekNum]       INT          NOT NULL,
    [DayOfWeek]     VARCHAR (10) NOT NULL,
    [IsWeekend]     VARCHAR (5)  NOT NULL,
    [FiscalYear]    VARCHAR (6)  NOT NULL,
    [FiscalQuarter] VARCHAR (4)  NOT NULL
);


GO

ALTER TABLE [curated].[Dim_Date]
    ADD CONSTRAINT [PK_Dim_Date] PRIMARY KEY NONCLUSTERED ([DateKey] ASC) NOT ENFORCED;


GO