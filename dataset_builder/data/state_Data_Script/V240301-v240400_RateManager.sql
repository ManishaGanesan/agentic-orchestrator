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
SET @FromDVersion = '2403.01'; -- the DVersion in the database
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
      VALUES (N'2403.01', N'2404.00', NULL, GETDATE())

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

    /***************** The following type of updates, should be added in between ALTER Statements 
    1. Add new pricer type or payment system and updates of add new Field(s)/section(s), tool tips, default values, etc
    2. Updates of state proc_array's, add/update new state(s) or new effective dates, add/update procedure codes, map/remove pricing variables for Medicaid APG or APR Pro Pricer types
    3. Adding new ace edits for ACE Override ID
    4. Add new payment system support on Fee Schedules, some other updates related to data can be added here, etc.
    5. If there are no updates on this block, we can remove the above and below ALTER statements from script (should be removed for only version changes, for installer)
    ******************/

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

    --US1193409
    INSERT [dbo].[LUT_AceErrorNumber] ([AceErrorNumber], [AceErrorDescription], [ErrorDispositionLevel], [Enabled], [InsertedTS]) VALUES (N'135', N'Claim day lacks required device code (RTP)', NULL, 1, CAST(N'2024-04-04 00:00:00.000' AS DateTime))
    UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription] = N'IOP primary service not reported for IOP day (RTP)' WHERE [AceErrorNumber] = N'190'
    UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription] = N'PHP primary service not reported for PHP day (RTP)' WHERE [AceErrorNumber] = N'191'

    --US1193453

    --Contract APC
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 1551
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 1570
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 1571
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'W.1', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2869
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 3398
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'P.3', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 3415
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'W.2', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 3526
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'W.3', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 3527
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'If this option is selected, the adjusted rebatable drug coinsurance factor is applied, when applicable. If you do not wish to apply this factor, do not check this box.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4420

    --Contract ASC
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'If total payment is to be reduced or increased by a standard factor, enter that factor here. This adjustment will be applied to payment at the line level. If no reduction or increase is appropriate, set this field to 1.0000.

This factor is applied to all lines unless an exclusion flag is set in SEQ H.1 to SEQ H.19.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2252
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue] = N'feeasc24', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2272
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'This field is no longer applicable to the ASC Pro Payment System.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 3390
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'If this option is selected, the adjusted rebatable drug coinsurance factor will be applied. When this option is not selected, the adjusted rebatable drug coinsurance factor will not be applied.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4416

    --TRICARE/CHAMPUS
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue] = N'0.2512', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2498
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue] = N'42,750.00', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2499
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue] = N'0.9340', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2504
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue] = N'1.2000', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2505

    --Kentucky Medicaid
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2355
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2356
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from psychiatric Distinct Part Units (DPUs). In addition, the per diem rate used to calculate the payment for claims from free-standing psychiatric facilities when the patient age is on or above the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2362
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from rehabilitation DPUs. In addition, the per diem rate used to calculate the payment for claims from free-standing rehabilitation facilities when the patient age is on or above the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2363
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from Long Term Acute Care (LTAC) hospitals. In addition, the per diem rate used to calculate the payment for claims from LTAC hospitals when the patient age is on or above the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 2364
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from free-standing psychiatric facilities when the patient is under the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4237
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from free-standing rehabilitation facilities when the patient is under the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4238
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The per diem rate used to calculate the payment for claims from LTAC hospitals when the patient is under the age specified in SEQ F.5.', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4239


    --Medicare DRG
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 29
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.7', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 30
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 73
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.8', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 74
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.9', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 31
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 32
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.10', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 43
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.11', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 87
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 88
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.12', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4067
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.13', [VariableDescr] = N'This field is no longer used and has been replaced by the Federal Wage Adjusted Rate (new) field (SEQ# D.14)', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 41
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'D.14', [VariableDescr] = N'The federal wage-adjusted rate is calculated as follows:

(The letters refer to the sequence letter associated with each variable listed above)

((D.3 * (1 - D.5) * E.1) + (D.4 * (1 - D.5) * E.7) + (D.1 * D.5 * E.13) + (D.2 * D.5 *E.7)) * H.10', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4178
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 4116
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The total federal rate for operating costs (including both regional and national portions, as appropriate), with adjustments for local wage differences. This is the hospital''s total federal operating rate after the operating federal portion and adjustments for IME and disproportionate share have been applied. The formula is as follows:

(The letters refer to the sequence letter associated with each variable)

((((D.14 * D.6 * (1 + E.3 + (E.4 * E.5))) + E.8) * (1 + H.5)) - (D.14 * (1 - E.15)) - (D.14 * (1 - E.16))) * H.4', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 46
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The capital portion of the hospital''s Total Base PPS Reimbursement Rate including both federal and hospital-specific portions, as appropriate. This is the hospital''s average reimbursement amount per discharge for capital costs. This rate includes all applicable add-ons for IME and DSH. It is calculated as follows:

(The letters refer to the sequence letter associated with each variable)

((I.5 + (G.7 * I.4 * (1 + G.3 + G.4))) * (1 + H.5)) * H.4', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 67
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The sum of the hospital''s Operating Base PPS Reimbursement Rate and the Capital Base PPS Reimbursement Rate. The formula is as follows:

(The letters refer to the sequence letter associated with each variable)

F.1+ F.2', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 72

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr] = N'The Capital Standard Federal Rate adjusted for local wage differences using the GAF and Large Urban Adjustment Factor. The formula for calculating this field is as follows:

(The letters refer to the sequence letter associated with each variable)

For hospitals in Hawaii or Alaska, the formula also includes a capital cost-of-living factor, which is not included in the formula below.

G.6 * H.10 * ((G.1 * G.2 * (1 - I.3)) + (I.1 * I.2 * I.3))', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 70

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 56
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 57
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 58
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 59
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 60
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 61
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 75
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 62
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 63
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 64
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 77
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 78
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'I.1', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 65
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'I.2', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 54
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'I.3', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 83
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'I.4', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 68
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'I.5', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 69
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'J.1', [VariableDescr] = N'The total federal rate for operating costs (including both regional and national portions, as appropriate), with adjustments for local wage differences. This is the hospital''s total federal operating rate after the operating federal portion and adjustments for IME and disproportionate share have been applied. The formula is as follows:

(The letters refer to the sequence letter associated with each variable)

((((D.14 * D.6 * (1 + E.3 + (E.4 * E.5))) + E.8) * (1 + H.5)) - (D.14 * (1 - E.15)) - (D.14 * (1 - E.16))) * H.4', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 98
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'J.2', [VariableDescr] = N'The capital portion of the hospital''s Total Base PPS Reimbursement Rate including both federal and hospital-specific portions, as appropriate. This is the hospital''s average reimbursement amount per discharge for capital costs. This rate includes all applicable add-ons for IME and DSH. It is calculated as follows:

(The letters refer to the sequence letter associated with each variable)

((I.5 + (G.7 * I.4 * (1 + G.3 + G.4))) * (1 + H.5)) * H.4', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 96
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ] = N'J.3', [VariableDescr] = N'The sum of the hospital''s Operating Base PPS Reimbursement Rate and the Capital Base PPS Reimbursement Rate. The formula is as follows:

(The letters refer to the sequence letter associated with each variable)

F.1+ F.2', [ModifiedTS] = CAST(N'2024-04-04T00:00:00.000' AS DateTime) where LUTPTVID = 97

---US1185421
INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (68, 84, N'FL', N'Florida', CAST(N'2022-07-01T00:00:00.000' AS DateTime), 5, 1)
INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (69, 84, N'FL', N'Florida', CAST(N'2024-01-01T00:00:00.000' AS DateTime), 5, 1)

INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (207, N'0512', N'Fee Rate Addon', 1, 84)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (208, N'1011', N'Find Fee Rate Addon (Genome Sequencing - Florida Medicaid)', 1, 84)
INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (208, 3154)

UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=16  WHERE LUTSID = 17 and LUTPID=146
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=17  WHERE LUTSID = 17 and LUTPID=98
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=18  WHERE LUTSID = 17 and LUTPID=99
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=19  WHERE LUTSID = 17 and LUTPID=95
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=20  WHERE LUTSID = 17 and LUTPID=145

UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=15  WHERE LUTSID = 45 and LUTPID=146
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=16  WHERE LUTSID = 45 and LUTPID=98
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=17  WHERE LUTSID = 45 and LUTPID=99
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=18  WHERE LUTSID = 45 and LUTPID=95
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=19  WHERE LUTSID = 45 and LUTPID=145

INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 1, 1, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 2, 2, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 3, 3, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 87, 4, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 101, 5, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 94, 6, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 14, 7, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 93, 8, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 8, 9, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 4, 10, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 46, 11, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 16, 12, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 10, 13, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 11, 14, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 97, 15, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 146, 16, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 98, 17, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 99, 18, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 95, 19, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 145, 20, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (68, 50, 21, CAST(N'2024-03-21T00:00:00.000' AS DateTime))

INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 1, 1, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 2, 2, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 3, 3, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 87, 4, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 101, 5, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 94, 6, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 14, 7, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 93, 8, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 8, 9, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 4, 10, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 46, 11, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 16, 12, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 10, 13, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 11, 14, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 97, 15, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 146, 16, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 208, 17, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 98, 18, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 99, 19, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 95, 20, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 145, 21, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 207, 22, CAST(N'2024-03-21T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (69, 50, 23, CAST(N'2024-03-21T00:00:00.000' AS DateTime))


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