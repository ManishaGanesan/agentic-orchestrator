USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v250101 to v250200.
Run this script on [RateManager] v250101 to upgrade it to [RateManager] v250200.
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
SET @FromDVersion = '2501.01'; -- the DVersion in the database
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

-- US1341074: V2502.00 - New field added to Contract APC

GO
PRINT N'Altering Table [dbo].[PPS_apcpro_i]...';

GO
    IF NOT EXISTS (
      SELECT 1 
      FROM   sys.columns 
      WHERE  object_id = OBJECT_ID(N'[dbo].[PPS_apcpro_i]') 
             AND name = 'dev_limit_flag'
    )
    BEGIN
        ALTER TABLE [dbo].[PPS_apcpro_i] ADD [dev_limit_flag] VARCHAR (1) NULL;
    END

    IF NOT EXISTS (
      SELECT 1 
      FROM   sys.columns 
      WHERE  object_id = OBJECT_ID(N'[dbo].[PPS_apcpro_i]') 
             AND name = 'id_rcc'
    )
    BEGIN
        ALTER TABLE [dbo].[PPS_apcpro_i] ADD [id_rcc] VARCHAR (7) NULL;
    END
GO 
PRINT N'Altering Table [dbo].[TMP_IM_medext_i]...'; 

GO
    IF NOT EXISTS (
     SELECT 1 
     FROM   sys.columns 
    WHERE  object_id = OBJECT_ID(N'[dbo].[TMP_IM_medext_i]') 
           AND name = 'dev_limit_flag'
    )
    BEGIN
       ALTER TABLE [dbo].[TMP_IM_medext_i] ADD [dev_limit_flag] VARCHAR (1) NULL;
    END

    IF NOT EXISTS (
     SELECT 1 
     FROM   sys.columns 
    WHERE  object_id = OBJECT_ID(N'[dbo].[TMP_IM_medext_i]') 
           AND name = 'id_rcc'
    )
    BEGIN
       ALTER TABLE [dbo].[TMP_IM_medext_i] ADD [id_rcc] VARCHAR (7) NULL;
    END

GO
PRINT N'Update complete.';

GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2412.00', N'2502.00', NULL, GETDATE())

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

    -- US1341074 & US1344522 : V2502.00 - New fields added & Sequence number updates to Contract APC
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4474, 14, N'E.46', N'dev_limit_flag', N'', N'DECIMAL', 1, 0, N'9(1)', NULL, N'Non-Opioid Device/Drug Payment Limit Flag:', N'1', NULL, 1, 185, 1, NULL, NULL, 0, NULL, NULL, 3, 1, '20250206 00:00:00.000', NULL, '20250101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4475, 14, N'E.47', N'id_rcc', N'The implantable device Ratio of Costs-to-Charges (RCCs). If available, this figure is used to calculate reimbursement for services assigned to Payment Status Indicators H and H1
(Pass-Through Device Categories). If not available, the outpatient RCC (SEQ G.1) is used.', N'DECIMAL', 1, 6, N'9(1)v9(6)', NULL, N'Implantable Devices RCC:', N'0.00000', NULL, 7, 178, 1, NULL, NULL, 0, 9.999999, NULL, 3, 1, '20250206 00:00:00.000', NULL, '00010101', '99991231', NULL)
   
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [LabelOnUI]=N'Payment Status H and H1 Items:', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=1542
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [LabelOnUI]=N'Payment Status G, K, & K1 Items:', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=1544
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableFormat]= N'X(322)', [VariableLeftCount] = 322, [VariableSizeInC] = 322, [StartPositionInC] = 186, ModifiedTS = '20250206 00:00:00.000' where [LUTPTVID] =4427 
    
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=1510
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.17', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=1511
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.18', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2603
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.19', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2604
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.20', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2866
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.21', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2867
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.22', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3130
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.23', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3131
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.24', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3236
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.25', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3237
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.26', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3267
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.27', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3338
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.28', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3393
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.29', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3394
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.30', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3395
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.31', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3396
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.32', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3397
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.33', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3466
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.34', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3467
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.35', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3468
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.36', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3469
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.37', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3525
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.38', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3563
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.39', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3564
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.40', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3921
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.41', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=3987
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.42', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=4261
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.43', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=4262
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.44', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=4402
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.45', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=4420

    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7015, 14, 2918, N'TextBlock', N'Text', NULL, NULL, NULL, 93, 1, '20250206 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7016, 14, 2918, N'CheckBox', N'IsChecked', NULL, NULL, NULL, 94, 1, '20250206 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7017, 14, 2918, N'TextBlock', N'Text', NULL, NULL, NULL, 95, 1, '20250206 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7018, 14, 2918, N'TextBox', N'Text', NULL, NULL, NULL, 96, 1, '20250206 00:00:00.000', NULL)   
    UPDATE [dbo].[TML_PricerPageTL] SET [FieldTextValue]=N'Paystatus H and H1 Flag', [ModifiedTS]='20250206 00:00:00.000' WHERE [TMLPPTID]=3018
    UPDATE [dbo].[TML_PricerPageTL] SET [FieldTextValue]=N'Paystatus K and K1 Flag', [ModifiedTS]='20250206 00:00:00.000' WHERE [TMLPPTID]=6219

    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3887, 7015, 4474)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3888, 7016, 4474)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3889, 7017, 4475)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3890, 7018, 4475)

    -- US1341607: V2502.00 - TRICARE/CHAMPUS Field Updates
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250206 00:00:00.000', [DisplayEndDate]='20050930' WHERE [LUTPTVID]=2500
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250206 00:00:00.000', [DisplayEndDate]='20050930' WHERE [LUTPTVID]=2501
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.3', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2502
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.4', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2503
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.5', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2504
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.6', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2505
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250206 00:00:00.000', [DisplayEndDate]='20050930' WHERE [LUTPTVID]=2506
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.7', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2507
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250206 00:00:00.000', [DisplayEndDate]='20050930' WHERE [LUTPTVID]=2508
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.8', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2509
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.9', [ModifiedTS]='20250206 00:00:00.000' WHERE [LUTPTVID]=2510

    -- US1343272: V2502.00 - Medicaid APG Pro State Procedure Update
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=6  WHERE LUTSID = 10 and LUTPID=21
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=7  WHERE LUTSID = 10 and LUTPID=22
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=8  WHERE LUTSID = 10 and LUTPID=52
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=9  WHERE LUTSID = 10 and LUTPID=23
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=10  WHERE LUTSID = 10 and LUTPID=61
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=11  WHERE LUTSID = 10 and LUTPID=25
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=12  WHERE LUTSID = 10 and LUTPID=26
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=13  WHERE LUTSID = 10 and LUTPID=141
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=14  WHERE LUTSID = 10 and LUTPID=57
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=15  WHERE LUTSID = 10 and LUTPID=27
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=16  WHERE LUTSID = 10 and LUTPID=28
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=17  WHERE LUTSID = 10 and LUTPID=29
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=18  WHERE LUTSID = 10 and LUTPID=30
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=19  WHERE LUTSID = 10 and LUTPID=31
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=20  WHERE LUTSID = 10 and LUTPID=32
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=21  WHERE LUTSID = 10 and LUTPID=33
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=22  WHERE LUTSID = 10 and LUTPID=34
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=23  WHERE LUTSID = 10 and LUTPID=54
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=24  WHERE LUTSID = 10 and LUTPID=55
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=25  WHERE LUTSID = 10 and LUTPID=56
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=26  WHERE LUTSID = 10 and LUTPID=53
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (10, 237, 5, CAST(N'2025-02-06T00:00:00.000' AS DateTime))

    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=6  WHERE LUTSID = 57 and LUTPID=21
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=7  WHERE LUTSID = 57 and LUTPID=22
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=8  WHERE LUTSID = 57 and LUTPID=52
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=9  WHERE LUTSID = 57 and LUTPID=23
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=10  WHERE LUTSID = 57 and LUTPID=61
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=11  WHERE LUTSID = 57 and LUTPID=25
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=12  WHERE LUTSID = 57 and LUTPID=26
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=13  WHERE LUTSID = 57 and LUTPID=141
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=14  WHERE LUTSID = 57 and LUTPID=142
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=15  WHERE LUTSID = 57 and LUTPID=57
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=16  WHERE LUTSID = 57 and LUTPID=27
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=17  WHERE LUTSID = 57 and LUTPID=28
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=18  WHERE LUTSID = 57 and LUTPID=29
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=19  WHERE LUTSID = 57 and LUTPID=30
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=20  WHERE LUTSID = 57 and LUTPID=31
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=21  WHERE LUTSID = 57 and LUTPID=32
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=22  WHERE LUTSID = 57 and LUTPID=33
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=23  WHERE LUTSID = 57 and LUTPID=34
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=24  WHERE LUTSID = 57 and LUTPID=54
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=25  WHERE LUTSID = 57 and LUTPID=55
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=26  WHERE LUTSID = 57 and LUTPID=56
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder]=27  WHERE LUTSID = 57 and LUTPID=53
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (57, 237, 5, CAST(N'2025-02-06T00:00:00.000' AS DateTime))

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