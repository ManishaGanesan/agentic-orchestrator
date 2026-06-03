USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v250600 to V250601.
Run this script on [RateManager] v250600 to upgrade it to [RateManager] V250601.
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
SET @FromDVersion = '2506.00'; -- the DVersion in the database
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

-- US1410208: V2506.01 - Medicare DRG SEQ#, Field Desc and End Date Updates &
-- DE295914: V2506.01 - Medicare DRG: calculated field(s) not being saved correctly; RM warns of modified fields on opening record

GO
PRINT N'Altering Function [dbo].[udf_CalculateMedicareCMS_baser]...';

GO

-- ================================================================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- ================================================================================
/**********************************************************************************  
SELECT top 1000
	(SELECT value from dbo.udf_CalculateMedicareCMS_baser(
	effdate, lowvoladj,lowvoladj_new, sch_addon,sch_addon_new
,caphrate, fp, fwa, iea, dshare, dshreduc, rpaf, o_vbp_adj, hac_fac))
FROM PPS_medprc_A_formatted_VW pps WITH (NOLOCK) INNER JOIN DTA_PaysourcePricer psp WITH (NOLOCK) ON psp.DTAPSPID = pps.DTAPSPID

SELECT effdate,baser,hac_fac FROM PPS_medprc_A pps WITH (NOLOCK) INNER JOIN DTA_PaysourcePricer psp WITH (NOLOCK) ON psp.DTAPSPID = pps.DTAPSPID

***********************************************************************************/  
CREATE OR ALTER FUNCTION [dbo].[udf_CalculateMedicareCMS_baser]
(	
@effdate datetime, @lowvoladj float, @lowvoladj_new float, @sch_addon float, @sch_addon_new float
,@caphrate float, @fp float, @fwa float, @iea float, @dshare float, @dshreduc float, @rpaf float, @o_vbp_adj float, @hac_fac float, @fwa_new float
)
RETURNS TABLE 
AS
RETURN 
(
SELECT 
	CASE WHEN (@effdate < CONVERT(DATETIME, '10/01/2014',101)) THEN -- < 2014-10-01
		tmp.[value]
	ELSE
		tmp.[value] * CASE WHEN @hac_fac = 0 THEN 1 ELSE @hac_fac END
	
	END as [value]
FROM
(SELECT 
	CASE 
		WHEN (@effdate < CONVERT(DATETIME, '10/01/2010',101)) THEN -- < 2010-10-01 
			Round(CASE WHEN @sch_addon_new > 0 THEN @sch_addon_new ELSE @sch_addon END + ((1 + CASE WHEN @lowvoladj_new > 0 THEN @lowvoladj_new ELSE @lowvoladj END) * (@fwa * (1 + @iea + (Round(@dshare * @dshreduc, 4))))), 2)
		WHEN (@effdate < CONVERT(DATETIME, '10/01/2012',101)) THEN -->= 10/1/2010 and < 2012-10-01
			((@fwa * (1 + @iea + (@dshreduc * @dshare))) + CASE WHEN @sch_addon_new > 0 THEN @sch_addon_new ELSE @sch_addon END) * (1 + CASE WHEN @lowvoladj_new > 0 THEN @lowvoladj_new ELSE @lowvoladj END)
		WHEN (@effdate < CONVERT(DATETIME, '10/01/2020',101)) THEN -->= 10/1/2012 and < 2020-10-01
			(((@fwa * (1 + @iea + (@dshreduc * @dshare))) + CASE WHEN @sch_addon_new > 0 THEN @sch_addon_new ELSE @sch_addon END) * (1 + CASE WHEN @lowvoladj_new > 0 THEN @lowvoladj_new ELSE @lowvoladj END)) - ((@fwa - (@fwa * @rpaf)) + (@fwa - (@fwa * CASE @o_vbp_adj WHEN 0 THEN 1 ELSE ISNULL(@o_vbp_adj,1) END)))
		ELSE
			(((@fwa_new * (1 + @iea + (@dshreduc * @dshare))) + CASE WHEN @sch_addon_new > 0 THEN @sch_addon_new ELSE @sch_addon END) * (1 + CASE WHEN @lowvoladj_new > 0 THEN @lowvoladj_new ELSE @lowvoladj END)) - ((@fwa_new - (@fwa_new * @rpaf)) + (@fwa_new - (@fwa_new * CASE @o_vbp_adj WHEN 0 THEN 1 ELSE ISNULL(@o_vbp_adj,1) END)))
	END as [value]) as tmp
)

GO


GO
PRINT N'Altering Function [dbo].[udf_CalculateMedicareCMS_tcapaddon]...';
GO

-- ================================================================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- ================================================================================
/**********************************************************************************  
SELECT top 1000
	(SELECT value from dbo.udf_CalculateMedicareCMS_tcapaddon(
	effdate, caphrate, caphblend, capadjfrate, capfedportion
,capimea, capdshare, lowvoladj_new, hac_fac))
FROM PPS_medprc_A_formatted_VW pps WITH (NOLOCK) INNER JOIN DTA_PaysourcePricer psp WITH (NOLOCK) ON psp.DTAPSPID = pps.DTAPSPID
SELECT tcapaddon from PPS_medprc_A
***********************************************************************************/  
CREATE OR ALTER FUNCTION [dbo].[udf_CalculateMedicareCMS_tcapaddon]
(	
@effdate datetime, @caphrate float, @caphblend float, @capadjfrate float, @capfedportion float
,@capimea float, @capdshare float, @lowvoladj_new float, @hac_fac float
)
RETURNS TABLE 
AS
RETURN 
(
SELECT 
	CASE 
		WHEN (@effdate < CONVERT(DATETIME, '10/01/2014',101)) THEN -- >= 2014-10-01
			tmp.tcapaddon
		ELSE
			tmp.tcapaddon * CASE WHEN @hac_fac = 0 THEN 1 ELSE @hac_fac END
	END as [value]
FROM
	(SELECT ((@capadjfrate * @capfedportion * (1 + @capimea + @capdshare)) * (1 + @lowvoladj_new)) as tcapaddon) as tmp
)

GO

GO
PRINT N'Update complete.';

GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2506.01', N'2506.01', NULL, GETDATE())

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

    -- US1410208: V2506.01 - Medicare DRG SEQ#, Field Desc and End Date Updates
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.3', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=30
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.5', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=31
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20150101' WHERE [LUTPTVID]=33
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'If the hospital is operating under a waiver (for example, hospitals in the state of Maryland) and is not subject to the IPPS, or to request percent-of-charge pricing for this facility, set this field to Y.
If the hospital is a CAH and is not subject to the IPPS, set this field to C. These facilities will be paid the cost-based per diem if the Total Per Diem Pass-Through (SEQ# H.6) is greater than 0. Otherwise these facilities will be paid a percent of billed charges as defined by the Waiver Factor (SEQ# H.11).', [StringLength]=1, [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=37
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.9', [VariableDescr]=N'This field is no longer used and has been replaced by the Federal Wage Adjusted Rate (new) field (SEQ# D.10)', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=41
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20170101' WHERE [LUTPTVID]=34
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20130930' WHERE [LUTPTVID]=35
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20150101' WHERE [LUTPTVID]=39
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20170101' WHERE [LUTPTVID]=44
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20170101' WHERE [LUTPTVID]=45
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20170101' WHERE [LUTPTVID]=42
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20180101' WHERE [LUTPTVID]=76
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.6', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=43
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20250619 00:00:00.000', [DisplayEndDate]='20230930' WHERE [LUTPTVID]=66
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.4', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=74
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'For hospitals subject to the IPPS, enter the per diem pass-through amount. The per diem pass-through amount is used by Medicare to reimburse hospitals for certain expenses that are not fully accounted for in the standard DRG payment rate. These expenses include capital, Direct Medical Education (DME), organ acquisition expenses,  supply chain costs, and allogeneic stem cell per diem pass-through.

For each claim, the pass-through amount is multiplied by the patient''s Length of Stay (LOS) and added to the total reimbursement for the claim. The pass-through payment is paid in addition to the IPPS amount for the DRG. It is generally paid as an estimated per diem, then retrospectively adjusted based on actual expenses.

For CAHs, enter the per diem amount. The value is available from your MAC. Per the Medicare Prescription Drug Improvement and Modernization Act of 2003 (MMA) CAHs are paid 101% of reasonable cost. Effective October 01, 2016, CAHs that are not meaningful Electronic Health Record (EHR) users are paid 100.00% instead of 101%. The per diem amount should include the appropriate adjustment.', [LabelOnUI]=N'Total Per Diem Pass-Through:$', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=82
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The pass thru amount may include pass-thru expenses related to the costs of DME, organ acquisition, and supply chain. For Medicare Risk pricing, these costs can be eliminated from the pass thru component. Enter the sum of the DME, organ acquisition, and supply chain pass thru per diem expenses in this field.

This entry must be less than or equal to the Total Per Diem Pass-Through amount (SEQ# H.6), which will equal the DME, organ acquisition, and supply chain amounts plus any other pass thru expenses. If Medicare Risk pricing is not required, a zero can be entered here ($0.00).', [LabelOnUI]=N'Per Diem Pass-Through Not Paid by MA:$', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=85
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.7', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=87
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'If the PPS Waiver indicator is set to Y or C (SEQ# H.10), enter the desired factor to be applied to total charges in this field.

For Maryland facilities paid by Medicare Advantage (MA) payers, enter 0.9230 (Public Payer Differential) multiplied by any GME discount factor.

For Maryland facilities paid by Fee-for-Service (FFS) payers, enter 0.9230 (Public Payer Differential).

For CAHs, enter the cost reduction factor to be applied to the submitted charges. The value is available from your MAC. Per the Medicare Prescription Drug Improvement and Modernization Act of 2003 (MMA) CAHs are paid 101% of reasonable cost. Effective October 01, 2016, CAHs that are not meaningful Electronic Health Record (EHR) users are paid 100.00% instead of 101%. The factor should include the appropriate adjustment.

For all non-waived facilities, enter 0.0000.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=89
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.12', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=1955
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.13', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=2607
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.8', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4067
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.10', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4178
UPDATE [dbo].[LUT_PricerTypeVariable] SET [LabelOnUI]=N'Allogeneic Stem Cell Per Diem Pass-Through Amount:$', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4179
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Please refer to SEQ# F.2 for the description and corresponding calculation for this field.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=96
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Please refer to SEQ# F.3 for the description and corresponding calculation for this field.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=97
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Please refer to SEQ# F.1 for the description and corresponding calculation for this field.', [CalculationJs] = N'C:var effdate = new Date(''{effdate}'');
var lowvoladj = ((parseFloat(''{lowvoladj_new}'') > 0) ? {lowvoladj_new} : {lowvoladj});
var sch_addon = ((parseFloat(''{sch_addon_new}'') > 0) ? {sch_addon_new} : {sch_addon});
var baser;
if (effdate < new Date(''10/01/2010''))
	baser = ( sch_addon + ((1 + lowvoladj ) * ({fwa} * (1 + {iea} +  parseFloat(({dshare} * {dshreduc}).toFixed(4)) )))).toFixed(2);
else if (effdate < new Date(''10/01/2012''))
	baser = (({fwa} * (1 + {iea} + ({dshreduc} * {dshare}))) + sch_addon ) * (1 + lowvoladj );
else
	var o_vbp_adj = [ 0 , NaN ].includes(parseFloat(''{o_vbp_adj}'')) ? 1 : {o_vbp_adj},
	fwa = ((parseFloat(''{fwa_new}'') > 0) ? {fwa_new} : {fwa}),
	baser = ((( fwa * (1 + {iea} + ({dshreduc} * {dshare}))) + sch_addon ) * (1 + lowvoladj )) - (( fwa - ( fwa * {rpaf})) + ( fwa - ( fwa * o_vbp_adj)));
if (effdate >= new Date(''10/01/2014''))
	var hac_fac = [ 0 , NaN ].includes(parseFloat(''{hac_fac}'')) ? 1 : {hac_fac},
	baser = baser * hac_fac;
console.log(''Calculating_MedicareCMS_baser:baser='' + baser);
return baser;', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=98
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The total federal rate for operating costs (including both regional and national portions, as appropriate), with adjustments for local wage differences. This is the hospital''s total federal operating rate after the adjustments for IME and disproportionate share have been applied. The formula is as follows:

(The letters refer to the sequence letter associated with each variable)

((((D.10 * (1 + E.3 + (E.4 * E.5))) + E.8) * (1 + H.5)) - (D.10 * (1 - E.12)) - (D.10 * (1 - E.13))) * H.4', [CalculationJs] = N'C:var effdate = new Date(''{effdate}'');
var lowvoladj = ((parseFloat(''{lowvoladj_new}'') > 0) ? {lowvoladj_new} : {lowvoladj});
var sch_addon = ((parseFloat(''{sch_addon_new}'') > 0) ? {sch_addon_new} : {sch_addon});
var baser;
if (effdate < new Date(''10/01/2010''))
	baser = ( sch_addon + ((1 + lowvoladj ) * ({fwa} * (1 + {iea} +  parseFloat(({dshare} * {dshreduc}).toFixed(4)) )))).toFixed(2);
else if (effdate < new Date(''10/01/2012''))
	baser = (({fwa} * (1 + {iea} + ({dshreduc} * {dshare}))) + sch_addon ) * (1 + lowvoladj );
else
	var o_vbp_adj = [ 0 , NaN ].includes(parseFloat(''{o_vbp_adj}'')) ? 1 : {o_vbp_adj},
	fwa = ((parseFloat(''{fwa_new}'') > 0) ? {fwa_new} : {fwa}),
	baser = ((( fwa * (1 + {iea} + ({dshreduc} * {dshare}))) + sch_addon ) * (1 + lowvoladj )) - (( fwa - ( fwa * {rpaf})) + ( fwa - ( fwa * o_vbp_adj)));
if (effdate >= new Date(''10/01/2014''))
	var hac_fac = [ 0 , NaN ].includes(parseFloat(''{hac_fac}'')) ? 1 : {hac_fac},
	baser = baser * hac_fac;
console.log(''Calculating_MedicareCMS_baser:baser='' + baser);
return baser;' , [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=46
-- US1413957: V2506.01 - Default value and description updates: New York Medicaid APG (Enhanced), Oklahoma Medicaid APC
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The rate to be paid for vaccines classified to certain APGs that are provided for free by the state to children (indicated with a Modifier of SL (State Supplied Vaccine (VFC Program)).

This rate is intended to reimburse the provider for the administration only.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4024
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The rate to be paid for services classified to certain APGs that are provided without cost to the provider (indicated with a Modifier of FB (Obtained by Provider at No Cost)).

This rate is intended to reimburse the provider for the administration only.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4025
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The type of facility:

01 = Hospital-Based (Clinic, Emergency Department, or ASC)
02 = Free-Standing Diagnostic Treatment Center (DTC)
03 = Office of Mental Health (OMH) Certified Clinic; Hospital-Based
04 = OMH Certified Clinic; Free-Standing DTC', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4241
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The adjustment to be applied when Modifiers U1 and U7 (Language Other Than English-Only for Services Provided Via an Outside/Contracted Interpreter Service) are reported on a service line for Article 31 Facilities.', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4337
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'feeok25', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4383
UPDATE [dbo].[LUT_PricerTypeVariable] SET [DefaultValue]=N'0', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4442
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'Payment adjustment that is applied over a five year period for integrated eConsultations between eligible physical health and behavioral health providers. This adjustment applies when procedure code 99451 or 99452 are billed with a combination of Modifier U1 and U1 (eConsult payment enhancement).', [ModifiedTS]='20250619 00:00:00.000' WHERE [LUTPTVID]=4484

-- US1411633: V2506.01 - Medicaid APR Pro - State Procedure and Variable Updates
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (257, N'0015', N'Return Code 24: Non-Covered Claim Due to Zero Covered Days', 1, 84)

UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = [DisplayOrder] + 2 WHERE [LUTSID] = 80 AND [DisplayOrder] >= 5;
UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 5 WHERE [LUTSID] = 80 AND [DisplayOrder] = 4;

INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 75, 4, CAST(N'2025-06-19T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 257, 6, CAST(N'2025-06-19T00:00:00.000' AS DateTime))

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
