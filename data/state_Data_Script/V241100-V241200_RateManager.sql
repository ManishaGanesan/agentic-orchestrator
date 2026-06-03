USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from V241100 to V241200.
Run this script on [RateManager] V241100 to upgrade it to [RateManager] V241200.
This script performs its actions in the following order:
1. Disable foreign-key constraints.
2. Perform DELETE commands. 
3. Perform UPDATE commands.
4. Perform INSERT commands.
5. Re-enable foreign-key constraints.
Please back up your target database before running this script.
*/

SET XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

DECLARE @FromDVersion varchar(50);
SET @FromDVersion = '2411.00'; -- the DVersion in the database
IF (SELECT TOP 1 DVersion FROM [RateManager].[dbo].ADM_SystemVersion ORDER BY DVersion DESC) <> @FromDVersion
BEGIN
  RAISERROR ('The database version(DVersion) of [RateManager] must be %s to continue the upgrade of [RateManager].', 16, 1, @FromDVersion)
  SET NOEXEC ON
END
ELSE
  SET NOEXEC OFF
GO

SET NOCOUNT ON
GO

-- START: DO NOT DELETE THIS BLOCK -- setting database compatibility level according to SQL server version
DECLARE @productVersion nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY('productversion'))
DECLARE @compatibilityLevel nvarchar(10)
DECLARE @sqlQuery nvarchar(max)
DECLARE @currentCompatibility varchar(10)
DECLARE @sqlDBName nvarchar(max) = DB_NAME()

SELECT
  @currentCompatibility = CAST(COMPATIBILITY_LEVEL AS nvarchar)
FROM SYS.DATABASES
WHERE NAME = @sqlDBName
SET @sqlQuery = N''

SELECT
  @compatibilityLevel =
                       CASE
                         WHEN @productVersion LIKE '11%' THEN '110' -- sql server 2012
                         WHEN @productVersion LIKE '12%' THEN '120' -- sql server 2014
                         WHEN @productVersion LIKE '13%' THEN '130' -- sql server 2016
                         WHEN @productVersion LIKE '14%' THEN '140' -- sql server 2017
                         WHEN @productVersion LIKE '15%' THEN '150' -- sql server 2019
                         WHEN @productVersion LIKE '16%' THEN '160' -- sql server 2022
                         ELSE ''                                    -- don't enforce compatibility level change
                       END

IF (@compatibilityLevel = '')
BEGIN
  INSERT INTO [dbo].[DTA_EventLog] ([LoginSessionGUID], [LoginUser], [TypeEnum], [ApplicationEnum], [SourceEnum], [SourceName], [Description], [DescriptionDetail], [Data], [InsertedTS])
    VALUES (NULL, SYSTEM_USER, 3, 4, 3, 'Script', 'Unable to detect SQL Server Version', 'Unable to detect SQL Server Version', NULL, GETDATE());

  RAISERROR ('Unable to detect SQL Server Version', 0, 0)
END
ELSE
IF @currentCompatibility <> @compatibilityLevel
BEGIN
  SET @sqlQuery = 'ALTER DATABASE [RateManager] SET COMPATIBILITY_LEVEL = ' + @compatibilityLevel;
  EXECUTE sp_executesql @sqlQuery

  INSERT INTO [dbo].[DTA_EventLog] ([LoginSessionGUID], [LoginUser], [TypeEnum], [ApplicationEnum], [SourceEnum], [SourceName], [Description], [DescriptionDetail], [Data], [InsertedTS])
    VALUES (NULL, SYSTEM_USER, 1, 4, 3, 'Script', 'SET COMPATIBILITY_LEVEL ' + @compatibilityLevel, 'Setting Compatibility_Level from ' + @currentCompatibility + ' to ' + @compatibilityLevel + ' for ' + SUBSTRING(@@Version, 1, 26), NULL, GETDATE())
END
GO
-- END: DO NOT DELETE THIS BLOCK
GO
PRINT N'Altering Table [dbo].[PPS_meddrgprc_73]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'base2'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [base2] VARCHAR(10) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'perdiem1'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [perdiem1] VARCHAR(10) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'fac_type'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [fac_type] VARCHAR(2) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'pol_addon1'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [pol_addon1] VARCHAR(10) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'factor1'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [factor1] VARCHAR(5) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'mcf2'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [mcf2] VARCHAR(5) NULL
END

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_meddrgprc_73]')
          AND name = 'mcf3'
)
BEGIN
    ALTER TABLE [dbo].[PPS_meddrgprc_73] ADD [mcf3] VARCHAR(5) NULL
END

SET NUMERIC_ROUNDABORT OFF;

/************************* Here, it should be added with following updates
1. Medicare HCPCS Rule updates/insert statements should be added here and also before actual insert statements, need to add TRUNCATE statement for that table
2. Schema changes can be added here, with print statements(Exapmle, Print N'Altering [dbo].[PPS_xxxxx]...')
3. SP updates, like if modifications on existing SP's or adding new SP's, etc.
4. VW updates, like if modifications on existing Views or adding new Views, etc.
5. Function updates, adding or modifying any user defined or other functions, etc.
6. *********IMPORTANT NOTE***** Added these comments for clear understaing/reference purpose, so please remove all these comments in between comments block(/******  ********/, excluding the first block at line 4 to 13) on original script without fail
*************************/

GO

	
BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2412.00', N'2412.00', NULL, GETDATE())

    /*************** Updates on ADM_SystemVersion, 
    [AVersion] should be updated only when the application has any code changes, othrewise it should be previous code change version only
    [DVersion] should be updated for every change, it may be code change or database change or only version change for installer if there are no other changes for that release
    ****************/

    ALTER TABLE [dbo].[LUT_RateGrouperVersion] DROP CONSTRAINT [FK_LUT_RateGrouperVersion_LUT_RateGrouper]
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] DROP CONSTRAINT [FK_LUT_PricerTypeAPRPro_ProcedureVariable_LUT_PricerTypeAPRPro_Procedure]
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] DROP CONSTRAINT [FK_LUT_PricerTypeAPRPro_ProcedureVariable_LUT_PricerTypeVariable]
    ALTER TABLE [dbo].[LUT_WeightTypeVariableAlternate] DROP CONSTRAINT [FK_LUT_WeightTypeVariableAlternate_LUTWTVID]
    ALTER TABLE [dbo].[TML_PricerPageTLAttr] DROP CONSTRAINT [FK_TML_PricerPageTLAttr_TML_PricerPageTL]
    ALTER TABLE [dbo].[LUT_WeightTypeVariable] DROP CONSTRAINT [FK_LUT_WeightTypeVariable_LUT_WeightType]
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] DROP CONSTRAINT [FK_LUT_PricerTypeAPRPro_StateProcedure_LUT_PricerTypeAPRPro_Procedure]
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] DROP CONSTRAINT [FK_LUT_PricerTypeAPRPro_StateProcedure_LUT_PricerTypeAPRPro_State]
	ALTER TABLE [dbo].[TML_PricerPageTLMap] DROP CONSTRAINT [FK_TML_PricerPageTLMap_LUT_PricerTypeVariable] 
	ALTER TABLE [dbo].[TML_PricerPageTLMap] DROP CONSTRAINT [FK_TML_PricerPageTLMap_TML_PricerPageTL] 
    ALTER TABLE [dbo].[TML_PricerPageTL] DROP CONSTRAINT [FK_TML_PricerPageTL_TML_PricerPageTL]
    ALTER TABLE [dbo].[LUT_PricerType] DROP CONSTRAINT [FK_LUT_PricerType_LUT_PaySourceClass]
    ALTER TABLE [dbo].[LUT_PricerTypeVariable] DROP CONSTRAINT [FK_LUT_PricerTypeVariable_LUT_PricerType]

    --US1303021: V2412.00 - ER - Preferences - Add audit trail time frame
    UPDATE [dbo].[ADM_SystemPreference] SET [PreferenceValueDescription] = N'7:1week;30:1month;60:2months;90:3months;180:6months;365:1year;1095:3years', [ModifiedTS]=CAST(N'2024-12-05T00:00:00.000' AS DateTime) WHERE [ADMSPID] = 5;

    --US1309517 : V2412.00 - Oklahoma Medicaid APC Pricer - Description Update
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The discount to be applied when calculating reimbursement for all other procedures with Payment Status Indicator T, eligible fee schedule items, and payable Payment Status Indicator J1 (Hospital Part B Services Paid Through a Comprehensive APC) services billed with Modifier 51 (Multiple Procedures).', [ModifiedTS]=CAST(N'2024-12-05T00:00:00.000' AS DateTime) WHERE [LUTPTVID]=4380
    
    --US1307012: V2412.00 - New state added to Medicaid MS-DRG Pro: Iowa
    INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (76, 96, N'IA', N'Iowa', CAST(N'2024-12-01T00:00:00.000' AS DateTime), 5, 1)

    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (220, N'0008', N'Return Code 16: Invalid Billing of ALC Days', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (221, N'0054', N'HCPCs Level Code Table Lookup', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (222, N'0069', N'Bill Type Per Diem 1 Reimbursement', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (223, N'0070', N'Group Medicaid Specific DRGs (IA)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (224, N'0071', N'Calculate Transfer LOS as (LOS)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (225, N'0072', N'Calculate Cost Outlier Threshold 2 (flat base * weight * factor)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (226, N'0073', N'Set Cost Outlier Threshold (max of Threshold1 or Threshold2)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (227, N'0074', N'Calculate Day Outlier LOS as (LOS - Non-Covered Days)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (228, N'0075', N'Calculate Long Stay Outlier Addon Payment', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (229, N'0076', N'Set Long Stay Per Diem as Inlier/DRG MLOS', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (230, N'0077', N'Set Covered Days 1', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (231, N'0078', N'Set Short Stay Per Diem as Inlier/DRG MLOS', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (232, N'0079', N'Calculate Short Stay Outlier Addon Payment', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (233, N'0080', N'Additional Payment', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (234, N'0081', N'Apply Short Stay Payment', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (235, N'0082', N'Determine Non-covered Days', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (236, N'0083', N'Set Long and Short Stay Marginal Cost Factors', 1, 96)

    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 184, 1, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 183, 2, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 187, 3, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 189, 4, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 182, 5, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 221, 6, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 222, 7, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 223, 8, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 186, 9, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 185, 10, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 235, 11, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 220, 12, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 192, 13, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 224, 14, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 196, 15, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 195, 16, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 194, 17, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 197, 18, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 199, 19, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 225, 20, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 198, 21, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 226, 22, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 200, 23, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 236, 24, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 227, 25, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 229, 26, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 230, 27, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 228, 28, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 201, 29, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 231, 30, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 232, 31, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 234, 32, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 233, 33, CAST(N'2024-12-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 203, 34, CAST(N'2024-12-05T00:00:00.000' AS DateTime))

    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (222, 4452)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (223, 4453)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (225, 4451)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (225, 4455)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (233, 4454)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (236, 4456)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (236, 4457)

    DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4367
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [StringLength]=2, [ModifiedTS]='20241205 00:00:00.000' WHERE [LUTPTVID]=4359
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [VariableDescr]=N'', [StringLength]=1, [ModifiedTS]='20241205 00:00:00.000' WHERE [LUTPTVID]=4360
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Base dollar amount 1 used for pricing MS-DRG claims.', [LabelOnUI]=N'Hospital Base Rate 1:$', [ModifiedTS]='20241205 00:00:00.000' WHERE [LUTPTVID]=4361
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.4', [ModifiedTS]='20241205 00:00:00.000' WHERE [LUTPTVID]=4362
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.4', [VariableDescr]=N'The Marginal Cost Factor is used to determine the outlier add-on payment amount.', [ModifiedTS]='20241205 00:00:00.000' WHERE [LUTPTVID]=4366
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4451, 96, N'E.2', N'base2', N'Base dollar amount 2 used for pricing MS-DRG claims.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'Hospital Base Rate 2:$', N'0.00', NULL, 10, 301, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4452, 96, N'E.3', N'perdiem1', N'Hospital-specific per diem rate 1.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'Per Diem 1:$', N'0.00', NULL, 10, 281, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4453, 96, N'F.2', N'fac_type', N'Specifies the facility type for policy adjustment:

00 = Standard Reimbursement
01 = Facility Eligible for Regrouping 1
02 = Facility Eligible for Regrouping 2', N'TEXT', 2, 0, N'X(2)', NULL, N'Facility Type:', N'0', NULL, 2, 316, 0, NULL, NULL, NULL, NULL, 2, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4454, 96, N'F.3', N'pol_addon1', N'First policy add-on payment.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'Policy Addon 1:$', N'0.00', NULL, 10, 318, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4455, 96, N'G.3', N'factor1', N'An adjustment factor used in the calculation of outliers.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Factor 1:', N'0', NULL, 5, 311, 0, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4456, 96, N'G.5', N'mcf2', N'The Marginal Cost Factor is used to determine the outlier add-on payment amount.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Marginal Cost Factor 2:', N'0', NULL, 5, 291, 0, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4457, 96, N'G.6', N'mcf3', N'The Marginal Cost Factor is used to determine the outlier add-on payment amount.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Marginal Cost Factor 3:', N'0', NULL, 5, 296, 0, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4458, 96, N'', N'filler1', N'', N'FILLER', 109, 0, N'X(109)', NULL, N'Filler:', N'', NULL, 109, 328, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20241205 00:00:00.000', NULL, '00010101', '99991231', NULL)

    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=7, [ModifiedTS]='20241205 00:00:00.000' WHERE [TMLPPTID]=6907
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=8, [ModifiedTS]='20241205 00:00:00.000' WHERE [TMLPPTID]=6908
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=7, [ModifiedTS]='20241205 00:00:00.000' WHERE [TMLPPTID]=6917
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=8, [ModifiedTS]='20241205 00:00:00.000' WHERE [TMLPPTID]=6918
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3858, 6986, 4451)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3859, 6987, 4451)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3860, 6988, 4452)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3861, 6989, 4452)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3862, 6990, 4453)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3863, 6991, 4453)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3864, 6992, 4453)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3865, 6993, 4453)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3866, 6994, 4453)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3867, 6995, 4454)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3868, 6996, 4454)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3869, 6997, 4455)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3870, 6998, 4455)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3871, 6999, 4456)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3872, 7000, 4456)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3873, 7001, 4457)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3874, 7002, 4457)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6986, 96, 6904, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6987, 96, 6904, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6988, 96, 6904, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6989, 96, 6904, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6990, 96, 6909, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6991, 96, 6909, N'ComboBox', N'SelectedValue', NULL, NULL, NULL, 4, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6992, 96, 6991, N'ComboBoxItem', N'Content', N'00 = Standard Reimbursement', NULL, NULL, 1, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6993, 96, 6991, N'ComboBoxItem', N'Content', N'01 = Facility Eligible for Regrouping 1', NULL, NULL, 2, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6994, 96, 6991, N'ComboBoxItem', N'Content', N'02 = Facility Eligible for Regrouping 2', NULL, NULL, 3, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6995, 96, 6909, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6996, 96, 6909, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6997, 96, 6912, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6998, 96, 6912, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6999, 96, 6912, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7000, 96, 6912, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7001, 96, 6912, N'TextBlock', N'Text', NULL, NULL, NULL, 11, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7002, 96, 6912, N'TextBox', N'Text', NULL, NULL, NULL, 12, 1, '20241205 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (516, 6992, N'Tag', N'00', 1, '20241205 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (517, 6993, N'Tag', N'01', 1, '20241205 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (518, 6994, N'Tag', N'02', 1, '20241205 00:00:00.000', '00010101', '99991231')

    -- US1307535 : V2412.00 - New state added to Medicaid MS-DRG Pro: Iowa - Code Table support
    INSERT [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (48, N'codeia2.dat', CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL)
    
    INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (48, 96)

    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (773, 48, N'CodeType', N'Code Type', 1, 1, N'codetype', N'Iowa Medicaid: B = UB-04 Bill Type C = Procedure Code Q = Discharge status R = Revenue Code', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, 1, N'ASC')
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (774, 48, N'Code', N'Code', 1, 2, N'code', N'Code value will be one of the following: 
- B: 0110  - non covered claim
- B: 018X  - add all values for “X” = 0-9 (swing bed per diem claim)
- B: 028X  - add all values for “X” = 0-9 (swing bed per diem claim)
- C: 90899 - HCPC for PIC Per Diem
- Q: 02    - transfer dstat
- Q: 05    - transfer dstat
- R: 0173  - Rev Code for Neonatal Claim
- R: 0174  - Rev Code for Neonatal Claim
- R: 0204  - Rev Code for PIC Per Diem', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, 2, N'ASC')
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (775, 48, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'Sequence number for this code record.', NULL, 2, N'Decimal', 2, NULL, N'9(2)', 13, 0, 99, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (776, 48, N'StartDate', N'Start Date', 1, 3, N'startdate', N'Date record is effective.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, 1, N'DESC', NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (777, 48, N'EndDate', N'End Date', 1, 4, N'enddate', N'00000000 = Code is still in effect YYYYMMDD = End date for record.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (778, 48, N'Column1', N'Transfer Discharge Status or Admit Source', 1, 5, N'transfer', N'Iowa Medicaid: 0 = Not applicable 1 = transfer dstat', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 31, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (779, 48, N'Column2', N'Bill Type Flag', 1, 6, N'billtype_flag', N'Iowa Medicaid: 0 = Not applicable 1 = non covered claim 2 = add all values for “X” = 0-9 (swing bed per diem claim)', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 32, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (780, 48, N'Column3', N'Discharge Status Flag', 1, 7, N'dstat_flag', N'Iowa Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 33, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (781, 48, N'Column4', N'Admission Source Flag', 1, 8, N'admsrc_flag', N'Iowa Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 34, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (782, 48, N'Column5', N'MS-DRG Flag', 1, 9, N'msdrg_flag', N'Iowa Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 35, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (783, 48, N'Column6', N'Revenue Code Flag', 1, 10, N'revflag', N'Iowa Medicaid: 0 = Not applicable 1 = Rev Code for PIC Per Diem 2 = Rev Code for Neonatal Claim 3 = Rev Code for Neonatal Claim', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 36, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (784, 48, N'Column7', N'HCPCs Flag', 1, 11, N'hcpcsflag', N'Iowa Medicaid: 0 = Not applicable 1 = HCPC for PIC Per Diem', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 37, 0, 9, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (785, 48, NULL, N'Filler', 0, NULL, N'filler', NULL, NULL, 213, N'Filler', 213, NULL, N'X(213)', 38, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

    ALTER TABLE [dbo].[LUT_RateGrouperVersion] ADD CONSTRAINT [FK_LUT_RateGrouperVersion_LUT_RateGrouper] FOREIGN KEY ([LUTRGID]) REFERENCES [dbo].[LUT_RateGrouper] ([LUTRGID])
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ADD CONSTRAINT [FK_LUT_PricerTypeAPRPro_ProcedureVariable_LUT_PricerTypeAPRPro_Procedure] FOREIGN KEY ([LUTPID]) REFERENCES [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID])
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ADD CONSTRAINT [FK_LUT_PricerTypeAPRPro_ProcedureVariable_LUT_PricerTypeVariable] FOREIGN KEY ([LUTPTVID]) REFERENCES [dbo].[LUT_PricerTypeVariable] ([LUTPTVID])
    ALTER TABLE [dbo].[LUT_WeightTypeVariableAlternate] ADD CONSTRAINT [FK_LUT_WeightTypeVariableAlternate_LUTWTVID] FOREIGN KEY ([LUTWTVID]) REFERENCES [dbo].[LUT_WeightTypeVariable] ([LUTWTVID])
    ALTER TABLE [dbo].[TML_PricerPageTLAttr] ADD CONSTRAINT [FK_TML_PricerPageTLAttr_TML_PricerPageTL] FOREIGN KEY ([TMLPPTID]) REFERENCES [dbo].[TML_PricerPageTL] ([TMLPPTID])
    ALTER TABLE [dbo].[LUT_WeightTypeVariable] ADD CONSTRAINT [FK_LUT_WeightTypeVariable_LUT_WeightType] FOREIGN KEY ([LUTWTID]) REFERENCES [dbo].[LUT_WeightType] ([LUTWTID])
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ADD CONSTRAINT [FK_LUT_PricerTypeAPRPro_StateProcedure_LUT_PricerTypeAPRPro_Procedure] FOREIGN KEY ([LUTPID]) REFERENCES [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID])
    ALTER TABLE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ADD CONSTRAINT [FK_LUT_PricerTypeAPRPro_StateProcedure_LUT_PricerTypeAPRPro_State] FOREIGN KEY ([LUTSID]) REFERENCES [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID])
	ALTER TABLE [dbo].[TML_PricerPageTLMap] ADD CONSTRAINT [FK_TML_PricerPageTLMap_LUT_PricerTypeVariable] FOREIGN KEY ([LUTPTVID]) REFERENCES [dbo].[LUT_PricerTypeVariable] ([LUTPTVID])
	ALTER TABLE [dbo].[TML_PricerPageTLMap] ADD CONSTRAINT [FK_TML_PricerPageTLMap_TML_PricerPageTL] FOREIGN KEY ([TMLPPTID]) REFERENCES [dbo].[TML_PricerPageTL] ([TMLPPTID])
    ALTER TABLE [dbo].[TML_PricerPageTL] ADD CONSTRAINT [FK_TML_PricerPageTL_TML_PricerPageTL] FOREIGN KEY ([TMLPPTID]) REFERENCES [dbo].[TML_PricerPageTL] ([TMLPPTID])
    ALTER TABLE [dbo].[LUT_PricerType] ADD CONSTRAINT [FK_LUT_PricerType_LUT_PaySourceClass] FOREIGN KEY ([LUTPSCID]) REFERENCES [dbo].[LUT_PaySourceClass] ([LUTPSCID])
    ALTER TABLE [dbo].[LUT_PricerTypeVariable] ADD CONSTRAINT [FK_LUT_PricerTypeVariable_LUT_PricerType] FOREIGN KEY ([LUTPTID]) REFERENCES [dbo].[LUT_PricerType] ([LUTPTID])

  COMMIT TRANSACTION
END TRY
BEGIN CATCH
  SELECT
    ERROR_NUMBER() AS ErrorNumber,
    ERROR_SEVERITY() AS ErrorSeverity,
    ERROR_STATE() AS ErrorState,
    ERROR_PROCEDURE() AS ErrorProcedure,
    ERROR_LINE() AS ErrorLine,
    ERROR_MESSAGE() AS ErrorMessage;
  -- Throw error and rollback the transaction if there is any issue with insert and update scripts in the above transaction
  DECLARE @ErrorMessage varchar(max) = ERROR_MESSAGE();
	RAISERROR (@ErrorMessage, 16, 1);  
  IF @@TRANCOUNT > 0
  BEGIN
    ROLLBACK TRANSACTION;
    PRINT 'Rollback'
  END
END CATCH;

IF @@TRANCOUNT > 0
  COMMIT TRANSACTION;
