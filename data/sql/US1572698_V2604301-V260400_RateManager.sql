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
SET @FromDVersion = '2603.01'; -- the DVersion in the database
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
DECLARE @errMessage nvarchar(max)
DECLARE @currentCompatibility varchar(10)
DECLARE @sqlDBName nvarchar(max) = DB_NAME()

SELECT
  @currentCompatibility = CAST(COMPATIBILITY_LEVEL AS nvarchar)
FROM SYS.DATABASES
WHERE NAME = @sqlDBName
SET @errMessage = N''

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
  SET @errMessage = N'Unable to detect SQL Server Version. Product version: ' + @productVersion;
  INSERT INTO [dbo].[DTA_EventLog] ([LoginSessionGUID], [LoginUser], [TypeEnum], [ApplicationEnum], [SourceEnum], [SourceName], [Description], [DescriptionDetail], [Data], [InsertedTS])
    VALUES (NULL, SYSTEM_USER, 3, 4, 3, 'Script', @errMessage, @errMessage + ' for ' + SUBSTRING(@@Version, 1, 70), NULL, GETDATE());

  RAISERROR (@errMessage, 0, 0)
END
ELSE
IF @currentCompatibility <> @compatibilityLevel
BEGIN
  SET @errMessage = N'SQL compatibility levels mismatch. Current: ' + @currentCompatibility + ';  Expected: ' + @compatibilityLevel;
  INSERT INTO [dbo].[DTA_EventLog] ([LoginSessionGUID], [LoginUser], [TypeEnum], [ApplicationEnum], [SourceEnum], [SourceName], [Description], [DescriptionDetail], [Data], [InsertedTS])
    VALUES (NULL, SYSTEM_USER, 1, 4, 3, 'Script', @errMessage, @errMessage + ' for ' + SUBSTRING(@@Version, 1, 70), NULL, GETDATE())

  RAISERROR (@errMessage, 0, 0)
END
GO
-- END: DO NOT DELETE THIS BLOCK

SET NUMERIC_ROUNDABORT OFF;
GO

-- US1572698: V2604.00 - New Field in New York Medicaid Psychiatric Exempt
GO
PRINT N'Altering Table [dbo].[PPS_nymedpsych_68]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_nymedpsych_68]')
          AND name = 'hhc_addon'
)
BEGIN
    ALTER TABLE [dbo].[PPS_nymedpsych_68] ADD [hhc_addon] VARCHAR (10) NULL;
END


BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2604.00', N'2604.00', NULL, GETDATE())

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

    -- US1572698: V2604.00 - New Field in New York Medicaid Psychiatric Exempt
    UPDATE LUT_PricerTypeVariable SET [VariableLeftCount] = 306, VariableFormat = N'X(306)', VariableSizeInC = 306, StartPositionInC = 132 where LUTPTVID=4319
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4518, 91, N'E.7', N'hhc_addon', N'The facility-specific Average Commercial Rate (ACR) add-on amount for facilities that are part of the NY Health and Hospitals Corporation (HHC). This add-on amount is applied for each day of the stay.

Note: This add-on payment applies only to claims from MMC payers for certain psychiatric services.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'Health and Hospitals Corporation Add-on:$', N'0.00', NULL, 10, 122, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20260407 00:00:00.000', NULL, '20240701', '99991231', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7057, 91, 6746, N'TextBlock', N'Text', NULL, NULL, NULL, 13, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7058, 91, 6746, N'TextBox', N'Text', NULL, NULL, NULL, 14, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3935, 7057, 4518)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3936, 7058, 4518)

    -- US1575098: V2604.00 - Default value and description updates: Kansas Medicaid Medicare IPF Medicare LTC Medicare ORF
    -- Medicare LTC
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The National Provider Identifier (NPI) to the rate record that contains the variables used to calculate the Medicare IPPS comparable payments that are used in the short stay and site neutral reimbursement formulas. The additional rates that are necessary to calculate the IPPS comparable amount are explained in the Medicare Inpatient RVW below.

Submit the NPI if the NPI is used to identify the associated acute care facility. If the NPI is submitted, submit any associated Inpatient Taxonomy Code (SEQ G.3).', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=1605
    -- Medicare IPF
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Adjustment applied to the 1st day of stay. Enter 1.28 here for all facilities. If the IPF has a qualifying Emergency Department (ED), SEQ G.11 and SEQ G.12 should also be set.', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=1446
    -- Medicare ORF
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.1', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4339
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4340
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.3', [VariableDescr]=N'A 2% reduction will apply to all Medicare payments per the Protecting Medicare and American Farmers From Sequester Cuts Act, which required a mandatory reduction in Federal spending also known as sequestration.

To apply this reduction, set this factor to 0.9800 for all facilities. If you would not like to apply the sequester reduction, set this factor to 1.0000 for all hospitals.', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4341
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.1', [DefaultValue]=N'feeorf26', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4342
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4343
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.1', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4344
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4345
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.3', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4346
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.1', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4347
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4348
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.3', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4349
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'H.1', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4350
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'H.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4351
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'H.3', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4352
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'I.1', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4353
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'I.2', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4354
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'I.3', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=4355
    -- Kansas Medicaid
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This field is no longer used and should be set to zero. If values are entered in both this field and the Extended Cost Outlier Adjustment field (SEQ E.4), values from the Extended Cost Outlier Adjustment field will be used for reimbursement calculations.', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=2769
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This field is no longer used and should be set to zero. If values are entered in both this field and the Extended Day Outlier Adjustment field (SEQ E.5), values from the Extended Day Outlier Adjustment field will be used for reimbursement calculations.', [ModifiedTS]='20260407 00:00:00.000' WHERE [LUTPTVID]=2770


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
