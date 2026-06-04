USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v260100 to v260101.
Run this script on [RateManager] v260100 to upgrade it to [RateManager] v260100.
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
SET @FromDVersion = '2601.00'; -- the DVersion in the database
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

-- US1524244: V2601.01 - Medicare APC Add New Field
GO
PRINT N'Altering Table [dbo].[PPS_medapc_h]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_medapc_h]')
          AND name = 'reduc_340b'
)
BEGIN
    ALTER TABLE [dbo].[PPS_medapc_h] ADD [reduc_340b] VARCHAR(5) NULL
END

GO
PRINT N'Altering Table [dbo].[TMP_IM_medext_h]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[TMP_IM_medext_h]')
          AND name = 'reduc_340b'
)
BEGIN
    ALTER TABLE [dbo].[TMP_IM_medext_h] ADD [reduc_340b] VARCHAR(5) NULL
END

-- US1527490: V2601.01 - ESRD Pricer New Field
GO
PRINT N'Altering Table [dbo].[PPS_esrdprc_60]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_esrdprc_60]')
          AND name = 'napa'
)
BEGIN
    ALTER TABLE [dbo].[PPS_esrdprc_60] ADD [napa] VARCHAR(5) NULL
END

GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2512.01', N'2601.01', NULL, GETDATE())

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

    -- US1524244: V2601.01 - Medicare APC Add New Field
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4497, 13, N'E.16', N'reduc_340b', N'The payment reduction applied to certain non-drug items and services for certain providers subject to the 340B Payment Policy Remedy.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Reduction for Providers Subject to the 340B Remedy Offset:', N'1.0000', NULL, 5, 57, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260122 00:00:00.000', NULL, '20260101', '99991231', NULL)

    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableLeftCount] = 446, [VariableFormat] = N'X (446)', [VariableSizeInC] = 446, [StartPositionInC] = 62, [ModifiedTS] = '20260122 00:00:00.000' WHERE [LUTPTVID] = 4255

    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7045, 13, 163, N'TextBlock', N'Text', NULL, NULL, NULL, 31, 1, '20260122 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7046, 13, 163, N'TextBox', N'Text', NULL, NULL, NULL, 32, 1, '20260122 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3923, 7045, 4497)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3924, 7046, 4497)

    -- US1527490: V2601.01 - ESRD Pricer New Field
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4502, 32, N'D.17', N'napa', N'Adjustment applied the non-labor portion of the ESRD facility base rate for certain non-contiguous areas.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Non-Contiguous Areas Payment Adjustment:', N'1.0000', NULL, 5, 412, 0, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260122 00:00:00.000', NULL, '20260101', '99991231', NULL)
    
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableLeftCount] = 21, [VariableFormat] = N'X (21)', [VariableSizeInC] = 21, [StartPositionInC] = 417, [ModifiedTS] = '20260122 00:00:00.000' WHERE [LUTPTVID] = 4469

    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7047, 32, 2567, N'TextBlock', N'Text', NULL, NULL, NULL, 39, 1, '20260122 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7048, 32, 2567, N'TextBox', N'Text', NULL, NULL, NULL, 40, 1, '20260122 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3925, 7047, 4502)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3926, 7048, 4502)

    -- US1529431: V2601.01 - New Mexico and New Mexico APC Description Updates
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Under the New Mexico Medicaid DRG-based payment system, a base rate per discharge value is calculated for each facility. This base rate may be increased for facilities designated as a hospital with a high total Medicaid as well as high share of Native American members for Managed Care Organization (MCO) reimbursements.', [ModifiedTS]='20260122 00:00:00.000', [DisplayStartDate]='20260101' WHERE [LUTPTVID]=2367
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Under the New Mexico Medicaid reimbursement system, hospitals receive a hospital-specific per case add-on rate for capital costs. This capital rate may be increased for facilities designated as a hospital with a high total Medicaid as well as high share of Native American members for MCO reimbursements.

Set this field equal to the hospital''s capital add-on to receive this additional payment. If no capital add-on should be applied, set this field to zero.', [ModifiedTS]='20260122 00:00:00.000', [DisplayStartDate]='20260101' WHERE [LUTPTVID]=2368

UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'OPPS percentage multiplier that is used to adjust reimbursement for all services excluding certain laboratory services.

For the University of New Mexico Hospital a 10% (0.10000) increase is applied, and for all other in-state hospitals a 18% (0.18000) increase is applied. ', [ModifiedTS]='20260122 00:00:00.000', [DisplayStartDate]='20260101' WHERE [LUTPTVID]=4112

-- US1532131: V2601.01 - default value and description updates:
-- Medicare HHA
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'A fixed dollar amount used to determine outlier eligibility. The formula used to calculate this dollar amount is as follows:

(0.37 * SEQ D.1)', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1273
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feehh26', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1291
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This field is to be used by customized fee schedule entries.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1298
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'1.7200', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2781
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'1.6225', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2782
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'1.6696', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2783
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'1.7238', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=4243

-- Medicare ASC
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feeasc25', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1260
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'A quality reduction applies to all ASCs that have not submitted quality reporting data, per CMS-1601-FC. This factor only applies to procedure codes that are assigned to a Payment Status Indicator of A2, D2, G2, J8, P2, R2, or Z2.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2786

-- Medicare ESRD
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0.56', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1309
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0.4873', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=4387

-- Medicare Hospice
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feehsp26', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=4203

-- Medicare DRG
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'If the PPS Waiver indicator is set to Y or C (SEQ# H.9), enter the desired factor to be applied to total charges in this field.

For Maryland facilities paid by Medicare Advantage (MA) payers, enter 0.9230 (Public Payer Differential) minus any GME discount factor.

For Maryland facilities paid by Fee-for-Service (FFS) payers, enter 0.9230 (Public Payer Differential).

For CAHs, enter the cost reduction factor to be applied to the submitted charges. The value is available from your MAC. Per the Medicare Prescription Drug Improvement and Modernization Act of 2003 (MMA) CAHs are paid 101% of reasonable cost. CAHs that are not meaningful Electronic Health Record (EHR) users are paid 100.00% instead of 101%. The factor should include the appropriate adjustment.

For all non-waived facilities, enter 0.0000.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=89
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Per H.R. 5371 (Continuing Appropriations, Agriculture, Legislative Branch, Military Construction and Veterans Affairs, and Extensions Act, 2026), if a hospital has 500 or fewer total discharges, and is located more than 15 miles from the nearest subsection (d) hospital, enter 0.250000 in this field. If a hospital has more than 500 and fewer than 3,800 total discharges and is located more than 15 miles from the nearest subsection (d) hospital, supply the value calculated as follows:

(19/66) - (discharges/13,200)

Note: The CMS Provider Specific File (PSF), which serves as the source for determining factors in the NMPRF, has not yet been fully updated to reflect the latest requirements for the LV program. As such, the PSF remains the primary reference. Optum has proceeded with updating the NMPRF based on the current PSF data and will continue to monitor for updates and make adjustments as needed.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=92

-- Medicare IRF
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Used to adjust the federal labor-related prospective payment rate for local wage differences. This index is specific to the hospital''s geographic location (i.e., urban or rural).

For FY 2026, the wage index is based solely on Core-Based Statistical Areas (CBSAs). CBSA based wage indices are located on the Centers for Medicare & Medicaid Services (CMS) web site.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=774
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This adjustment is intended to compensate hospitals located in non-metropolitan areas that have higher per diem costs than those in metropolitan areas.

Note: Per the Final Rule, changes to the OMB Core-Based Statistical Area (CBSA) delineations resulted in certain counties being designated as urban that had previously been classified as rural. To mitigate the effect of the significant loss in payment for the IRFs located in these counties, CMS implemented a three-year budget-neutral phase-out to the rural adjustment for the providers that transitioned from rural to urban in FY 2025. The rural adjustments for these providers are:

FY2025: 1.0993
FY2026: 1.0497
FY 2027 and later: No rural adjustment', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=775
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific Cost-to-Charge Ratio (CCR). Hospital-specific CCRs are computed annually by the MAC using information on the IRFs latest settled cost report and charge data for the same period. Used in calculating cost outlier payments.

For FY 2026, the national average CCRs are 0.463000 for rural facilities and 0.398000 for urban facilities. National CCRs are used by new facilities, facilities which have an overall CCR in excess of the national ceiling (1.540000), and other facilities for which an overall CCR could not be accurately calculated.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=781
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'10,141.00', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=783

-- Medicare IPF
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'892.87', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1423
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0.79000', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1424
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This adjustment is intended to compensate hospitals for the indirect costs of providing medical education. This field should be rounded to two places after the decimal.

The value is calculated as follows:
(1 + ((# Full Time Equivalent Interns + Residents) / # Average Daily Census))^0.7957', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1426
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'673.85', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1429
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'39,360', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1433
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Facility-specific Ratio of Cost-to-Charges (RCCs) used in calculating cost outlier payments under the prospective payment system. Facility-specific RCCs are computed annually by the FI using information on the facility''s latest settled cost report and charge data for the same period.

The Centers for Medicare & Medicaid Services (CMS) has calculated a national median RCC of 0.5720 for rural IPFs and 0.4200 for urban IPFs. For new facilities, CMS will use these national ratios until the IPFs actual RCC can be computed using the first tentatively settled or final settled cost report data, which will then be used for the subsequent cost report period. CMS will also use the national median RCC for IPFs whose overall RCC is above the upper threshold.

The upper threshold RCC for rural IPFs is 2.4373. The upper threshold RCC for urban IPFs is 1.8305.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1434
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Qualifying Emergency Department (ED) flag - Check this box if the IPF has a qualifying emergency department. A higher adjustment is applied for the 1st day of stay if the IPF has, or is a psychiatric unit in an acute care facility with, a qualifying emergency department.
Starting April 1, 2006 (retroactive to October 1, 2005), the CMS and EASYGroup™ Pricers will recognize Admission Source D to identify claims that are transferred from the emergency department of that same facility. Claims with an Admission Source of D will not receive the qualifying ED variable per diem adjustment factor on the first day of stay. These cases will receive the Day 1 variable per diem adjustment factor in SEQ G.1.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1468
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Adjustment for uncontrolled Diabetes-Mellitus (with or without complications).', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1476
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Adjustment for Chronic Obstructive Pulmonary Disease (COPD) and Sleep Apnea.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=1483

-- TRICARE/CHAMPUS
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Refer to SEQ D.1  above.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2492
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Refer to SEQ D.3 above.', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2494
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'This adjustment is an add-on for the Indirect Medical Education (IME) costs. It is also used in determining cost outlier eligibility and, if eligibility is confirmed, to calculate total costs. This value can be obtained from TRICARE and is calculated as follows:

1.02 [(1 + (#FTE Interns + Residents)/#Beds).5795 – 1]', [ModifiedTS]='20260122 00:00:00.000' WHERE [LUTPTVID]=2497

-- Medicare FQHC : - Dev : yet to do


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