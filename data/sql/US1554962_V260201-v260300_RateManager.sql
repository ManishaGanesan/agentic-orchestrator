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
SET @FromDVersion = '2602.01'; -- the DVersion in the database
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
      VALUES (N'2602.01', N'2603.00', NULL, GETDATE())

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
    -- Medicare Snf update 
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feesnf26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=1035
    -- Medicare Physician
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feephys26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2434
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'facphy26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=3976
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Check this box for providers that are a Qualifying Advanced Alternative Payment Model (APM) Participant (QP). Providers that are not QPs, do not check this box.', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4503
    --Medicare RHC 
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feerhc26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4305
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'319.38', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4374
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'418.45', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4461
    
    --New York Medicaid APG (Enhanced)
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific, per claim add-on amount for facilities classified as Financially Distressed Hospitals (FDHs), Safety Net Hospitals, Critical Access Hospitals (CAHs), or Sole Community Hospitals (SCHs), or for facilities that are part of the New York City (NYC) Health and Hospital Corporation (HHC).

Note: These add-on amounts apply only to claims from Medicaid Managed Care (MMC) payers that meet the outpatient clinic add-on criteria during approved time periods.', [LabelOnUI]=N'Clinic Add-On for Designated Hospital Types:$', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4322
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific, per claim add-on amount for facilities classified as FDHs, Safety Net Hospitals, CAHs, or SCHs, or for facilities that are part of the NYC HHC.

Note: These add-on amounts apply only to claims from MMC payers that meet the Ambulatory Surgical Center (ASC) add-on criteria during approved time periods.', [LabelOnUI]=N'ASC Add-On for Designated Hospital Types:$', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4323
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific, per claim add-on amount for facilities classified as FDHs, Safety Net Hospitals, CAHs, SCHs, or for facilities that are part of the NYC HHC.

Note: These add-on amounts apply only to claims from MMC payers that meet the Emergency Room (ER) add-on criteria during approved time periods.', [LabelOnUI]=N'ER Add-On for Designated Hospital Types:$', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4324
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feeny26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4034

    --contract APC 
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The payment reduction to be applied to certain non-drug items and services for providers eligible for the 340B remedy offset.', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4509

    -- Oklahoma Medicaid APC
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feeok26', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4383

    --Tricare Champus 

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0.2251', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2498
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'40,397.00', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2499
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0.9370', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2504
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'1.2600', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2505

    --New_York_Medicaid_APR-DRG
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific, per discharge add-on amount for Safety Net Hospitals or facilities that have been identified as financially distressed.

Note: This add-on payment applies only to claims from MMC payers for certain newborn, maternity, and medical/surgical services.', [LabelOnUI]=N'Add-On for Designated Hospital Types:$', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4316
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific, per discharge add-on amount for eligible facilities.

Note: This add-on payment applies only to claims from MMC payers for certain newborn, maternity, and medical/surgical services.', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4437

    --New_Mexico_Medicaid

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The Ratio of Cost-to-Charges (RCCs) used to determine the actual costs of a claim in the calculation of cost outlier payments.', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=2374
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Adjustment factor applied to Hospital Base and Capital Rates for facilities designated as a hospital with a high total Medicaid and high share of Native American members for Managed Care Organization (MCO) reimbursements.

If no adjustment should be applied, set this field to 1.0000.', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4506


    --New York Medicaid Psychiatric Exempt

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The facility-specific add-on amount for Safety Net hospitals or facilities that have been identified as financially distressed. This add-on amount is applied for each day of the stay.

Note: This add-on payment applies only to claims from MMC payers for certain psychiatric services.', [LabelOnUI]=N'Add-On for Designated Hospital Types:$', [ModifiedTS]='20260305 00:00:00.000' WHERE [LUTPTVID]=4317



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
