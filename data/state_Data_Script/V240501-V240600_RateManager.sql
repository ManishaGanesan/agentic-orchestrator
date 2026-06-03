USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from V191100 to v191101.
Run this script on [RateManager] V191100 to upgrade it to [RateManager] v191101.
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
SET @FromDVersion = '2405.01'; -- the DVersion in the database
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
      VALUES (N'2406.00', N'2406.00', NULL, GETDATE())

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

-- Add one procedure, add one procedure array for APR Pro (Florida)
INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (70, 84, N'FL', N'Florida', CAST(N'2024-07-01T00:00:00.000' AS DateTime), 5, 1)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (209, N'0092', N'Policy Adjustment 8', 1, 84)

INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 1, 1, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 2, 2, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 3, 3, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 87, 4, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 101, 5, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 209, 6, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 14, 7, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 93, 8, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 8, 9, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 4, 10, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 46, 11, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 16, 12, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 10, 13, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 11, 14, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 97, 15, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 146, 16, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 208, 17, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 98, 18, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 99, 19, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 95, 20, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 145, 21, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 207, 22, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (70, 50, 23, CAST(N'2024-06-06T00:00:00.000' AS DateTime))

-- US1224215 - APG PRO - 6 NEW PROCEDURES, ADD 2 PROCEDURE ARRAY, REMOVE 1 PROCEDURE ARRAY
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (210, N'0006', N'Claim Level Return Code 27: Wrong Procedure Performed', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (211, N'0155', N'Cap Fee Schedule at Max Units', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (212, N'0156', N'Pay Discounted Charges', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (213, N'0157', N'Set Pricing Method for Fee Schedule Capped at Max Units', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (214, N'0158', N'Procedure Code/Modifier Pair Add-On Payment', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (215, N'0159', N'Distributed Charge Cap, APG Lines Only', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (216, N'0160', N'Set Method for Fee Schedule Lines without a Rate', 1, 86)

INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (212, 3298)
INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (214, 3488)

INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (71, 86, N'NE', N'Nebraska', CAST(N'2024-07-01T00:00:00.000' AS DateTime), 5, 1)
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 20, 1, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 51, 2, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 37, 3, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 22, 4, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 52, 5, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 25, 6, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 26, 7, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 83, 8, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 27, 9, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 28, 10, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 29, 11, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 30, 12, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 31, 13, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 32, 14, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 33, 15, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 70, 16, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 42, 17, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 34, 18, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 130, 19, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (71, 53, 20, CAST(N'2024-06-06T00:00:00.000' AS DateTime))

INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (72, 86, N'WI', N'Wisconsin', CAST(N'2024-06-01T00:00:00.000' AS DateTime), 7, 1)
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 19, 1, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 20, 2, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 210, 3, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 23, 4, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 37, 5, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 26, 6, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 25, 7, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 58, 8, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 27, 9, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 28, 10, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 29, 11, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 30, 12, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 31, 13, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 32, 14, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 211, 15, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 141, 16, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 213, 17, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 216, 18, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 212, 19, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 73, 20, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 22, 21, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 33, 22, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 34, 23, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 215, 24, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 214, 25, CAST(N'2024-06-06T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (72, 53, 26, CAST(N'2024-06-06T00:00:00.000' AS DateTime))

DELETE FROM [dbo].[LUT_PricerTypeAPRPro_State]  WHERE [LUTSID] = 67; 
DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure]  WHERE [LUTSID] = 67;

-- US1223758 : New York Medicaid APG (Enhanced)
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'25.10', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4024
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The adjustment to be applied to procedure code H0038 when Modifier HQ is present. This adjustment is applicable to claims submitted with an OMH rate code.', [DefaultValue]=N'0.3900', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4314
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This age cutoff is used to determine whether a claim is eligible for any of the following special pediatric payment policies:

- Eligibility for the Vaccines for Children Program.
- Application of the pediatric psychotherapy adjustment.', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4026

-- US1223758 : Oklahoma Medicaid APC
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4381
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'If the total payment is to be reduced or increased by a standard factor, enter that factor here.

This is an optional field; if no reduction or increase is appropriate, set this field to 1.0000.', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4382
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The discount to be applied to procedure codes billed with Modifier 73 (Terminated Procedure) or 52 (Reduced Services).', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4436

-- US1223758 : TRICARE APC
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The provider Medicare ID used to access the internal 3M™ TRICARE Outpatient Pricer Tables in the 3M™ GPCS.', [DefaultValue]=N'', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=2487
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The second part of the key used to access the internal 3M™ TRICARE Outpatient Pricer Tables. Set this value to 9960. If not supplied, the default will be the Payer ID.', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=2488
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'', [ModifiedTS]='20240606 00:00:00.000' WHERE [LUTPTVID]=4434 -- Updated the default value from null to empty string for lutptvid = 4434 & 2487

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

-- US1226180 : V2406.00 - add support for new code table file (codewi1.dat) for Medicaid APG Pro

INSERT [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (46, N'codewi1.dat', CAST(N'2024-06-06T00:00:00.000' AS DateTime), NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (46, 86)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (743, 46, N'CodeType', N'Code Type', 1, 1, N'codetype', N'C= Procedure Code
M= Modifier', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, 1, N'ASC')
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (744, 46, N'Code', N'Code', 1, 2, N'code', N'For Code Type C:
Set to “41899”

For Code Type M:
Set to “U2”

Code value will be a 5-character procedure code and a 2 character modifier.', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, 2, N'ASC')
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (745, 46, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'For Code Types C & M:
Zero fill – this is the current record.', NULL, 2, N'Decimal', 2, NULL, N'9(2)', 13, 0, 99, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (746, 46, N'StartDate', N'Start Date', 1, 3, N'startdate', N'For Code Type C:
Set to 20240601

For Code Type M:
Set to 20240601

*Dental Add-on policy for All hospitals classifications except CAH effective 01-01-2023.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), CAST(N'2024-03-07T00:00:00.000' AS DateTime), 1, N'DESC', NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (747, 46, N'EndDate', N'End Date', 1, 4, N'enddate', N'For Code Types C & M:
Set to “00000000”', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (748, 46, N'Column1', N'Adjustment Flag', 1, 5, N'adj_flag', N'For Code Type C:
Set to “0”

For Code Type M:
Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 31, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (749, 46, N'Column2', N'Cap at Charge Flag', 1, 6, N'charge_flag', N'For Code Types C & M:
Set to “0” = code does not use cap at charge logic', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 32, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (750, 46, N'Column3', N'Observation Flag', 1, 7, N'obs_flag', N'For Code Types C & M:
Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 33, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (751, 46, N'Column4', N'Revenue Code Flag', 1, 8, N'revenue_flag', N'For Code Types C & M:
Set to “0” = Covered Revenue Code', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 34, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (752, 46, N'Column5', N'Non-Covered HCPCS', 1, 9, N'deniedhcpc', N'For Code Types C & M:
Set to “0” = uses discounted terminated policy', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 35, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (753, 46, N'Column6', N'Minimum Units', 1, 10, N'min_units', N'For Code Types C & M:
Set to “0”', N'TextBox', 7, N'Integer', 7, NULL, N'9(7)', 36, 0, 9999999, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (754, 46, N'Column7', N'Maximum Units', 1, 11, N'max_units', N'For Code Types C & M:
Set to “0”', N'TextBox', 7, N'Integer', 7, NULL, N'9(7)', 43, 0, 9999999, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (755, 46, N'Column8', N'Modifier Flag', 1, 12, N'mod_flag', N'For Code Types C:
Set to “0” = Not Applicable

For Code Type M 
Set to “2”

2 = Modifier subject to special payment logic', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 50, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (756, 46, N'Column9', N'Outlier Flag', 1, 13, N'outlier_flag', N'For Code Types C & M:
Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 51, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (757, 46, N'Column10', N'APL Flag', 1, 14, N'aplflag', N'For Code Types C & M:
Set to “00” = Not an APL Code', N'TextBox', 2, N'Text', 2, NULL, N'X(2)', 52, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (758, 46, N'Column11', N'Payment Type', 1, 15, N'special_pmt', N'For Code Types C:
Set to “2” for 41899

2 = Subject to special payment rules

For Code Type M:
Set to “0” for U2', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 54, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (759, 46, N'Column12', N'Vagus Nerve Stimulator (VNS) Flag', 1, 16, N'vns_flag', N'Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 55, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (760, 46, N'Column13', N'Discount Flag', 1, 17, N'discount_flag', N'Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 56, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (761, 46, N'Column14', N'Diagnosis Flag', 1, 18, N'dx_flag', N'Set to “0”', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 57, 0, 9, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (762, 46, NULL, N'Filler', 0, NULL, N'filler1', NULL, NULL, 193, N'Filler', 193, NULL, N'X(193)', 58, NULL, NULL, NULL, NULL, CAST(N'2024-01-01T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

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