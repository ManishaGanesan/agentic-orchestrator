USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from V260402 to v260500.
Run this script on [RateManager] V260402 to upgrade it to [RateManager] v260500.
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
SET @FromDVersion = '2605.00'; -- the DVersion in the database
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
PRINT N'Altering Table [dbo].[DTA_PaySourcePricer]...';


GO
ALTER TABLE [dbo].[DTA_PaySourcePricer]
    ADD [phys_rule_override_id] VARCHAR (20) NULL,
        [phys_code_override_id] VARCHAR (20) NULL;
GO

PRINT N'Altering Table [dbo].[LUT_RateEditingMapping]...';
GO
ALTER TABLE [dbo].[LUT_RateEditingMapping]
    ADD [grpr_dateVisible] BIT  NULL CONSTRAINT [DF_grpr_dateVisible_1] DEFAULT ((1)),
        [phys_rule_override_idVisible] BIT          NULL,
        [phys_rule_override_idValue]   VARCHAR (20) NULL,
        [phys_code_override_idVisible] BIT          NULL,
        [phys_code_override_idValue]   VARCHAR (20) NULL;
GO
PRINT N'Altering Table [dbo].[TMP_IM_config]...';


GO
ALTER TABLE [dbo].[TMP_IM_config]
    ADD [phys_rule_override_id] VARCHAR (20) NULL,
        [phys_code_override_id] VARCHAR (20) NULL;


GO
PRINT N'Altering View [dbo].[DTA_PaySourceAll_VW]...';


GO

ALTER VIEW [dbo].[DTA_PaySourceAll_VW]
AS
SELECT
	dbo.DTA_PaySource.LUTPSCID,
	dbo.DTA_PaySource.TMPPSID,
	dbo.DTA_PaySource.facility_id,
	dbo.DTA_PaySource.payer_id,
	dbo.DTA_PaySource.npi,
	dbo.DTA_PaySource.taxonomy,
	dbo.DTA_PaySource.pattype,
	dbo.DTA_PaySource.npi_flag,
	dbo.DTA_PaySource.date_flag,
	dbo.DTA_PaySource.paysource_name,
	dbo.DTA_PaySource.abbrev_name,
	dbo.DTA_PaySourcePricer.DTAPSPID,
	dbo.DTA_PaySourcePricer.DTAPSID,
	dbo.DTA_PaySourcePricer.LUTPTID,
	dbo.DTA_PaySourcePricer.LoginSessionGUID,
	dbo.DTA_PaySourcePricer.LoginUser,
	dbo.DTA_PaySourcePricer.Enabled,
	dbo.DTA_PaySourcePricer.DoNotExport,
	dbo.DTA_PaySourcePricer.InsertedTS,
	dbo.DTA_PaySourcePricer.ModifiedTS,
	dbo.DTA_PaySourcePricer.ImportedTS,
	dbo.DTA_PaySourcePricer.ExportedTS,
	dbo.DTA_PaySourcePricer.ExportedUID,
	dbo.DTA_PaySourcePricer.SharedWeightDTAPSPID,
	dbo.DTA_PaySourcePricer.version,
	dbo.DTA_PaySourcePricer.effdate,
	dbo.DTA_PaySourcePricer.tab_filename,
	dbo.DTA_PaySourcePricer.havewt,
	dbo.DTA_PaySourcePricer.grpr_type,
	dbo.DTA_PaySourcePricer.grpr_vers,
    dbo.DTA_PaySourcePricer.grpr_date,
	dbo.DTA_PaySourcePricer.pricer_type,
	dbo.DTA_PaySourcePricer.icd9_map,
	dbo.DTA_PaySourcePricer.edit_date,
	dbo.DTA_PaySourcePricer.dsc_flag,
	dbo.DTA_PaySourcePricer.poa_flag,
	dbo.DTA_PaySourcePricer.hac_flag,
	dbo.DTA_PaySourcePricer.hac_override_id,
	dbo.DTA_PaySourcePricer.oce_flag,
	dbo.DTA_PaySourcePricer.ocewp_flag,
	dbo.DTA_PaySourcePricer.nonoce_flag,
	dbo.DTA_PaySourcePricer.lcd_flag,
	dbo.DTA_PaySourcePricer.map_override_id,
	dbo.DTA_PaySourcePricer.map_category,
	dbo.DTA_PaySourcePricer.map_type,
	dbo.DTA_PaySourcePricer.TMPWID,
	dbo.DTA_PaySourcePricer.TMPIMCID,
	dbo.DTA_PaySourcePricer.ace_override_id,
	dbo.DTA_PaySourcePricer.closed_fac_sw,
	dbo.DTA_PaySourcePricer.bwgt_option,
	dbo.DTA_PaySourcePricer.disch_drg_option,
	dbo.DTA_PaySourcePricer.hac_version,
	dbo.DTA_PaySourcePricer.CCIRequest_flag,
	dbo.DTA_PaySourcePricer.CCIBypass_flag,
	dbo.DTA_PaySourcePricer.PhysicianEdit_flag,
	dbo.DTA_PaySourcePricer.TRICAREOPPS,
	dbo.DTA_PaySourcePricer.reimbdate,
	dbo.DTA_PaySourcePricer.asc_override_id,
	dbo.DTA_PaySourcePricer.paysrc_notes,
	dbo.DTA_PaySourcePricer.StateCCIValue,
	dbo.DTA_PaySourcePricer.user_key,
    dbo.DTA_PaySourcePricer.pay_except,
	dbo.DTA_PaySource.InExportQueue,
	dbo.DTA_PaySourcePricer.line_bypass,
	dbo.DTA_PaySourcePricer.icd9_routing,
	dbo.DTA_PaySourcePricer.apc_override_id,
	dbo.DTA_PaySourcePricer.vers_qual,
	dbo.DTA_PaySourcePricer.edit_req2,
	dbo.DTA_PaySourcePricer.[analyzer_type],
	dbo.DTA_PaySourcePricer.[analyzer_type_rsvd],
	dbo.DTA_PaySourcePricer.[analyzer_vers],
	dbo.DTA_PaySourcePricer.[analyzer_vers_rsvd],
	dbo.DTA_PaySourcePricer.[start_lvl_option1],
	dbo.DTA_PaySourcePricer.[start_lvl_option2],
	dbo.DTA_PaySourcePricer.[start_lvl_option3],
	dbo.DTA_PaySourcePricer.[start_lvl_option4],
	dbo.DTA_PaySourcePricer.[start_lvl_option5],
	dbo.DTA_PaySourcePricer.[lvl_change_option],
	dbo.DTA_PaySourcePricer.[edc_action],
	dbo.DTA_PaySourcePricer.[facility_type],
	dbo.DTA_PaySourcePricer.[PhysEdit_MaxDME],
	dbo.DTA_PaySourcePricer.[moe_flag],
	dbo.DTA_PaySourcePricer.[mcd_override_id],
	dbo.DTA_PaySourcePricer.[DTAPDID],
	dbo.DTA_PaySourcePricer.othermedicare_flag,
    dbo.DTA_PaySourcePricer.ppc_vers,
    dbo.DTA_paysourcepricer.phys_rule_override_id,
    dbo.DTA_PaySourcePricer.phys_code_override_id
FROM dbo.DTA_PaySource WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer WITH (NOLOCK)
	ON dbo.DTA_PaySource.DTAPDID= dbo.DTA_PaySourcePricer.DTAPDID 
	AND dbo.DTA_PaySource.DTAPSID = dbo.DTA_PaySourcePricer.DTAPSID
GO
PRINT N'Refreshing View [dbo].[DTA_PaySourceKey_VW]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[DTA_PaySourceKey_VW]';


GO
PRINT N'Altering View [dbo].[DTA_PaySourcePricerForAudit_VW]...';


GO

ALTER VIEW [dbo].[DTA_PaySourcePricerForAudit_VW]
AS
SELECT
	dbo.DTA_PaySourcePricer.DTAPSPID,
	dbo.DTA_PaySourcePricer.DTAPSID,
	dbo.DTA_PaySourcePricer.LUTPTID,
	dbo.DTA_PaySourcePricer.LoginSessionGUID,
	dbo.DTA_PaySourcePricer.LoginUser,
	dbo.DTA_PaySourcePricer.Enabled,
	dbo.DTA_PaySourcePricer.DoNotExport,
	dbo.DTA_PaySourcePricer.InsertedTS,
	dbo.DTA_PaySourcePricer.ModifiedTS,
	dbo.DTA_PaySourcePricer.ImportedTS,
	dbo.DTA_PaySourcePricer.ExportedTS,
	dbo.DTA_PaySourcePricer.ExportedUID,
	dbo.DTA_PaySourcePricer.SharedWeightDTAPSPID,
	dbo.DTA_PaySourcePricer.version,
	dbo.DTA_PaySourcePricer.effdate,
	dbo.DTA_PaySourcePricer.tab_filename,
	dbo.DTA_PaySourcePricer.havewt,
	dbo.LUT_RateGrouper.GrouperName AS grpr_type,
	dbo.DTA_PaySourcePricer.grpr_vers,
    dbo.DTA_PaySourcePricer.grpr_date,
	dbo.DTA_PaySourcePricer.pricer_type,
	CASE icd9_map
		WHEN '0' THEN 'No Mapping'
		WHEN '1' THEN 'Standard '
		WHEN '2' THEN 'State-specific'
		ELSE ''
	END AS icd9_map,
	dbo.DTA_PaySourcePricer.edit_date,
	dbo.DTA_PaySourcePricer.dsc_flag,
	dbo.DTA_PaySourcePricer.poa_flag,
	dbo.DTA_PaySourcePricer.hac_flag,
	dbo.DTA_PaySourcePricer.hac_override_id,
	dbo.DTA_PaySourcePricer.oce_flag,
	dbo.DTA_PaySourcePricer.ocewp_flag,
	dbo.DTA_PaySourcePricer.nonoce_flag,
	dbo.DTA_PaySourcePricer.lcd_flag,
	dbo.DTA_PaySourcePricer.map_override_id,
	dbo.DTA_PaySourcePricer.map_category,
	CASE map_type
		WHEN '01' THEN 'ICD-9'
		WHEN '02' THEN 'ICD-10'
		--BEGIN.20170504.US341186.Vadim  Added hard-coded values 
		WHEN '00' THEN 'None'
		WHEN '03' THEN 'Alternate ICD-10'
		--END.20170504.US341186.Vadim  
		ELSE ''
	END AS map_type,
	dbo.DTA_PaySourcePricer.TMPWID,
	dbo.DTA_PaySourcePricer.TMPIMCID,
	dbo.DTA_PaySourcePricer.ace_override_id,
	dbo.DTA_PaySourcePricer.closed_fac_sw,
	dbo.DTA_PaySourcePricer.bwgt_option,
	dbo.DTA_PaySourcePricer.disch_drg_option,
	dbo.DTA_PaySourcePricer.hac_version,
	dbo.DTA_PaySourcePricer.CCIRequest_flag,
	dbo.DTA_PaySourcePricer.CCIBypass_flag,
	dbo.DTA_PaySourcePricer.PhysicianEdit_flag,
	dbo.DTA_PaySourcePricer.reimbdate,
	dbo.DTA_PaySourcePricer.asc_override_id,
	dbo.DTA_PaySourcePricer.TRICAREOPPS,
	dbo.DTA_PaySourcePricer.paysrc_notes,
	dbo.DTA_PaySourcePricer.StateCCIValue,
	dbo.DTA_PaySourcePricer.user_key,
    dbo.DTA_PaySourcePricer.pay_except,
	dbo.DTA_PaySourcePricer.line_bypass,
	dbo.DTA_PaySourcePricer.icd9_routing,
	dbo.DTA_PaySourcePricer.apc_override_id,
	dbo.DTA_PaySourcePricer.vers_qual,
	dbo.DTA_PaySourcePricer.edit_req2,
	CASE [analyzer_type]
		WHEN '00' THEN 'No Analyzer'
		WHEN '01' THEN 'EDC Analyzer'
		WHEN '02' THEN 'E&M Analyzer Pro'
		ELSE ''
	END AS [analyzer_type],
	dbo.DTA_PaySourcePricer.[analyzer_type_rsvd],
	dbo.DTA_PaySourcePricer.[analyzer_vers],
	dbo.DTA_PaySourcePricer.[analyzer_vers_rsvd],
	dbo.DTA_PaySourcePricer.[start_lvl_option1],
	dbo.DTA_PaySourcePricer.[start_lvl_option2],
	dbo.DTA_PaySourcePricer.[start_lvl_option3],
	dbo.DTA_PaySourcePricer.[start_lvl_option4],
	dbo.DTA_PaySourcePricer.[start_lvl_option5],
	dbo.DTA_PaySourcePricer.[lvl_change_option],
	CASE [edc_action]
		WHEN '0' THEN 'Recommend visit level only; ED visit code required'
		WHEN '1' THEN 'Recommend visit level; apply results to reimbursement'
		WHEN '2' THEN 'Recommend visit level if decreased; apply results to reimbursement'
		WHEN '3' THEN 'Recommend visit level only; ED visit code not required'
		ELSE ''
	END AS [edc_action],
	CASE dbo.DTA_PaySourcePricer.[facility_type]
		WHEN '00' THEN 'All Other Hospitals'
		WHEN '01' THEN 'Ambulatory Surgical Center (ASC)'
		ELSE ''
	END AS [facility_type],
	dbo.DTA_PaySourcePricer.PhysEdit_MaxDME,
	dbo.DTA_PaySourcePricer.[moe_flag],
	dbo.DTA_PaySourcePricer.[mcd_override_id],
    dbo.DTA_PaySourcePricer.[cah_oce_flag], -- new column Din
	dbo.DTA_PaySourcePricer.othermedicare_flag,
    dbo.DTA_PaySourcePricer.ppc_vers,
    dbo.DTA_PaySourcePricer.phys_rule_override_id,
    dbo.dta_PaySourcePricer.phys_code_override_id
FROM dbo.DTA_PaySource WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer WITH (NOLOCK)
	ON dbo.DTA_PaySource.DTAPSID = dbo.DTA_PaySourcePricer.DTAPSID
LEFT OUTER JOIN dbo.LUT_RateGrouper WITH (NOLOCK)
	ON dbo.DTA_PaySourcePricer.grpr_type = dbo.LUT_RateGrouper.GrouperValue
	AND dbo.DTA_PaySource.pattype = dbo.LUT_RateGrouper.pattype
GO
PRINT N'Refreshing View [dbo].[PPS_medprc_A_calcuated2_VW]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[PPS_medprc_A_calcuated2_VW]';


GO
PRINT N'Altering View [dbo].[VW_Config_Export]...';


GO

ALTER VIEW [dbo].[VW_Config_Export]
AS
SELECT
	ps.DTAPSID,
    ps.LUTPSCID,
    ps.facility_id,
	ps.payer_id,
	ps.npi,
    ps.taxonomy,
	ps.InExportQueue,
	ps.abbrev_name,
	ps.paysource_name,
	psp.DTAPSPID,
	psp.LUTPTID,
	psp.SharedWeightDTAPSPID,
	psp.DoNotExport,
	psp.tab_filename,
	CASE
		WHEN npi_flag = '0' THEN [facility_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN [npi] + [taxonomy]
		ELSE ''
	END + CASE
		WHEN npi_flag = '0' THEN [payer_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN LEFT([payer_id], 9)
		ELSE ''
	END AS paysource,
    psp.effdate,
    psp.havewt,
	psp.icd9_map,
	psp.dsc_flag,
	psp.poa_flag,
	psp.hac_flag,
	psp.hac_override_id,
	psp.oce_flag,
	psp.ocewp_flag,
	psp.nonoce_flag,
	psp.lcd_flag,
	psp.map_override_id,
	psp.map_category,
	psp.map_type,
	pt.PricerTypeName COLLATE Latin1_General_CS_AS AS PricerTypeName,
	ps.npi_flag,
	ps.pattype,
	psp.grpr_type,
	psp.grpr_vers,
    psp.grpr_date,
	psp.closed_fac_sw,
	UPPER(psp.ace_override_id) AS ace_override_id,
	psp.version,
	psp.bwgt_option,
	psp.disch_drg_option,
	psp.hac_version,
	psp.CCIRequest_flag,
	psp.PhysicianEdit_flag,
	psp.CCIBypass_flag,
	psp.TRICAREOPPS,
	psp.reimbdate,
	UPPER(psp.asc_override_id) AS asc_override_id,
	psp.sqr_flag,
	psp.StateCCIValue,
	psp.user_key,
    psp.pay_except,
	psp.line_bypass,
	psp.icd9_routing,
	UPPER(psp.apc_override_id) AS apc_override_id,
	psp.vers_qual,
	psp.edit_req2,
	psp.[analyzer_type],
	psp.[analyzer_type_rsvd],
	psp.[analyzer_vers],
	psp.[analyzer_vers_rsvd],
	psp.[start_lvl_option1],
	psp.[start_lvl_option2],
	psp.[start_lvl_option3],
	psp.[start_lvl_option4],
	psp.[start_lvl_option5],
	psp.[lvl_change_option],
	psp.[edc_action],
	psp.[facility_type],
	psp.[rf_vers],
	psp.[LUTWTID],
	psp.[PhysEdit_MaxDME],
	psp.[moe_flag],
	psp.[mcd_override_id],
	psp.[cah_oce_flag],
	psp.othermedicare_flag,
    psp.ppc_vers,
    psp.phys_rule_override_id,
    psp.phys_code_override_id,
	psp.[DTAPDID]
FROM dbo.DTA_PaySource AS ps WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer AS psp WITH (NOLOCK)
	ON ps.DTAPDID = psp.DTAPDID
	AND ps.DTAPSID = psp.DTAPSID
INNER JOIN dbo.LUT_PricerType AS pt WITH (NOLOCK)
	ON psp.LUTPTID = pt.LUTPTID
WHERE (ps.Enabled = 1)
AND (psp.Enabled = 1)
GO
PRINT N'Altering View [dbo].[VW_Config_Export_Archive]...';


GO


ALTER VIEW [dbo].[VW_Config_Export_Archive]
AS
SELECT
	ps.DTAPSID,
	psp.DTAPSPID,
	psp.LUTPTID,
	psp.SharedWeightDTAPSPID,
	psp.DoNotExport,
	psp.tab_filename,
	CASE
		WHEN npi_flag = '0' THEN [facility_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN [npi] + [taxonomy]
		ELSE ''
	END + CASE
		WHEN npi_flag = '0' THEN [payer_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN LEFT([payer_id], 9)
		ELSE ''
	END AS paysource,
	psp.effdate,
	psp.icd9_map,
	psp.dsc_flag,
	psp.poa_flag,
	psp.hac_flag,
	psp.hac_override_id,
	psp.oce_flag,
	psp.ocewp_flag,
	psp.nonoce_flag,
	psp.lcd_flag,
	psp.map_override_id,
	psp.map_category,
	psp.map_type,
	pt.PricerTypeName COLLATE Latin1_General_CS_AS AS PricerTypeName,
	ps.npi_flag,
	ps.pattype,
	psp.grpr_type,
	psp.grpr_vers,
	psp.closed_fac_sw,
	UPPER(psp.ace_override_id) AS ace_override_id,
	psp.version,
	psp.bwgt_option,
	psp.disch_drg_option,
	psp.hac_version,
	psp.CCIRequest_flag,
	psp.PhysicianEdit_flag,
	psp.CCIBypass_flag,
	psp.TRICAREOPPS,
	psp.reimbdate,
	UPPER(psp.asc_override_id) AS asc_override_id,
	psp.sqr_flag,
	psp.StateCCIValue,
	psp.user_key,
	psp.line_bypass,
	psp.icd9_routing,
	UPPER(psp.apc_override_id) AS apc_override_id,
	psp.vers_qual,
	psp.edit_req2,
	psp.[analyzer_type],
	psp.[analyzer_type_rsvd],
	psp.[analyzer_vers],
	psp.[analyzer_vers_rsvd],
	psp.[start_lvl_option1],
	psp.[start_lvl_option2],
	psp.[start_lvl_option3],
	psp.[start_lvl_option4],
	psp.[start_lvl_option5],
	psp.[lvl_change_option],
	psp.[edc_action],
	psp.[facility_type],
	psp.[rf_vers],
	psp.[LUTWTID],
	psp.[PhysEdit_MaxDME],
	psp.[moe_flag],
	psp.[mcd_override_id],
	psp.othermedicare_flag,
    psp.ppc_vers,
    psp.phys_rule_override_id,
    psp.phys_code_override_id,
	ps.DTAPDID
FROM dbo.DTA_PaySource AS ps WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer AS psp WITH (NOLOCK)
	ON ps.DTAPDID = psp.DTAPDID  AND ps.DTAPSID = psp.DTAPSID 
INNER JOIN dbo.LUT_PricerType AS pt WITH (NOLOCK)
	ON psp.LUTPTID = pt.LUTPTID
WHERE (ps.Enabled = 1)
AND (psp.Enabled = 1)
GO
PRINT N'Altering View [dbo].[VW_Config_Export_OPTM]...';


GO


ALTER VIEW [dbo].[VW_Config_Export_OPTM]
AS
SELECT
	ps.DTAPSID,
    ps.LUTPSCID,
    ps.facility_id,
	ps.payer_id,
	ps.npi,
	ps.InExportQueue,
	ps.abbrev_name,
	ps.paysource_name,
	psp.DTAPSPID,
	psp.LUTPTID,
	psp.SharedWeightDTAPSPID,
	psp.DoNotExport,
	psp.tab_filename,
	CASE
		WHEN npi_flag = '0' THEN [facility_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN [npi] + [taxonomy]
		ELSE ''
	END + CASE
		WHEN npi_flag = '0' THEN [payer_id]
		ELSE ''
	END + CASE
		WHEN npi_flag = '1' THEN LEFT([payer_id], 9)
		ELSE ''
	END AS paysource,
    psp.effdate,
    psp.havewt,
	psp.icd9_map,
	psp.dsc_flag,
	psp.poa_flag,
	psp.hac_flag,
	psp.hac_override_id,
	psp.oce_flag,
	psp.ocewp_flag,
	psp.nonoce_flag,
	psp.lcd_flag,
	psp.map_override_id,
	psp.map_category,
	psp.map_type,
	pt.PricerTypeName COLLATE Latin1_General_CS_AS AS PricerTypeName,
	ps.npi_flag,
	ps.pattype,
	psp.grpr_type,
	psp.grpr_vers,
	psp.closed_fac_sw,
	psp.ace_override_id,
	psp.version,
	psp.bwgt_option,
	psp.disch_drg_option,
	psp.hac_version,
	psp.CCIRequest_flag,
	psp.PhysicianEdit_flag,
	psp.CCIBypass_flag,
	psp.TRICAREOPPS,
	psp.reimbdate,
	psp.asc_override_id,
	psp.sqr_flag,
	psp.StateCCIValue,
	psp.user_key,
	psp.line_bypass,
	psp.icd9_routing,
	psp.apc_override_id,
	psp.vers_qual,
	psp.edit_req2,
	psp.[analyzer_type],
	psp.[analyzer_type_rsvd],
	psp.[analyzer_vers],
	psp.[analyzer_vers_rsvd],
	psp.[start_lvl_option1],
	psp.[start_lvl_option2],
	psp.[start_lvl_option3],
	psp.[start_lvl_option4],
	psp.[start_lvl_option5],
	psp.[lvl_change_option],
	psp.[edc_action],
	psp.[facility_type],
	psp.[rf_vers],
	psp.[LUTWTID],
	psp.[PhysEdit_MaxDME],
	psp.[moe_flag],
	psp.[mcd_override_id],
	psp.[DTAPDID],
	psp.[edit_date],
	psp.[pricer_type],
    psp.othermedicare_flag,
    psp.ppc_vers,
    psp.[phys_rule_override_id],
    psp.[phys_code_override_id],
	pt.[VersionInCommon],
	ps.[taxonomy]
FROM dbo.DTA_PaySource AS ps WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer AS psp WITH (NOLOCK)
	ON ps.DTAPDID = psp.DTAPDID
	AND ps.DTAPSID = psp.DTAPSID
INNER JOIN dbo.LUT_PricerType AS pt WITH (NOLOCK)
	ON psp.LUTPTID = pt.LUTPTID
WHERE (ps.Enabled = 1)
AND (psp.Enabled = 1)
GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourcePricerSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourcePricerSearch]';


GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourcePricerSingle]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourcePricerSingle]';


GO
PRINT N'Altering View [dbo].[VW_DTA_PaySourceRptSearch]...';


GO

ALTER VIEW [dbo].[VW_DTA_PaySourceRptSearch]
AS
SELECT
	dbo.DTA_PaySource.DTAPSID,
	REPLACE(dbo.DTA_PaySource.facility_id, ',', '') AS facility_id,
	REPLACE(dbo.DTA_PaySource.payer_id, ',', '') AS payer_id,
	REPLACE(dbo.DTA_PaySource.npi, ',', '') AS npi,
	REPLACE(dbo.DTA_PaySource.taxonomy, ',', '') AS taxonomy,
	dbo.DTA_PaySource.paysource_name,
	ISNULL(dbo.DTA_PaySource.InExportQueue, 0) AS InExportQueue,
	dbo.DTA_PaySource.LUTPSCID,
	dbo.LUT_PricerType.LUTPTID AS LUTPTID,
	ISNULL(dbo.LUT_PricerType.PricerTypeName, 'NN')
	AS PricerTypeName,
	ISNULL(dbo.LUT_PricerType.PricerTypeDescr, dbo.udf_GetNonePricerDescr(dbo.DTA_PaySource.pattype, 'NN'))
	AS PricerTypeDescr,
	REPLACE(dbo.DTA_PaySource.abbrev_name, ',', '') AS abbrev_name,
	dbo.LUT_PaySourceClass.ClassName,
	dbo.LUT_RateGrouper.GrouperName,
	dbo.LUT_PaySourceClass.ClassDesc,
	CASE havewt
		WHEN 'Y' THEN 'Loaded'
		WHEN 'L' THEN 'Shared'
		ELSE 'None'
	END AS Rates,
	CASE
		WHEN DoNotExport = 1 THEN 'True'
		ELSE 'False'
	END AS DonotExport,
	ISNULL(psp.DTAPSPID, 0) AS DTAPSPID,
	psp.[version],
	psp.[effdate],
	psp.[tab_filename],
	psp.[havewt],
	psp.[grpr_type],
	psp.[grpr_vers],
    psp.[grpr_date],
	psp.[pricer_type],
	psp.[icd9_map],
	psp.[edit_date],
	psp.[dsc_flag],
	psp.[poa_flag],
	psp.[hac_flag],
	psp.[hac_override_id],
	psp.[oce_flag],
	psp.[ocewp_flag],
	psp.[nonoce_flag],
	psp.[lcd_flag],
	psp.[map_override_id],
	psp.[map_category],
	psp.[map_type],
	psp.[ace_override_id],
	psp.[closed_fac_sw],
	psp.[bwgt_option],
	psp.[disch_drg_option],
	psp.[hac_version],
	psp.[CCIRequest_flag],
	psp.[CCIBypass_flag],
	psp.[PhysicianEdit_flag],
	psp.[reimbdate],
	psp.[TRICAREOPPS],
	psp.[asc_override_id],
	psp.[paysrc_notes],
	psp.[StateCCIValue],
	psp.[user_key],
    psp.[pay_except],
	psp.[line_bypass],
	psp.[icd9_routing],
	psp.[apc_override_id],
	psp.[vers_qual],
	psp.[edit_req2],
	psp.[analyzer_type],
	psp.[analyzer_type_rsvd],
	psp.[analyzer_vers],
	psp.[analyzer_vers_rsvd],
	psp.[start_lvl_option1],
	psp.[start_lvl_option2],
	psp.[start_lvl_option3],
	psp.[start_lvl_option4],
	psp.[start_lvl_option5],
	psp.[lvl_change_option],
	psp.[edc_action],
	psp.[facility_type],
	psp.[PhysEdit_MaxDME],
	psp.[moe_flag],
	psp.[mcd_override_id],
	dbo.DTA_PaySource.DTAPDID,
	psp.[cah_oce_flag],
	psp.[othermedicare_flag],
    psp.[ppc_vers],
    psp.[rf_vers],
    psp.[phys_rule_override_id],
    psp.[phys_code_override_id],
	psp.[ModifiedTS],
	psp.[InsertedTS],
	psp.[LoginUser],
    dbo.LUT_RateGrouper.[GrouperVersionFormat],
    dbo.LUT_PricerType.IsEditAll,
    dbo.LUT_RateGrouper.LUTRGID
FROM dbo.DTA_PaySource WITH (NOLOCK)
INNER JOIN dbo.DTA_PaySourcePricer AS psp WITH (NOLOCK) 
    ON psp.DTAPSID = dbo.DTA_PaySource.DTAPSID  
INNER JOIN dbo.LUT_PricerType WITH (NOLOCK)   
    ON psp.LUTPTID = dbo.LUT_PricerType.LUTPTID  
LEFT OUTER JOIN dbo.LUT_RateGrouper WITH (NOLOCK)
	ON dbo.LUT_RateGrouper.GrouperValue = psp.grpr_type
	AND dbo.LUT_RateGrouper.pattype = dbo.DTA_PaySource.pattype
LEFT OUTER JOIN dbo.LUT_PaySourceClass WITH (NOLOCK)
	ON dbo.DTA_PaySource.LUTPSCID = dbo.LUT_PaySourceClass.LUTPSCID
GO
PRINT N'Altering View [dbo].[VW_DTA_PaySourceSearch_MaxEff]...';


GO

ALTER VIEW [dbo].[VW_DTA_PaySourceSearch_MaxEff]
AS
SELECT 
	dbo.DTA_PaySource.DTAPSID,
	dbo.DTA_PaySource.facility_id,
	dbo.DTA_PaySource.payer_id,
	dbo.DTA_PaySource.npi,
	dbo.DTA_PaySource.taxonomy,
	dbo.DTA_PaySource.paysource_name,
	dbo.DTA_PaySource.abbrev_name,
	dbo.DTA_PaySource.pattype,
	dbo.LUT_PricerType.LUTPTID,
	dbo.LUT_PricerType.PricerTypeName,
	dbo.LUT_PricerType.PricerTypeDescr,
	InExportQueue,
	psp.[DTAPSPID],
	psp.[DoNotExport],
	psp.[version],
	psp.[effdate],
	psp.[tab_filename],
	psp.[havewt],
	psp.[grpr_type],
	psp.[grpr_vers],
	psp.[pricer_type],
	psp.[icd9_map],
	psp.[edit_date],
	psp.[dsc_flag],
	psp.[poa_flag],
	psp.[hac_flag],
	psp.[hac_override_id],
	psp.[oce_flag],
	psp.[ocewp_flag],
	psp.[nonoce_flag],
	psp.[lcd_flag],
	psp.[map_override_id],
	psp.[map_category],
	psp.[map_type],
	psp.[ace_override_id],
	psp.[closed_fac_sw],
	psp.[bwgt_option],
	psp.[disch_drg_option],
	psp.[ppc_vers],
	psp.[hac_version],
	psp.[CCIRequest_flag],
	psp.[CCIBypass_flag],
	psp.[PhysicianEdit_flag],
	psp.[reimbdate],
	psp.[TRICAREOPPS],
	psp.[asc_override_id],
	psp.[paysrc_notes],
	psp.[StateCCIValue],
	psp.[user_key],
	psp.[line_bypass],
	psp.[icd9_routing],
	psp.[phys_rule_override_id],
	psp.[phys_code_override_id],
	dbo.DTA_PaySource.[DTAPDID]
FROM dbo.DTA_PaySource WITH (NOLOCK)
LEFT OUTER JOIN (SELECT
	DTAPSID,ISNULL(pd.DTAPDID,0) DTAPDID,
	MAX(effdate) AS effdate
FROM dbo.DTA_PaySourcePricer psp WITH (NOLOCK)
LEFT JOIN DTA_ProductionDate pd WITH (NOLOCK) 
ON psp.DTAPDID  = pd.DTAPDID  OR psp.DTAPDID  = 0
GROUP BY DTAPSID,pd.DTAPDID) AS xpsp
	ON xpsp.DTAPSID = dbo.DTA_PaySource.DTAPSID
	AND dbo.DTA_PaySource.DTAPDID = xpsp.DTAPDID
LEFT OUTER JOIN dbo.DTA_PaySourcePricer psp
	ON dbo.DTA_PaySource.DTAPSID = psp.DTAPSID
	AND xpsp.effdate = psp.effdate
	AND psp.DTAPDID  = xpsp.DTAPDID
LEFT OUTER JOIN dbo.LUT_PricerType WITH (NOLOCK)
	ON dbo.LUT_PricerType.LUTPTID = psp.LUTPTID
GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourceSearch_PricerType]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourceSearch_PricerType]';


GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourceSearchResult]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourceSearchResult]';


GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourceSharedWeightSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourceSharedWeightSearch]';


GO
PRINT N'Refreshing View [dbo].[VW_DTA_WeightListEditor]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_WeightListEditor]';


GO
PRINT N'Refreshing View [dbo].[VW_DTA_WeightListEditor_APC]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_WeightListEditor_APC]';


GO
PRINT N'Refreshing View [dbo].[VW_PaySourcePricer_Export]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_PaySourcePricer_Export]';


GO
PRINT N'Altering View [dbo].[VW_DTA_PaySourceSearch_SinglePricerType]...';


GO

ALTER VIEW [dbo].[VW_DTA_PaySourceSearch_SinglePricerType]
AS
SELECT
	ps.DTAPSID,
	ps.facility_id,
	ps.payer_id,
	ps.npi,
	ps.taxonomy,
	ps.paysource_name,
	ps.abbrev_name,
	dbo.LUT_PricerType.LUTPTID,
	dbo.LUT_PricerType.PricerTypeName,
	dbo.LUT_PricerType.PricerTypeDescr,
	ps.InExportQueue,
	ps.LUTPSCID,
	ps.pattype,	
	psp.[DTAPSPID],
	psp.[DoNotExport],
	psp.[version],
	psp.[effdate],
	psp.[tab_filename],
	psp.[havewt],
	psp.[grpr_type],
	psp.[grpr_vers],
	psp.[grpr_date],
	psp.[pricer_type],
	psp.[icd9_map],
	psp.[edit_date],
	psp.[dsc_flag],
	psp.[poa_flag],
	psp.[hac_flag],
	psp.[hac_override_id],
	psp.[oce_flag],
	psp.[ocewp_flag],
	psp.[nonoce_flag],
	psp.[lcd_flag],
	psp.[map_override_id],
	psp.[map_category],
	psp.[map_type],
	psp.[ace_override_id],
	psp.[closed_fac_sw],
	psp.[bwgt_option],
	psp.[disch_drg_option],
	psp.[hac_version],
	psp.[CCIRequest_flag],
	psp.[CCIBypass_flag],
	psp.[PhysicianEdit_flag],
	psp.[reimbdate],
	psp.[TRICAREOPPS],
	psp.[asc_override_id],
	psp.[paysrc_notes],
	psp.[StateCCIValue],
	psp.[user_key],
	psp.[pay_except],
	psp.[line_bypass],
	psp.[icd9_routing],
	psp.[apc_override_id],
	psp.[vers_qual],
	psp.[edit_req2],
	psp.[analyzer_type],
	psp.[analyzer_type_rsvd],
	psp.[analyzer_vers],
	psp.[analyzer_vers_rsvd],
	psp.[start_lvl_option1],
	psp.[start_lvl_option2],
	psp.[start_lvl_option3],
	psp.[start_lvl_option4],
	psp.[start_lvl_option5],
	psp.[lvl_change_option],
	psp.[edc_action],
	psp.[facility_type],
	psp.[PhysEdit_MaxDME],
	psp.[moe_flag],
	psp.[mcd_override_id],
	psp.[othermedicare_flag],
	psp.[ppc_vers],
	psp.[phys_rule_override_id],
	psp.[phys_code_override_id],
	psp.DTAPDID [DTAPDID]
FROM dbo.DTA_PaySource ps WITH (NOLOCK)
LEFT OUTER JOIN dbo.DTA_PaySourceAll_VW AS psp WITH (NOLOCK)
	ON psp.DTAPSID = ps.DTAPSID AND psp.DTAPDID = ps.DTAPDID
LEFT OUTER JOIN dbo.LUT_PricerType WITH (NOLOCK)
	ON dbo.LUT_PricerType.LUTPTID = psp.LUTPTID
GO
PRINT N'Refreshing View [dbo].[VW_DTA_PaySourceSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[VW_DTA_PaySourceSearch]';


GO
PRINT N'Refreshing Function [dbo].[udf_DTA_PaySourcePricerSingle]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[udf_DTA_PaySourcePricerSingle]';


GO
PRINT N'Refreshing Function [dbo].[udf_DTA_PaySourceSearch_Internal]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[udf_DTA_PaySourceSearch_Internal]';


GO
PRINT N'Altering Function [dbo].[udf_DTA_PaySourceSearch_MaxEff]...';


GO
GO
PRINT N'Altering Function [dbo].[udf_Export_Search]...';


GO
-- ==========================================================================================  
-- Author:   Amy Zhao  
-- Create date: 8/8/2014  
-- Modified By: Raghu Malladi  
-- Modified Date: 01/08/2021  
-- Modified By: Raghu Malladi  
-- Modified Date: 05/24/2021  
-- Modification: as per US769608 Changes to add cah_oce_flag column.  
-- Description: The function is for the search of export. This function will be called   
-- from export SP: SP_Export_config, SP_Export_medxxx, SP_Export_ratexxx and SP_Export_payxxx.  
-- 20230323.US1023967.Krishnam Payer Exceptions to be exported in 305-306  
-- ==========================================================================================  
/*******************************************************************************  
SELECT * from udf_Export_Search('','','','',13,0,'','2030-01-01')  
SELECT * from udf_Export_Search('','','','',36,1,'2000-01-01','2030-01-01')  
********************************************************************************/  
ALTER FUNCTION [dbo].[udf_Export_Search] (@FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(10), @PayerID varchar(13), @PayerName varchar(50), @PricerTypeID int, @InExportQueue bit, @FromDate datetime = NULL, @ToDate datetime = NULL)  
RETURNS TABLE  
AS  
  RETURN  
  (  
  WITH CTE_paysourceExport  
  AS (SELECT  
    vw.DTAPSID,  
    vw.[DTAPSPID],  
    vw.LUTPTID,  
    vw.[SharedWeightDTAPSPID],  
    vw.[DoNotExport],  
    vw.[tab_filename],  
    vw.paysource,  
    vw.[effdate],  
    vw.[icd9_map],  
    vw.[dsc_flag],  
    vw.[poa_flag],  
    vw.[hac_flag],  
    vw.[hac_override_id],  
    vw.[oce_flag],  
    vw.[ocewp_flag],  
    vw.[nonoce_flag],  
    vw.[lcd_flag],  
    vw.[map_override_id],  
    vw.[map_category],  
    vw.[map_type],  
    vw.[PricerTypeName],  
    vw.[npi_flag],  
    vw.pattype,  
    vw.[grpr_type],  
    vw.[grpr_vers],  
    vw.[grpr_date],  
    vw.[closed_fac_sw],  
    vw.[ace_override_id],  
    vw.[version],  
    vw.[bwgt_option],  
    vw.[disch_drg_option],  
    vw.[hac_version],  
    vw.[CCIRequest_flag],  
    vw.[PhysicianEdit_flag],  
    vw.[CCIBypass_flag],  
    vw.[TRICAREOPPS],  
    vw.[reimbdate],  
    vw.[asc_override_id],  
    vw.[sqr_flag],  
    vw.[StateCCIValue],  
    vw.[user_key],  
    vw.[pay_except],  
    vw.[line_bypass],  
    vw.[icd9_routing],  
    vw.[apc_override_id],  
    vw.[vers_qual],  
    vw.[edit_req2],  
    vw.[analyzer_type],  
    vw.[analyzer_type_rsvd],  
    vw.[analyzer_vers],  
    vw.[analyzer_vers_rsvd],  
    vw.[start_lvl_option1],  
    vw.[start_lvl_option2],  
    vw.[start_lvl_option3],  
    vw.[start_lvl_option4],  
    vw.[start_lvl_option5],  
    vw.[lvl_change_option],  
    vw.[edc_action],  
    vw.[facility_type],  
    vw.[rf_vers],  
    vw.[PhysEdit_MaxDME],  
    vw.[moe_flag],  
    vw.[mcd_override_id],  
	vw.[cah_oce_flag],
	vw.[othermedicare_flag],
    vw.[ppc_vers],
	vw.[phys_rule_override_id],
	vw.[phys_code_override_id]
  FROM dbo.VW_Config_Export AS vw WITH (NOLOCK)  
  WHERE vw.facility_id LIKE '%' + @FacilityID + '%'  
  AND ISNULL(vw.payer_id, '') LIKE '%' + @PayerID + '%'  
  AND vw.npi LIKE '%' + @NPI + '%'  
  AND vw.taxonomy LIKE '%' + @Taxonomy + '%'  
  AND ISNULL(vw.paysource_name, '') LIKE '%' + @PayerName + '%'  
  AND ISNULL(vw.InExportQueue, 0) =  
                                   CASE  
                                     WHEN @InExportQueue = 1 THEN @InExportQueue  
                                     ELSE ISNULL(vw.InExportQueue, 0)  
                                   END  
  AND vw.LUTPTID =  
                  CASE  
                    WHEN @PricerTypeID > 0 THEN @PricerTypeID  
                    ELSE vw.LUTPTID  
                  END  
  AND ISNULL(vw.DoNotExport, 0) = 0  
  AND vw.effdate BETWEEN @FromDate AND @ToDate),  
  CTE_sharedWeight  
  AS (SELECT DISTINCT  
    SharedWeightDTAPSPID  
  FROM CTE_paysourceExport  
  WHERE SharedWeightDTAPSPID IS NOT NULL),  
  CTE_sharedPaysourceExport  
  AS (SELECT  
    vw.DTAPSID,  
    vw.[DTAPSPID],  
    vw.LUTPTID,  
    vw.[SharedWeightDTAPSPID],  
    --US6462227.Naga 20200605 start, Parents paysource DoNotExport field to be ignored   
 0 [DoNotExport],  
    --US6462227.Naga 20200605 end  
    vw.[tab_filename],  
    vw.paysource,  
    vw.[effdate],  
    vw.[icd9_map],  
    vw.[dsc_flag],  
    vw.[poa_flag],  
    vw.[hac_flag],  
    vw.[hac_override_id],  
    vw.[oce_flag],  
    vw.[ocewp_flag],  
    vw.[nonoce_flag],  
    vw.[lcd_flag],  
    vw.[map_override_id],  
    vw.[map_category],  
    vw.[map_type],  
    vw.[PricerTypeName],  
    vw.[npi_flag],  
    vw.pattype,  
    vw.[grpr_type],  
    vw.[grpr_vers],  
    vw.[grpr_date],  
    vw.[closed_fac_sw],  
    vw.[ace_override_id],  
    vw.[version],  
    vw.[bwgt_option],  
    vw.[disch_drg_option],  
    vw.[hac_version],  
    vw.[CCIRequest_flag],  
    vw.[PhysicianEdit_flag],  
    vw.[CCIBypass_flag],  
    vw.[TRICAREOPPS],  
    vw.[reimbdate],  
    vw.[asc_override_id],  
    vw.[sqr_flag],  
    vw.[StateCCIValue],  
    vw.[user_key],  
    vw.[pay_except],  
    vw.[line_bypass],  
    vw.[icd9_routing],  
    vw.[apc_override_id],  
    vw.[vers_qual],
    vw.[edit_req2],  
    vw.[analyzer_type],  
    vw.[analyzer_type_rsvd],  
    vw.[analyzer_vers],  
    vw.[analyzer_vers_rsvd],  
    vw.[start_lvl_option1],  
    vw.[start_lvl_option2],  
    vw.[start_lvl_option3],  
    vw.[start_lvl_option4],  
    vw.[start_lvl_option5],  
    vw.[lvl_change_option],  
    vw.[edc_action],  
    vw.[facility_type],  
    vw.[rf_vers],  
    vw.[PhysEdit_MaxDME],  
    vw.[moe_flag],  
    vw.[mcd_override_id],  
	vw.[cah_oce_flag],
	vw.[othermedicare_flag],
    vw.[ppc_vers],
	vw.[phys_rule_override_id],
	vw.[phys_code_override_id]
  FROM VW_Config_Export vw WITH (NOLOCK)  
  INNER JOIN CTE_sharedWeight tw  
    ON vw.DTAPSPID = tw.SharedWeightDTAPSPID  
  WHERE ISNULL(vw.havewt, '') = 'Y')  
  SELECT  
    *  
  FROM CTE_paysourceExport  
  UNION  
  SELECT  
    *  
  FROM CTE_sharedPaysourceExport  
  )
GO
PRINT N'Altering Function [dbo].[udf_Export_Search_Archive]...';


GO
-- ==========================================================================================  
-- Author:     Amy Zhao  
-- Create date: 8/8/2014  
-- Modified By: Raghu Malladi  
-- Modified Date: 01/08/2021  
-- Description: The function is for the search of export. This function will be called from SP_Archive_FromDB  
-- 20200430.Vadim Copied from udf_Export_Search - DoNotExport flag is removed as we need to archive all data regardless  
-- ==========================================================================================  
/*******************************************************************************  
SELECT * from [udf_Export_Search_Archive]('','','','','',13,0)  
SELECT * from [udf_Export_Search_Archive]('','','','','',36,1)  
********************************************************************************/  
ALTER FUNCTION [dbo].[udf_Export_Search_Archive] (@FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(10), @PayerID varchar(13), @PayerName varchar(50), @PricerTypeID int, @InExportQueue bit)  
RETURNS TABLE  
AS  
  RETURN  
  (  
  WITH CTE_paysourceExport  
  AS (SELECT  
    vw.DTAPSID,  
    vw.[DTAPSPID],  
    vw.LUTPTID,  
    vw.[SharedWeightDTAPSPID],  
    vw.[DoNotExport],  
    vw.[tab_filename],  
    vw.paysource,  
    vw.[effdate],  
    vw.[icd9_map],  
    vw.[dsc_flag],  
    vw.[poa_flag],  
    vw.[hac_flag],  
    vw.[hac_override_id],  
    vw.[oce_flag],  
    vw.[ocewp_flag],  
    vw.[nonoce_flag],  
    vw.[lcd_flag],  
    vw.[map_override_id],  
    vw.[map_category],  
    vw.[map_type],  
    vw.[PricerTypeName],  
    vw.[npi_flag],  
    vw.pattype,  
    vw.[grpr_type],  
    vw.[grpr_vers],  
    vw.[closed_fac_sw],  
    vw.[ace_override_id],  
    vw.[version],  
    vw.[bwgt_option],  
    vw.[disch_drg_option],  
    vw.[hac_version],  
    vw.[CCIRequest_flag],  
    vw.[PhysicianEdit_flag],  
    vw.[CCIBypass_flag],  
    vw.[TRICAREOPPS],  
    vw.[reimbdate],  
    vw.[asc_override_id],  
    vw.[sqr_flag],  
    vw.[StateCCIValue],  
    vw.[user_key],  
    vw.[line_bypass],  
    vw.[icd9_routing],  
    vw.[apc_override_id],  
    vw.[vers_qual],  
    vw.[edit_req2],  
    vw.[analyzer_type],  
    vw.[analyzer_type_rsvd],  
    vw.[analyzer_vers],  
    vw.[analyzer_vers_rsvd],  
    vw.[start_lvl_option1],  
    vw.[start_lvl_option2],  
    vw.[start_lvl_option3],  
    vw.[start_lvl_option4],  
    vw.[start_lvl_option5],  
    vw.[lvl_change_option],  
    vw.[edc_action],  
    vw.[facility_type],  
    vw.[rf_vers],  
    vw.[PhysEdit_MaxDME],  
    vw.[moe_flag],  
    vw.[mcd_override_id],
	vw.[othermedicare_flag],
    vw.[ppc_vers],
    vw.[phys_rule_override_id],
	vw.[phys_code_override_id]
  FROM dbo.VW_Config_Export AS vw WITH (NOLOCK)  
  WHERE vw.facility_id LIKE '%' + @FacilityID + '%'  
  AND ISNULL(vw.payer_id, '') LIKE '%' + @PayerID + '%'  
  AND vw.npi LIKE '%' + @NPI + '%'  
  AND vw.taxonomy LIKE '%' + @Taxonomy + '%'  
  AND ISNULL(vw.paysource_name, '') LIKE '%' + @PayerName + '%'  
  AND ISNULL(vw.InExportQueue, 0) =  
                                   CASE  
                                     WHEN @InExportQueue = 1 THEN @InExportQueue  
                                     ELSE ISNULL(vw.InExportQueue, 0)  
                                   END  
  AND vw.LUTPTID =  
                  CASE  
                    WHEN @PricerTypeID > 0 THEN @PricerTypeID  
                    ELSE vw.LUTPTID  
                  END),  
  CTE_sharedWeight  
  AS (SELECT DISTINCT  
    SharedWeightDTAPSPID  
  FROM CTE_paysourceExport  
  WHERE SharedWeightDTAPSPID IS NOT NULL),  
  CTE_sharedPaysourceExport  
  AS (SELECT  
    vw.DTAPSID,  
    vw.[DTAPSPID],  
    vw.LUTPTID,  
    vw.[SharedWeightDTAPSPID],  
    --US6462227.Naga 20200605 start, Parents paysource DoNotExport field to be ignored   
    0 [DoNotExport],  
    --US6462227.Naga 20200605 end  
    vw.[tab_filename],  
    vw.paysource,  
    vw.[effdate],  
    vw.[icd9_map],  
    vw.[dsc_flag],  
    vw.[poa_flag],  
    vw.[hac_flag],  
    vw.[hac_override_id],  
    vw.[oce_flag],  
    vw.[ocewp_flag],  
    vw.[nonoce_flag],  
    vw.[lcd_flag],  
    vw.[map_override_id],  
    vw.[map_category],  
    vw.[map_type],  
    vw.[PricerTypeName],  
    vw.[npi_flag],  
    vw.pattype,  
    vw.[grpr_type],  
    vw.[grpr_vers],  
    vw.[closed_fac_sw],  
    vw.[ace_override_id],  
    vw.[version],  
    vw.[bwgt_option],  
    vw.[disch_drg_option],  
    vw.[hac_version],  
    vw.[CCIRequest_flag],  
    vw.[PhysicianEdit_flag],  
    vw.[CCIBypass_flag],  
    vw.[TRICAREOPPS],  
    vw.[reimbdate],  
    vw.[asc_override_id],  
    vw.[sqr_flag],  
    vw.[StateCCIValue],  
    vw.[user_key],  
    vw.[line_bypass],  
    vw.[icd9_routing],  
    vw.[apc_override_id],  
    vw.[vers_qual],
    vw.[edit_req2],  
    vw.[analyzer_type],  
    vw.[analyzer_type_rsvd],  
    vw.[analyzer_vers],  
    vw.[analyzer_vers_rsvd],  
    vw.[start_lvl_option1],  
    vw.[start_lvl_option2],  
    vw.[start_lvl_option3],  
    vw.[start_lvl_option4],  
    vw.[start_lvl_option5],  
    vw.[lvl_change_option],  
    vw.[edc_action],  
    vw.[facility_type],  
    vw.[rf_vers],  
    vw.[PhysEdit_MaxDME],  
    vw.[moe_flag],  
    vw.[mcd_override_id],
	vw.[othermedicare_flag],
    vw.[ppc_vers],
    vw.[phys_rule_override_id],
	vw.[phys_code_override_id]
  FROM VW_Config_Export vw WITH (NOLOCK)  
  INNER JOIN CTE_sharedWeight tw  
    ON vw.DTAPSPID = tw.SharedWeightDTAPSPID  
  WHERE ISNULL(vw.havewt, '') = 'Y')  
  SELECT  
    *  
  FROM CTE_paysourceExport  
  UNION  
  SELECT  
    *  
  FROM CTE_sharedPaysourceExport  
  )
GO

PRINT N'Refreshing Procedure [dbo].[SP_Export_medext]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_medext]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_medxxx]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_medxxx]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_rateny]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_rateny]';

GO
-- ==========================================================================================    
-- Author:  Amy Zhao    
-- Create date: 8/8/2014    
-- Description: The function is for the search of export. This function will be called     
-- from export SP: SP_Export_config, SP_Export_medxxx, SP_Export_ratexxx and SP_Export_payxxx    
-- ==========================================================================================    
/*******************************************************************************    
SELECT  top 100 * from udf_DTA_PaySourceSearch_MaxEff(65, 1) Where payer_id='09' order by payer_id    
SELECT top 1000 * from udf_DTA_PaySourceSearch_MaxEff(0, 3) Where payer_id='09'    
********************************************************************************/    
ALTER FUNCTION [dbo].[udf_DTA_PaySourceSearch_MaxEff] (@LUTPTID int = 0, @DTAPDID int = 0)    
RETURNS TABLE    
AS    
 RETURN    
 (    
  SELECT     
   ps.DTAPSID,    
   ps.facility_id,    
   ps.payer_id,    
   ps.npi,    
   ps.taxonomy,    
   ps.paysource_name,    
   ps.abbrev_name,    
   pt.LUTPTID,    
   pt.PricerTypeName,    
   pt.PricerTypeDescr,    
   ps.InExportQueue,    
   ps.LUTPSCID,    
   ps.pattype,     
   psp.[DTAPSPID],    
   psp.[DoNotExport],    
   psp.[version],    
   psp.[effdate],    
   psp.[tab_filename],    
   psp.[havewt],    
   psp.[grpr_type],    
   psp.[grpr_vers],    
   psp.[grpr_date],    
   psp.[pricer_type],    
   psp.[icd9_map],    
   psp.[edit_date],    
   psp.[dsc_flag],    
   psp.[poa_flag],    
   psp.[hac_flag],    
   psp.[hac_override_id],    
   psp.[oce_flag],    
   psp.[ocewp_flag],    
   psp.[nonoce_flag],    
   psp.[lcd_flag],    
   psp.[map_override_id],    
   psp.[map_category],    
   psp.[map_type],    
   psp.[ace_override_id],    
   psp.[closed_fac_sw],    
   psp.[bwgt_option],    
   psp.[disch_drg_option],    
   psp.[hac_version],    
   psp.[CCIRequest_flag],    
   psp.[CCIBypass_flag],    
   psp.[PhysicianEdit_flag],    
   psp.[reimbdate],    
   psp.[TRICAREOPPS],    
   psp.[asc_override_id],    
   psp.[paysrc_notes],    
   psp.[StateCCIValue],    
   psp.[user_key],    
   psp.[pay_except],    
   psp.[line_bypass],    
   psp.[icd9_routing],    
   psp.[apc_override_id],    
   psp.[vers_qual],  
   psp.[edit_req2],      
   psp.[analyzer_type],    
   psp.[analyzer_type_rsvd],    
   psp.[analyzer_vers],    
   psp.[analyzer_vers_rsvd],    
   psp.[start_lvl_option1],    
   psp.[start_lvl_option2],    
   psp.[start_lvl_option3],    
   psp.[start_lvl_option4],    
   psp.[start_lvl_option5],    
   psp.[lvl_change_option],    
   psp.[edc_action],    
   psp.[facility_type],    
   psp.[PhysEdit_MaxDME],    
   psp.[moe_flag],    
   psp.[mcd_override_id],    
   ps.DTAPDID,    
   psp.cah_oce_flag,
   psp.[othermedicare_flag],
   psp.[ppc_vers],
   psp.[Phys_Rule_Override_Id],
   psp.[Phys_Code_Override_Id]
  FROM dbo.DTA_PaySource ps WITH (NOLOCK)    
  INNER JOIN (SELECT    
   DTAPDID, --20200521.DE196297.Naga Unique key always with DTAPDID    
   DTAPSID,    
   MAX(effdate) AS effdate     
  FROM dbo.DTA_PaySourcePricer psp WITH (NOLOCK)    
  WHERE DTAPDID = @DTAPDID AND (LUTPTID = @LUTPTID OR @LUTPTID < 1)    
  GROUP BY     
  DTAPDID, --20200521.DE196297.Naga Unique key always with DTAPDID    
  DTAPSID) AS xpsp    
  ON xpsp.DTAPSID = ps.DTAPSID    
 LEFT OUTER JOIN dbo.DTA_PaySourcePricer psp WITH (NOLOCK)    
  ON ps.DTAPSID = psp.DTAPSID    
  AND xpsp.effdate = psp.effdate    
  --AND psp.DTAPDID  = @DTAPDID     
  AND xpsp.DTAPDID = psp.DTAPDID --20200521.DE196297.Naga Unique key always with DTAPDID    
 LEFT OUTER JOIN dbo.LUT_PricerType pt WITH (NOLOCK)    
  ON pt.LUTPTID = psp.LUTPTID    
 WHERE    
  ps.DTAPDID = @DTAPDID    
)
GO
PRINT N'Refreshing Function [dbo].[udf_PaySourceSearch_ALL]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[udf_PaySourceSearch_ALL]';


GO
PRINT N'Refreshing Function [dbo].[udf_Export_Search]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[udf_Export_Search]';


GO
PRINT N'Refreshing Function [dbo].[udf_Export_Search_Archive]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[udf_Export_Search_Archive]';


GO
PRINT N'Altering Function [dbo].[udf_XMLToTableDTA_PaySourcePricer]...';


GO
-- ============================================================================    
-- Author:     Amy Zhao    
-- Modified by    
-- Create date: 09/21/2011    
-- Description:     
-- This functio is to convert xml format PaySourcePricer to table DTA_PaySourcePricer    
-- 20230127.US1007322. Vadim  closed_fac_sw: bit to char(1)    
-- 20230323. US1023967: Krishnam Added pay_except field.    
-- =============================================================================    
    
/*******************************************************************************    
DECLARE @XmlStr VARCHAR(MAX), @iDoc AS INT    
SET @XmlStr =     
'    
 <PaySource>    
  <facility_id>010001          </facility_id>    
  <npi></npi>    
  <taxonomy></taxonomy>    
  <payer_id>09           </payer_id>    
  <paysource_name>PaySourceTest1</paysource_name>    
  <abbrev_name>PT1</abbrev_name>    
  <LUTPSCID>1</LUTPSCID>    
  <DTAPSID>363</DTAPSID>    
  <LoginSessionGUID>00000000-0000-0000-0000-000000000000</LoginSessionGUID>    
  <ADMUID>0</ADMUID>    
  <PaySourcePricers>    
   <PaySourcePricer>    
    <DoNotExport>false</DoNotExport>    
    <DTAPSID>363</DTAPSID>    
    <DTAPSPID>46</DTAPSPID>    
    <effdate>10/1/2010</effdate>    
    <LUTPTID>36</LUTPTID>    
    <totalcount>0</totalcount>    
    <poa_flag>true</poa_flag>    
     <dsc_flag>false</dsc_flag>    
    <SharedWeightPSPID>0</SharedWeightPSPID>    
    <ExportedByUserID>0</ExportedByUserID>    
    <ModifedByUserID>0</ModifedByUserID>    
    <LoginSessionGUID>00000000-0000-0000-0000-000000000000</LoginSessionGUID>    
    <ADMUID>0</ADMUID>    
<bwgt_option>7</bwgt_option>    
<disch_drg_option>1</disch_drg_option>    
<hac_version>230</hac_version>    
   </PaySourcePricer>    
  </PaySourcePricers>    
 </PaySource>    
'    
    
SET @iDoc = NULL    
    
-- parse the XML data to tables    
EXEC sp_xml_preparedocument @iDoc OUTPUT, @XmlStr    
    
IF object_id('tempdb..#DTA_PaySourcePricer') IS NOT NULL    
BEGIN    
   DROP TABLE #DTA_PaySourcePricer    
END    
SELECT * INTO #DTA_PaySourcePricer FROM dbo.udf_XMLToTableDTA_PaySourcePricer(@iDoc)    
    
SELECT * FROM #DTA_PaySourcePricer    
    
DROP TABLE #DTA_PaySourcePricer    
    
-- clean xml obj    
EXEC sp_xml_removedocument @iDoc    
SET @iDoc = NULL     
    
********************************************************************************/    
ALTER FUNCTION [dbo].[udf_XMLToTableDTA_PaySourcePricer] (@xmlDocParserID AS int)    
RETURNS @DTA_PaySourcePricer TABLE (    
 [DTAPSPID] [bigint],    
 [DTAPSID] [bigint],    
 [LUTPTID] [int],    
 [LoginSessionGUID] [uniqueidentifier],    
 [DoNotExport] [bit],    
 [ExportedUID] [int],    
 [SharedWeightDTAPSPID] [bigint],    
 [version] [varchar](50),    
 [effdate] [datetime],    
 [tab_filename] [varchar](9),    
 [grpr_type] [varchar](5),    
 [grpr_vers] [varchar](3),    
 [grpr_date] [varchar](1),    
 [pricer_type] [varchar](2),    
 [icd9_map] [char](1),    
 [edit_date] [bit],    
 [dsc_flag] [bit],    
 [poa_flag] [bit],    
 [hac_flag] [bit],    
 [hac_override_id] [varchar](10),    
 [oce_flag] [bit],    
 [ocewp_flag] [bit],    
 [nonoce_flag] [bit],    
 [lcd_flag] [bit],    
 [map_override_id] varchar(20),    
 [map_category] char(2),    
 [map_type] char(2),    
 [closed_fac_sw] char(1),    
 [ace_override_id] varchar(20),    
 [bwgt_option] varchar(1),    
 [disch_drg_option] varchar(1),    
 [hac_version] varchar(4)--includes the xml in the value    
 ,    
 [CCIRequest_flag] bit,    
 [CCIBypass_flag] bit,    
 [PhysicianEdit_flag] bit,    
 [TRICAREOPPS] bit,    
 [reimbdate] varchar(1),    
 [asc_override_id] varchar(20),    
 [apc_override_id] varchar(20),    
 [paysrc_notes] varchar(100),    
 [StateCCIValue] varchar(2),    
 [user_key] varchar(3),    
 [pay_except] char(2),    
 [line_bypass] char(1),    
 [icd9_routing] bit,    
 [vers_qual] char(1),   
 [edit_req2] bit, 
 [analyzer_type] varchar(2),    
 [analyzer_type_rsvd] varchar(2),    
 [analyzer_vers] varchar(2),    
 [analyzer_vers_rsvd] varchar(4),    
 [start_lvl_option1] bit,    
 [start_lvl_option2] bit,    
 [start_lvl_option3] bit,    
 [start_lvl_option4] bit,    
 [start_lvl_option5] bit,    
 [lvl_change_option] varchar(1),    
 [edc_action] varchar(1),    
 [facility_type] varchar(2),    
 [LUTWTID] int,    
 [PhysEdit_MaxDME] bit,    
 [moe_flag] bit,    
    [mcd_override_id] varchar (20),    
 [cah_oce_flag] [bit], -- new column Din 
 [othermedicare_flag] bit,
 [ppc_vers] varchar(3),
 [phys_rule_override_id] varchar(20),
 [phys_code_override_id] varchar(20)
)    
AS    
BEGIN    
 INSERT INTO @DTA_PaySourcePricer    
  SELECT    
   *    
  FROM OPENXML(@xmlDocParserID, '/PaySource/PaySourcePricers/PaySourcePricer', 2)    
  WITH    
  (    
  [DTAPSPID] [bigint]    
  , [DTAPSID] [bigint]    
  , [LUTPTID] [int]    
  , [LoginSessionGUID] [uniqueidentifier]    
  , [DoNotExport] [bit]    
  , [ExportedUID] [int]    
  , [SharedWeightDTAPSPID] [bigint]    
  , [version] [varchar](50)    
  , [effdate] [datetime]    
  , [tab_filename] [varchar](9)    
  , [grpr_type] [varchar](5)    
  , [grpr_vers] [varchar](3)    
  , [grpr_date] [varchar](1)    
  , [pricer_type] [varchar](2)    
  , [icd9_map] [char](1)    
  , [edit_date] [bit]    
  , [dsc_flag] [bit]    
  , [poa_flag] [bit]    
  , [hac_flag] [bit]    
  , [hac_override_id] [varchar](10)    
  , [oce_flag] [bit]    
  , [ocewp_flag] [bit]    
  , [nonoce_flag] [bit]    
  , [lcd_flag] [bit]    
  , [map_override_id] varchar(20)    
  , [map_category] char(2)    
  , [map_type] char(2)    
  , [closed_fac_sw] char(1)    
  , [ace_override_id] varchar(20)    
  , [bwgt_option] varchar(1)    
  , [disch_drg_option] varchar(1)    
  , [hac_version] varchar(4)--includes the xml in the value    
  , [CCIRequest_flag] bit    
  , [CCIBypass_flag] bit    
  , [PhysicianEdit_flag] bit    
  , [TRICAREOPPS] bit    
  , [reimbdate] varchar(1)    
  , [asc_override_id] varchar(20)    
  , [apc_override_id] varchar(20)    
  , [paysrc_notes] varchar(100)    
  , [StateCCIValue] varchar(2)    
  , [user_key] varchar(3)    
  , [pay_except] char(2)    
  , [line_bypass] char(1)    
  , [ICD9Routing] bit    
  , [vers_qual] char(1)   
  , [edit_req2] bit     
  , [analyzer_type] varchar(2)    
  , [analyzer_type_rsvd] varchar(2)    
  , [analyzer_vers] varchar(2)    
  , [analyzer_vers_rsvd] varchar(4)    
  , [start_lvl_option1] bit    
  , [start_lvl_option2] bit    
  , [start_lvl_option3] bit    
  , [start_lvl_option4] bit    
  , [start_lvl_option5] bit    
  , [lvl_change_option] varchar(1)    
  , [edc_action] varchar(1)    
  , [facility_type] varchar(2)    
  , [LUTWTID] int    
  , [PhysEdit_MaxDME] bit    
  , [moe_flag] bit    
  , [mcd_override_id] varchar (20)    
  , [cah_oce_flag] [bit] -- new column Din   
  , [othermedicare_flag] bit
  , [ppc_vers] varchar(3)
  , [phys_rule_override_id] varchar(20)
  , [phys_code_override_id] varchar(20)
  ) xmlData    
    
 RETURN    
END
GO
PRINT N'Altering Procedure [dbo].[SP_DTA_PaySourcePricer_Save]...';


GO
 -- ============================================================================                
-- Author:  Amy Zhao                
-- Modified by                
-- Create date: 09/23/2011                
-- Description:                 
-- This stored procedure is to save the xml format PaySourcePricer data                 
-- into database.                
-- 1. Check if the @DTAPSID(param xml) and effective date(from xml) exist in table DTA_PaySourcePricer                
--  if no, insert a new one with @DTAPSID                
--  if yes, update existing one based on @DTAPSID                
-- 2. This sp will ignore the DTAPSID and DTAPSPID from xml. The sp will find this value by itself      
-- 20220311. US874687: Divya Added grpr_date field (151).    
-- 20230323. US1023967: Krishnam Added pay_except field.    
    
-- =============================================================================                
/*******************************************************************************                
DECLARE @xmlData VARCHAR(MAX)               
declare @tlPage bigint                 
SET @xmlData =                 
'<PaySource><facility_id>1122</facility_id><npi /><taxonomy /><payer_id>q</payer_id><paysource_name>q</paysource_name><abbrev_name /><InExportQueue>false</InExportQueue><LUTPSCID>1</LUTPSCID><PaySourcePricers><PaySourcePricer><reimbdate>A</reimbdate><DoNo
  
tExport>false</DoNotExport><closed_fac_sw>false</closed_fac_sw><grpr_vers>16</grpr_vers><bwgt_option /><disch_drg_option /><paysrc_notes /><DTAPSID>27573</DTAPSID><DTAPSPID>267219</DTAPSPID><effdate>7/1/2016</effdate><grpr_type>55</grpr_type><havewt>N</ha
  
vewt><icd9_map>0</icd9_map><LUTPTID>14</LUTPTID><pricer_type>i </pricer_type><dsc_flag>false</dsc_flag><othermedicare_flag>false</othermedicare_flag><poa_flag>false</poa_flag><hac_flag>false</hac_flag><hac_override_id /><oce_flag>false</oce_flag><ocewp_fl
ag>false</ocewp_flag><nonoce_flag>false</nonoc  
e_flag><lcd_flag>false</lcd_flag><CCIRequest_flag>false</CCIRequest_flag><CCIBypass_flag>false</CCIBypass_flag><PhysicianEdit_flag>false</PhysicianEdit_flag><TRICAREOPPS>false</TRICAREOPPS><map_type>00</map_type><ace_override_id>ace</ace_override_id><asc_
  
override_id /><apc_override_id>apc</apc_override_id><hac_version>000</hac_version><StateCCIValue /><State_CCI_Visible>true</State_CCI_Visible><user_key /><line_bypass>0</line_bypass><ICD9Routing>false</ICD9Routing><LoginSessionGUID>00000000-0000-0000-0000
  
-000000000000</LoginSessionGUID></PaySourcePricer></PaySourcePricers><payer_name /><DTAPSID>27573</DTAPSID><LoginSessionGUID>00000000-0000-0000-0000-000000000000</LoginSessionGUID><pattype>02</pattype><npi_flag>0</npi_flag></PaySource>'                
DECLARE @LoginSessionGUID as uniqueidentifier              
set @LoginSessionGUID='0229A9C4-7A07-4F22-8092-C55194A4CFFD'              
exec [SP_DTA_PaySourcePricer_Save]@LoginSessionGUID, 59,@xmlData,@tlPage OUTPUT                
                
********************************************************************************/    
ALTER PROCEDURE [dbo].[SP_DTA_PaySourcePricer_Save] @LoginSessionGUID uniqueidentifier, @DTAPSID bigint, @XmlStr varchar(max), @DTAPSPID bigint OUT    
AS    
BEGIN    
 -- SET NOCOUNT ON added to prevent extra result sets from                
 SET NOCOUNT ON;    
    
 -- variables for try-catch                
	DECLARE	@retVal AS int,
   @errSeverity AS int,    
   @errMsg AS varchar(max),    
   @currentStep varchar(150)    
 SET @retVal = 0    
    
 -- variables for xml handling                
 DECLARE @iDoc AS int    
 SET @iDoc = NULL    
    
 -- other variables                
	DECLARE	@LoginUser varchar(500),
   @effdate datetime,    
   @LUTPTID int    
 SELECT    
  @DTAPSPID = NULL,    
  @effdate = NULL,    
  @LUTPTID = NULL    
    
 BEGIN TRY    
    
  SET @currentStep = 'Get login user name.'    
		EXEC sp_GetLoguser	@LoginSessionGUID,
       @LoginUser OUT    
    
  -- parse the XML data to tables                
  SET @currentStep = 'Parse xml.'    
		EXEC sp_xml_preparedocument	@iDoc OUTPUT,
         @XmlStr    
    
  -- parse the XML to table #tmpDTA_PaySourcePricer                 
  SET @currentStep = 'Calling functio dbo.udf_XMLToTableDTA_PaySourcePricer()'    
  IF OBJECT_ID('tempdb..#tmpDTA_PaySourcePricer ') IS NOT NULL    
  BEGIN    
   DROP TABLE #tmpDTA_PaySourcePricer    
  END    
  SELECT    
   * INTO #tmpDTA_PaySourcePricer    
  FROM dbo.udf_XMLToTableDTA_PaySourcePricer(@iDoc)    
    
    
    
  -- clean xml obj                
  EXEC sp_xml_removedocument @iDoc    
  SET @iDoc = NULL    
    
  Declare @count As int --Raise error if parent is deleted by another user     
  EXEC [dbo].[SP_IsRecordExists] 'dbo.DTA_PaySource','DTAPSID',@DTAPSID,@output = @count OUTPUT    
  IF( @count = 0)    
  BEGIN    
   RAISERROR ('INGX:Your changes could not be saved. This item may have been modified or deleted by another user.', 16, 1)    
  END    
  -- get the certain info from xml                
  SET @currentStep = 'Getting certain info from #DTA_PaySource.'    
  SELECT    
   @effdate = effdate,    
   @LUTPTID = LUTPTID,    
   @DTAPSPID = DTAPSPID    
  FROM #tmpDTA_PaySourcePricer    
    
  -- validate effdate                
  IF (@effdate IS NULL)    
   RAISERROR ('Effective date is empty.', 16, 1)    
    
  -- insert a new PaySoucePricer                
  IF (@DTAPSPID < 1)    
  BEGIN    
    
   -- validate if the effdate exists for the paysource              
   SET @currentStep = 'Validating if the effdate exists for paysource.'    
   IF (EXISTS (SELECT    
     1    
    FROM DTA_PaySourcePricer WITH (NOLOCK)    
    WHERE DTAPSID = @DTAPSID    
    AND effdate = @effdate)    
    )    
    RAISERROR ('INGX: Effective date already exists in this pay source', 16, 1)    
    
   SET @currentStep = 'Inserting a new DTA_PaySourcePricer.'    
       
   INSERT INTO DTA_PaySourcePricer (DTAPSID    
   , [LUTPTID]    
   , [LoginSessionGUID]    
   , [LoginUser]    
   , [Enabled]    
   , [DoNotExport]    
   , [InsertedTS]    
   --,[SharedWeightDTAPSPID]                
   , [version]    
   , [effdate]    
   --,[tab_filename]                
   , [havewt]    
   , [grpr_type]    
   , [grpr_vers]    
   , [grpr_date]    
   , [pricer_type]    
   , [icd9_map]    
   , [edit_date]    
   , [dsc_flag]    
   , [poa_flag]    
   , [hac_flag]    
   , [hac_override_id]    
   , [oce_flag]    
   , [ocewp_flag]    
   , [nonoce_flag]    
   , [lcd_flag]    
   , [map_override_id]    
   , [map_category]    
   , [map_type]    
   , [closed_fac_sw]    
   , [ace_override_id]    
   , [bwgt_option]    
   , [disch_drg_option]    
   , [hac_version]    
   , [CCIRequest_flag]    
   , [CCIBypass_flag]    
   , [PhysicianEdit_flag]    
   , [TRICAREOPPS]    
   , [reimbdate]    
   , [asc_override_id]    
   , [paysrc_notes]    
   , [StateCCIValue]    
   , [user_key]    
   , [pay_except] -- new column krishnam    
   , [line_bypass]    
   , [icd9_routing]    
   , [apc_override_id]    
   , [vers_qual] 
   , [edit_req2]    
   , [analyzer_type]    
   , [analyzer_type_rsvd]    
   , [analyzer_vers]    
   , [analyzer_vers_rsvd]    
   , [start_lvl_option1]    
   , [start_lvl_option2]    
   , [start_lvl_option3]    
   , [start_lvl_option4]    
   , [start_lvl_option5]    
   , [lvl_change_option]    
   , [edc_action]    
   , [facility_type]    
   , [PhysEdit_MaxDME]    
   , [moe_flag]    
   , [mcd_override_id]    
   , [cah_oce_flag] -- new column Din
   , [othermedicare_flag]
   , [ppc_vers]
   , [phys_rule_override_id]
   , [phys_code_override_id]
   )    
    SELECT    
     @DTAPSID,    
     tpsp.[LUTPTID],    
     @LoginSessionGUID,    
     @LoginUser,    
     1   -- Enabled                
     ,    
     [DoNotExport],    
     GETDATE() -- InsertedTS                
     --,[SharedWeightDTAPSPID]                
     ,    
     [version],    
     [effdate]    
     --,[tab_filename]                
     --,[havewt]                
     ,    
     'N' -- we always set havewt='N' for inserting                
     ,    
     [grpr_type],    
     [grpr_vers],    
     [grpr_date],    
     [pricer_type],    
     [icd9_map],    
     [edit_date],    
     [dsc_flag],    
     [poa_flag],    
     [hac_flag],    
     [hac_override_id],    
     [oce_flag],    
     [ocewp_flag],    
     [nonoce_flag],    
     [lcd_flag],    
     [map_override_id],    
     [map_category],    
     [map_type],    
     [closed_fac_sw],    
     [ace_override_id],    
     [bwgt_option],    
     [disch_drg_option],    
     REPLACE([hac_version], '.', ''),    
     [CCIRequest_flag],    
     [CCIBypass_flag],    
     [PhysicianEdit_flag],    
     [TRICAREOPPS],    
     [reimbdate],    
     [asc_override_id],    
     [paysrc_notes],    
     [StateCCIValue],    
     [user_key],    
     [pay_except], -- new column krishnam    
     [line_bypass],    
     [icd9_routing],    
     [apc_override_id],    
     [vers_qual],   
     [edit_req2],     
     [analyzer_type],    
     [analyzer_type_rsvd],    
     [analyzer_vers],    
     [analyzer_vers_rsvd],    
     [start_lvl_option1],    
     [start_lvl_option2],    
     [start_lvl_option3],    
     [start_lvl_option4],    
     [start_lvl_option5],    
     [lvl_change_option],    
     [edc_action],    
     [facility_type],    
     [PhysEdit_MaxDME],    
     [moe_flag],    
     [mcd_override_id],    
     [cah_oce_flag], -- new column Din 
	 [othermedicare_flag],
     [ppc_vers],
     [phys_rule_override_id],
	 [phys_code_override_id]
    FROM #tmpDTA_PaySourcePricer tpsp    
    LEFT OUTER JOIN LUT_PricerType lpt    
     ON tpsp.LUTPTID = lpt.LUTPTID    
    WHERE lpt.[Enabled] = 1    
    
   -- return   @DTAPSPID                
   SET @DTAPSPID = @@IDENTITY    
    
   SET @currentStep = 'Insert into  DTA_AuditTrail from #DTA_PaySourcePricer .'    
   SELECT    
    @DTAPSPID AS DTAPSPID,    
    'User Created' AS field_name,    
    'Created' AS new_value INTO #DTA_PaySourcePricer    
			EXEC sp_DTA_AuditTrail_Insert	@LoginSessionGuid,
           'UI'    
    
  END    
  ELSE -- update existing PaySoucePricer                
  BEGIN    
    
   -- create temp for audit trail                
   SET @currentStep = 'Create table table #PPS_Table_Original.'    
   SELECT    
    * INTO #PPS_Table_Original    
   FROM DTA_PaySourcePricerForAudit_VW    
   WHERE DTAPSPID = @DTAPSPID    
    
   -- update                
   SET @currentStep = 'Updating table DTA_PaySourcePricer.'    
    
   UPDATE DTA_PaySourcePricer    
			SET	DTA_PaySourcePricer.[LUTPTID] = tpsp.[LUTPTID],
    DTA_PaySourcePricer.[LoginSessionGUID] = @LoginSessionGUID,    
    DTA_PaySourcePricer.[LoginUser] = @LoginUser,    
    DTA_PaySourcePricer.[DoNotExport] = tpsp.[DoNotExport],    
    DTA_PaySourcePricer.[ModifiedTS] = GETDATE()    
    --, DTA_PaySourcePricer.[SharedWeightDTAPSPID] = tpsp.[SharedWeightDTAPSPID]                
    --, DTA_PaySourcePricer.[version] = tpsp.[version]                
    ,    
    DTA_PaySourcePricer.[effdate] = tpsp.[effdate]    
    --, DTA_PaySourcePricer.[tab_filename] = tpsp.[tab_filename]                
    --, DTA_PaySourcePricer.[havewt] = tpsp.[havewt]                
    ,    
    DTA_PaySourcePricer.[grpr_type] = tpsp.[grpr_type],    
    DTA_PaySourcePricer.[grpr_vers] = tpsp.[grpr_vers],    
    DTA_PaySourcePricer.[grpr_date] = tpsp.[grpr_date],    
    DTA_PaySourcePricer.[pricer_type] = tpsp.[pricer_type],    
    DTA_PaySourcePricer.[icd9_map] = tpsp.[icd9_map],    
    DTA_PaySourcePricer.[edit_date] = tpsp.[edit_date],    
    DTA_PaySourcePricer.[dsc_flag] = tpsp.[dsc_flag],    
    DTA_PaySourcePricer.[poa_flag] = tpsp.[poa_flag],    
    DTA_PaySourcePricer.[hac_flag] = tpsp.[hac_flag],    
    DTA_PaySourcePricer.[hac_override_id] = tpsp.[hac_override_id],    
    DTA_PaySourcePricer.[oce_flag] = tpsp.[oce_flag],    
    DTA_PaySourcePricer.[ocewp_flag] = tpsp.[ocewp_flag],    
    DTA_PaySourcePricer.[nonoce_flag] = tpsp.[nonoce_flag],    
    DTA_PaySourcePricer.[lcd_flag] = tpsp.[lcd_flag],    
    DTA_PaySourcePricer.[map_override_id] = tpsp.[map_override_id],    
    DTA_PaySourcePricer.[map_category] = tpsp.[map_category],    
    DTA_PaySourcePricer.[map_type] = tpsp.[map_type],    
    DTA_PaySourcePricer.[closed_fac_sw] = tpsp.[closed_fac_sw],    
    DTA_PaySourcePricer.[ace_override_id] = tpsp.[ace_override_id],    
    DTA_PaySourcePricer.[bwgt_option] = tpsp.[bwgt_option],    
    DTA_PaySourcePricer.[disch_drg_option] = tpsp.[disch_drg_option],    
    DTA_PaySourcePricer.[hac_version] = REPLACE(tpsp.[hac_version], '.', ''),    
    DTA_PaySourcePricer.[CCIRequest_flag] = tpsp.[CCIRequest_flag],    
    DTA_PaySourcePricer.[CCIBypass_flag] = tpsp.[CCIBypass_flag],    
    DTA_PaySourcePricer.[PhysicianEdit_flag] = tpsp.[PhysicianEdit_flag],    
    DTA_PaySourcePricer.[TRICAREOPPS] = tpsp.[TRICAREOPPS],    
    DTA_PaySourcePricer.[reimbdate] = tpsp.[reimbdate],    
    DTA_PaySourcePricer.[asc_override_id] = tpsp.[asc_override_id],    
    DTA_PaySourcePricer.[paysrc_notes] = tpsp.[paysrc_notes],    
    DTA_PaySourcePricer.[StateCCIValue] = tpsp.[StateCCIValue],    
    DTA_PaySourcePricer.[user_key] = tpsp.[user_key],    
    DTA_PaySourcePricer.[pay_except] = tpsp.[pay_except],    
    DTA_PaySourcePricer.[line_bypass] = tpsp.[line_bypass],    
    DTA_PaySourcePricer.[icd9_routing] = tpsp.[icd9_routing],    
    DTA_PaySourcePricer.[apc_override_id] = tpsp.[apc_override_id],    
    DTA_PaySourcePricer.[vers_qual] = tpsp.[vers_qual],
    DTA_PaySourcePricer.[edit_req2] = tpsp.[edit_req2],    
    DTA_PaySourcePricer.[analyzer_type] = tpsp.[analyzer_type],    
    DTA_PaySourcePricer.[analyzer_type_rsvd] = tpsp.[analyzer_type_rsvd],    
    DTA_PaySourcePricer.[analyzer_vers] = tpsp.[analyzer_vers],    
    DTA_PaySourcePricer.[analyzer_vers_rsvd] = tpsp.[analyzer_vers_rsvd],    
    DTA_PaySourcePricer.[start_lvl_option1] = tpsp.[start_lvl_option1],    
    DTA_PaySourcePricer.[start_lvl_option2] = tpsp.[start_lvl_option2],    
    DTA_PaySourcePricer.[start_lvl_option3] = tpsp.[start_lvl_option3],    
    DTA_PaySourcePricer.[start_lvl_option4] = tpsp.[start_lvl_option4],    
    DTA_PaySourcePricer.[start_lvl_option5] = tpsp.[start_lvl_option5],    
    DTA_PaySourcePricer.[lvl_change_option] = tpsp.[lvl_change_option],    
    DTA_PaySourcePricer.[edc_action] = tpsp.[edc_action],    
    DTA_PaySourcePricer.[facility_type] = tpsp.[facility_type],    
    DTA_PaySourcePricer.[PhysEdit_MaxDME] = tpsp.[PhysEdit_MaxDME],    
    DTA_PaySourcePricer.[moe_flag] = tpsp.[moe_flag],    
    DTA_PaySourcePricer.[mcd_override_id] = tpsp.[mcd_override_id],    
    DTA_PaySourcePricer.[cah_oce_flag] = tpsp.[cah_oce_flag], -- new column Din
	DTA_PaySourcePricer.[othermedicare_flag] = tpsp.[othermedicare_flag],
    DTA_PaySourcePricer.[ppc_vers] = tpsp.[ppc_vers],
    DTA_PaySourcePricer.[phys_rule_override_id] = tpsp.[phys_rule_override_id],
	DTA_PaySourcePricer.[phys_code_override_id] = tpsp.[phys_code_override_id]
   FROM DTA_PaySourcePricer psp    
   INNER JOIN #tmpDTA_PaySourcePricer tpsp    
    ON psp.DTAPSPID = tpsp.DTAPSPID    
   LEFT OUTER JOIN LUT_PricerType lpt    
    ON tpsp.LUTPTID = lpt.LUTPTID    
   WHERE psp.DTAPSPID = @DTAPSPID    
   AND lpt.[Enabled] = 1    
    
   --US867896: If we are removing shared paysource from DO Not Export, then it's parent loaded paysource should also removed from DO Not Export    
   IF EXISTS (SELECT DTAPSPID FROM DTA_PaySourcePricer WITH (NOLOCK)    
    WHERE DTAPSPID = @DTAPSPID AND ISNULL(DoNotExport,0) = 0 AND SharedWeightDTAPSPID IS NOT NULL)    
   BEGIN    
    UPDATE psp      
     SET psp.DoNotExport = 0     
    FROM DTA_PaySourcePricer psp  WITH (NOLOCK)    
    INNER JOIN DTA_PaySourcePricer psp1     
    ON psp.DTAPSPID = psp1.SharedWeightDTAPSPID    
    WHERE psp1.DTAPSPID = @DTAPSPID    
   END    
    
   -- audit trail                
   SET @currentStep = 'Call sp_DTA_AuditTrail_Insert_PPS to insert PaySourcePricer'    
   PRINT 'audit error'    
			EXEC sp_DTA_AuditTrail_Insert_PPS	@LoginSessionGUID,
            'DTA_PaySourcePricerForAudit_VW'    
    
   -- clean up                
   IF OBJECT_ID('tempdb..#PPS_Table_Original') IS NOT NULL    
   BEGIN    
    
    DROP TABLE #PPS_Table_Original    
    
   END    
    
  END    
    
    
 END TRY    
 BEGIN CATCH    
  SELECT    
   @errSeverity = ERROR_SEVERITY(),    
   @errMsg = ERROR_MESSAGE()    
		EXEC dbo.[SP_DTA_EventLog_Insert_SP]	@LoginSessionGUID,
            '[SP_DTA_PaySourcePricer_Save]',    
            @@ERROR,    
            @errSeverity,    
            @errMsg,    
            @@TRANCOUNT,    
            @currentStep    
 END CATCH    
    
END
GO
PRINT N'Altering Procedure [dbo].[SP_Import_config]...';


GO
-- ============================================================================            
-- Author:  Balaji            
-- Modified by: Amy Zhao     
-- Create date: 09/23/2011   
-- Modified by: Shubhra Jain  
-- Modified Date: 05/13/2014        
-- Modified by: Hao Jiang  
-- Modified Date: 09/12/2019     
-- Modified by: Hao Jiang  
-- Modified Date: 10/30/2019  
-- Modified by: Raghu Malladi  
-- Modified Date: 05/26/2021  
-- Description:             
-- This stored procedure is to transfer data from TMP_IM_config to DTA tables            
-- 1. If the data are existing in DTA_PaySource            
--      * If the paysource pricer exists, update the existing data in DTA_PaySourcePricer            
--        else insert into DTA_PaySourcePricer.            
-- 2. If the data are not existing in DTA_PaySource, insert data into tables            
--    DTA_PaySource and DTA_PaySourcePricer            
-- Revision History:  2012-03-17 added 3 to IMSource support medout     
-- Revision 2 History: As per US109668 If Updated Shared Weights is selected in Preferences screen , updated the payer id for shared paysource  
-- Revision 3 History: As per US570761 icd9_map field value should be set only from config file and not med file - mdesai  
-- Revision 4 History: As per US656371 included is not null in predicate to improve the performance  
-- 06/03/2020: Modified by Amy:   
--             1. added index to the temp tables  
--             2. modified the logic for shared weight  
-- 3. If the grouper type and grouper version take from config file not from med files.   
--  If values not exist in config then consider med files  
-- 06/18/2021: Modified by Ajay  
-- 05/26/2021: Modified by Raghu: As per US769608 added a field cah_oce_flag for CAH at 90th position.  
-- 20220527.US892068.Vadim      Added import type and default user parm for Export to Diff DB case  
-- US890131: V2208.01 - ER - Import new C Config files split by Patient Type  
-- 20230323.US1023967.Krishnam Payer Exceptions to be exported in 305-306  
-- ===========================================================================================================================================        
  
/*******************************************************************************          
exec [SP_Import_config] 'D9B01822-4823-4AC3-8C6D-BA8A39682B99', 'config', 100         
exec [SP_Import_config] 'D9B01822-4823-4AC3-8C6D-BA8A39682B99', 'medcalc', 100         
exec [SP_Import_config] 'D9B01822-4823-4AC3-8C6D-BA8A39682B99', 'medout', 100         
exec [SP_Import_config] 'D9B01822-4823-4AC3-8C6D-BA8A39682B99', 'medirf', 100    use ratemanager    
********************************************************************************/  
  
ALTER PROCEDURE [dbo].[SP_Import_config]   
 @LoginSessionGUID uniqueidentifier,   
 @ImportedFileWithoutExt varchar(20) = '',   
 @DTAPDID int = 0,  
 @ImportType varchar(900) = '', -- for BackLog DB Audit table, field field_name  
 @DefaultUser varchar(500) = '' -- for BackLog DB Audit table, field LoginUser  
AS  
  
BEGIN  
 -- variables for try-catch          
 DECLARE @retVal AS int,  
   @errSeverity AS int,  
   @errMsg AS varchar(max),  
   @currentStep varchar(50),  
   @DTAPDIDLabel varchar(50)  
 SET @retVal = 0  
 -- SET NOCOUNT ON added to prevent extra result sets from         
 SET XACT_ABORT ON  
 SET NOCOUNT ON;  
 --other Variables-----          
 DECLARE @EffectRows bigint  
 BEGIN TRY  
  
  SET @DTAPDIDLabel =   
  (CASE  
   WHEN (@DTAPDID > 0) Then ' DTAPDID: ' + cast(@DTAPDID as varchar)  
   ELSE ''  
  END)  
  
  
  DECLARE @DTAELID bigint  
  SET @currentStep = 'Start to transfer from TMP_IM_config.' + @DTAPDIDLabel  
  EXEC [SP_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           NULL,  
           @DTAELID OUT  
  
  -- get LoginUser          
  DECLARE @LoginUser varchar(500)  
  EXEC [SP_GetLogUser] @LoginSessionGUID,  
        @LoginUser OUT;  
  
  -------Remove duplicate data on shared weight import in the TMP_IM_config------    
  
  WITH TempEmp (TMPIMID, duplicateRecCount)  
  AS (SELECT  
   TMPIMID,  
   ROW_NUMBER() OVER (PARTITION BY pfac, psrc, npi, taxonomy, pattype, effdate ORDER BY TMPIMID)  
   AS duplicateRecCount  
  FROM dbo.TMP_IM_config)  
  
  DELETE FROM TempEmp  
  WHERE duplicateRecCount > 1  
  
     DELETE TMP_IM_config  
   FROM TMP_IM_config tic  
   LEFT OUTER JOIN LUT_PricerType lpt WITH (NOLOCK)  
    ON tic.pricer_type  
    COLLATE Latin1_General_CS_AS = lpt.PricerTypeName COLLATE Latin1_General_CS_AS  
  WHERE (lpt.[Enabled] = 0  
   OR lpt.LUTPTID IS NULL) and tic.pricer_type not in ('0 ','00')  
  
  SET @EffectRows = @@ROWCOUNT  
  SET @currentStep = 'Delete the data if the pricer type is not in our system.' + @DTAPDIDLabel  
  EXEC [SP_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           @EffectRows,  
           @DTAELID OUT  
  -----update the payer_id preference-------          
  
  DECLARE @newval varchar(50)  
  DECLARE @oldval varchar(50)  
  DECLARE @updatesharedweights varchar(1)  
  
  EXEC [SP_CreateSystemPreferenceImportPayerTempTable]  
  
  IF OBJECT_ID('tempdb..##ADM_SystemPreference_ImportPayer') IS NOT NULL  
  BEGIN  
  
   IF ((SELECT  
     COUNT(*)  
    FROM ##ADM_SystemPreference_ImportPayer)  
    = 1)  
   BEGIN  
  
    SELECT  
     @newval = NewVal,  
     @oldval = OldVal,  
     @updatesharedweights = UpdateSharedWeights  
    FROM ##ADM_SystemPreference_ImportPayer  
    UPDATE TMP_IM_config  
    SET psrc = @newval  
    WHERE psrc = LTRIM(RTRIM(@oldval))  
    IF (@UpdateSharedWeights = '1')  
     UPDATE TMP_IM_config  
     SET ratepsrc = @newval  
     WHERE ratepsrc = LTRIM(RTRIM(@oldval))  
    ----- update havewt to null if the updatesharedweights is false  
    IF (@updatesharedweights = '0' AND @newval != @oldval)  
     UPDATE TMP_IM_config  
     SET havewt = null  
     WHERE ratepsrc = LTRIM(RTRIM(@oldval))  
   END  
   DROP TABLE ##ADM_SystemPreference_ImportPayer  
  END  
  -------------------------------------------------------          
    
  
  -- update pattype for medxxx import   
  
  DECLARE @pattype char(2);  
  SET @currentStep = 'Get @pattype. '  
  SET @pattype = dbo.udf_GetPatType(@ImportedFileWithoutExt)  
  
  UPDATE TMP_IM_config  
  SET pattype = ISNULL(@pattype, '')  
  WHERE IMSource IN (2, 3, 4) -- 1 is config(we don't need update config, because pattype in the file); 2 is medcalc/irf/snf; 3 is medout; 4 is Shared          
  
  -- update grouper type  in tmp table   
  UPDATE TMP_IM_config  
  SET grpr_type = CASE WHEN (LEN(grpr_type) > 2                                            
  OR LEN(RTRIM(ISNULL(grpr_type, ''))) < 2) THEN '00' ELSE lrg.GrouperValue END  
  FROM TMP_IM_config tic  
  INNER JOIN LUT_RateGrouper lrg WITH (NOLOCK)  
   ON RTRIM(LTRIM(tic.grpr_type)) = RTRIM(LTRIM(lrg.GrouperShortName))  
   AND tic.pattype = lrg.pattype  
  WHERE tic.IMSource IN (2, 3) -- 1 is config; 2 is medcalc/irf/snf; 3 means imported from medout          
  
   
  -- update LUTPTID  for all Pricer type    
  UPDATE TMP_IM_config          
  SET LUTPTID = pt.LUTPTID          
  FROM TMP_IM_config tic          
    INNER JOIN LUT_PricerType pt WITH (NOLOCK)          
     ON tic.pattype = pt.pattype       
     and (CASE  
     WHEN tic.pricer_type not in ('0 ','00') then tic.pricer_type  
     WHEN tic.pricer_type in ('0 ','00') and tic.pattype='01' then 'II'      
     WHEN tic.pricer_type in ('0 ','00') and tic.pattype='02' then 'OO'      
     WHEN tic.pricer_type in ('0 ','00') and tic.pattype='03' then 'RR'      
     WHEN tic.pricer_type in ('0 ','00') and tic.pattype='04' then 'PP'     
     WHEN tic.pricer_type in ('0 ','00') and tic.pattype='06' then 'SS'     
     ELSE '00'    
     END)=pt.PricerTypeName      
  
  -- delete the records with LUTPTID is null        
  
  DELETE FROM TMP_IM_config  
  WHERE LUTPTID IS NULL  
  
  -- update necessary columns in tmp table, grpr_vers, icd9_map, edit_date        
UPDATE tic  
  SET   
   grpr_vers =   
      CASE    
        WHEN tic.IMSource != 1 THEN RIGHT(tic.grpr_vers,2) -- If the file is not config, then we can directly take right 2 digits from provided grouper version   
         WHEN LEFT(lutrg.GrouperVersionFormat,7) = 'DECIMAL' AND lutrg.LUTRGID =22 AND RTRIM(ISNULL(tic.grpr_vers, '')) <> ''  THEN CONCAT(IIF(LEN(tic.grpr_vers) = 3, RIGHT(tic.grpr_vers,1), '0'),LEFT(tic.grpr_vers,2)) -- For EAPG Grouper the value will become from 143 to 314 -US1187126    
        WHEN LEFT(lutrg.GrouperVersionFormat,7) = 'DECIMAL' THEN IIF(LEN(tic.grpr_vers) = 3 AND RIGHT(tic.grpr_vers,1) != '0', tic.grpr_vers, LEFT(tic.grpr_vers,2))   
        ELSE LEFT(tic.grpr_vers,2)  
      END,  
   icd9_map =  
      CASE icd9_map  
       WHEN 'N' THEN '0'  
       WHEN 'Y' THEN '1'  
       ELSE icd9_map  
      END,  
   edit_date =  
      CASE edit_date  
       WHEN 'A' THEN 1  
       ELSE 0  
      END  
  FROM TMP_IM_config tic   
  LEFT OUTER JOIN LUT_RateGrouper lutrg  
  ON lutrg.GrouperValue = tic.grpr_type  
  AND lutrg.pattype = tic.pattype   
  
  SET @currentStep = 'Updated paytype in TMP_IM_config.' + @DTAPDIDLabel  
  EXEC [SP_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           @@ROWCOUNT,  
           @DTAELID OUT  
  
  -- clear previous tmp data          
  UPDATE DTA_PaySource  
  SET TMPPSID = NULL  
  WHERE TMPPSID IS NOT NULL  
  
  UPDATE DTA_PaySourcePricer  
  SET TMPIMCID = NULL  
  WHERE TMPIMCID IS NOT NULL  
  
  -- tmp table to hold key of paysource          
  DECLARE @PaySourcesInTMP TABLE (  
   TMPPSID int NOT NULL IDENTITY (1, 1) PRIMARY KEY,  
   pfac char(16),  
   psrc char(13),  
   npi char(10),  
   taxonomy char(10),  
   pattype char(2)  
  )  
  
  -- insert into the paysource data          
  INSERT INTO @PaySourcesInTMP  
   SELECT DISTINCT  
    pfac,  
    psrc,  
    npi,  
    taxonomy,  
    pattype  
   FROM TMP_IM_config  
  
  -- set up TMPPSID          
  UPDATE TMP_IM_config  
  SET TMP_IM_config.TMPPSID = pst.TMPPSID  
  FROM TMP_IM_config tic  
  INNER JOIN @PaySourcesInTMP pst  
   ON tic.pfac = pst.pfac  
   AND tic.psrc = pst.psrc  
   AND tic.npi = pst.npi  
   AND tic.taxonomy = pst.taxonomy  
   AND tic.pattype = pst.pattype  
  
  
  -- log          
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           'Get exist pay source - start',  
           NULL,  
           @DTAELID  
  
  -- get exising PaySource          
  SELECT  
   ps.DTAPSID,  
   pst.TMPPSID INTO #ExistPaySource  
  FROM DTA_PaySource ps WITH (NOLOCK)  
  INNER JOIN @PaySourcesInTMP pst  
   ON ps.facility_id = pst.pfac  
   AND ps.npi = pst.npi  
   AND ps.payer_id = pst.psrc  
   AND ps.taxonomy = pst.taxonomy  
   AND ps.pattype = pst.pattype  
  WHERE ps.DTAPDID = @DTAPDID  
  
  CREATE CLUSTERED INDEX #tmp_idx_ExistPaySource ON #ExistPaySource (TMPPSID, DTAPSID)  
  
  -- log          
  SELECT  
   @EffectRows = COUNT(1)  
  FROM #ExistPaySource WITH (NOLOCK)  
  SET @currentStep = 'Get exist pay source - end.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           @EffectRows,  
           @DTAELID  
  
  -- log          
  SET @currentStep = 'Get exist pay source pricer - start.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           NULL,  
           @DTAELID  
  
  -- get existing PaySourcePricer          
  SELECT  
   tvp.TMPIMID,  
   psp.DTAPSPID,  
   psp.LUTPTID INTO #ExistPaySourcePricer  
  FROM TMP_IM_config tvp WITH (NOLOCK)  
  INNER JOIN #ExistPaySource tps WITH (NOLOCK)  
   ON tvp.TMPPSID = tps.TMPPSID  
  INNER JOIN DTA_PaySourcePricer psp WITH (NOLOCK)  
   ON psp.DTAPSID = tps.DTAPSID  
   AND psp.effdate = tvp.effdate  
  WHERE psp.DTAPSID = tps.DTAPSID  
  AND psp.DTAPDID = @DTAPDID  
  
  CREATE CLUSTERED INDEX #tmp_idx_ExistPaySourcePricer ON #ExistPaySourcePricer (TMPIMID, DTAPSPID)  
  
  -- get the pricer type that is difference between TMP_IM_config and DTA_PaySourcePricer    
  SELECT  
   ROW_NUMBER() OVER (ORDER BY lut.LUTPTID) AS ID,  
   tpsp.DTAPSPID,  
   lut.PricerTableName,  
   lutw.WeightTableName INTO #NeedRemovePPSTables  
  FROM #ExistPaySourcePricer tpsp  
  INNER JOIN TMP_IM_config tvp  
   ON tpsp.TMPIMID = tvp.TMPIMID  
  INNER JOIN LUT_PricerType lut  
   ON tpsp.LUTPTID = lut.LUTPTID  
  LEFT OUTER JOIN LUT_WeightType lutw  
   ON lut.LUTWTID = lutw.LUTWTID  
  WHERE tpsp.LUTPTID <> tvp.LUTPTID  
  
  -- log          
  SELECT  
   @EffectRows = COUNT(1)  
  FROM #ExistPaySourcePricer  
  SET @currentStep = 'Get exist pay source pricer - end.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           @EffectRows,  
           @DTAELID  
  
  -- log          
  SET @currentStep = 'update PaySourcePricer for existing PaySource - start.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
           '[SP_Import_config]',  
           '',  
           @currentStep,  
           NULL,  
           @DTAELID  
  
  -- get data to update PaySourcePricer for existing PaySource          
  --SELECT * INTO #TMP_IM_config1InTmp FROM TMP_IM_config WITH (NOLOCK) WHERE TMPIMID IN (SELECT TMPIMID FROM #ExistPaySourcePricer WITH (NOLOCK)) AND IMSource in (1,2,3)--1 config; 2 medcalc; 3 medcalcout; we don't need 4 which is shared weight         
  
  SELECT  
   TMP_IM_config.*,  
   #ExistPaySourcePricer.DTAPSPID INTO #TMP_IM_config1InTmp  
  FROM TMP_IM_config WITH (NOLOCK)  
  INNER JOIN #ExistPaySourcePricer WITH (NOLOCK)  
   ON TMP_IM_config.TMPIMID = #ExistPaySourcePricer.TMPIMID  
  WHERE IMSource IN (1, 2, 3)--1 config; 2 medcalc/irf/snf; 3 medcalcout; we don't need 4 which is shared weight      
    
  CREATE CLUSTERED INDEX #tmp_idx_TMP_IM_config1InTmp ON #TMP_IM_config1InTmp (TMPIMID, DTAPSPID)      
  
  BEGIN TRAN  
  
   -- remove existing data from PPS table if the pricer type is different from the existing    
   IF (EXISTS (SELECT  
     (PricerTableName)  
    FROM #NeedRemovePPSTables)  
    )  
   BEGIN  
    DECLARE @PricerTableName varchar(30),  
      @WeightTableName varchar(30),  
      @QueryString nvarchar(max),  
      @index int,  
      @total int  
    SELECT  
     @index = 1,  
     @total = MAX(ID)  
    FROM #NeedRemovePPSTables  
  
    -- return pps data    
    WHILE (@index <= @total)  
    BEGIN  
  
     SELECT  
      @PricerTableName = PricerTableName,  
      @WeightTableName = WeightTableName  
     FROM #NeedRemovePPSTables  
     WHERE ID = @index  
  
     -- only for the table exists    
     IF (EXISTS (SELECT  
       name  
      FROM sys.objects  
      WHERE name = @PricerTableName)  
      )  
     BEGIN  
      SET @QueryString = 'DELETE pps FROM ' + @PricerTableName + ' pps INNER JOIN #NeedRemovePPSTables tpsp ON pps.DTAPSPID=tpsp.DTAPSPID AND pps.DTAPDID=@DTAPDID'  
      --PRINT @QueryString           
      EXECUTE sp_executesql @QueryString, N'@DTAPDID int', @DTAPDID = @DTAPDID  
     END  
  
     -- only for the table weight exists    
     IF (EXISTS (SELECT  
       name  
      FROM sys.objects  
      WHERE name = ISNULL(@WeightTableName, ''))  
      )  
     BEGIN  
      SET @QueryString = 'DELETE weight FROM ' + @WeightTableName + ' weight INNER JOIN #NeedRemovePPSTables tpsp ON weight.DTAPSPID=tpsp.DTAPSPID AND weight.DTAPDID=@DTAPDID'  
      --PRINT @QueryString           
      EXECUTE sp_executesql @QueryString, N'@DTAPDID int', @DTAPDID = @DTAPDID  
     END  
  
     SET @index = @index + 1  
    END  
   END  
  
   -- update PaySourcePricer for config import  
   IF(EXISTS (SELECT TOP 1 IMSource FROM TMP_IM_config WHERE IMSource = 1))                              
   BEGIN   
   UPDATE psp  
   SET LoginSessionGUID = @LoginSessionGUID,  
    LoginUser = @LoginUser,  
    psp.effdate = tvp.effdate,  
    psp.LUTPTID = tvp.LUTPTID,  
    psp.pricer_type = tvp.pricer_type,  
    psp.ImportedTS = GETDATE(),  
    psp.ModifiedTS = GETDATE(),  
    psp.grpr_type = tvp.grpr_type,  
    psp.grpr_vers = tvp.grpr_vers,  
    psp.hac_override_id = tvp.hac_override_id,  
    psp.dsc_flag = tvp.dsc_flag,  
    psp.oce_flag = tvp.OCE_flag,  
    psp.ocewp_flag = tvp.ocewp_flag,  
    psp.nonoce_flag = tvp.nonoce_flag,  
    psp.lcd_flag = tvp.LCD_flag,  
    psp.poa_flag = tvp.POA_flag,  
    psp.hac_flag = tvp.HAC_flag,  
    psp.icd9_map = tvp.icd9_map,  
    psp.map_override_id = tvp.map_override_id,  
    psp.map_category = tvp.map_category,  
    psp.map_type = tvp.map_type,  
    psp.closed_fac_sw = tvp.closed_fac_sw,  
    psp.ace_override_id = tvp.ace_override_id,  
    psp.[version] = tvp.[version],  
    psp.TMPIMCID = tvp.TMPIMCID,  
    psp.bwgt_option = tvp.bwgt_option,  
    psp.disch_drg_option = tvp.disch_drg_option,  
    psp.hac_version = tvp.hac_version,  
    psp.CCIRequest_flag = tvp.CCIRequest_flag,  
    psp.CCIBypass_flag = tvp.CCIBypass_flag,  
    psp.PhysicianEdit_flag = tvp.PhysicianEdit_flag,  
    psp.reimbdate = tvp.reimbdate,  
    psp.TRICAREOPPS = tvp.TRICAREOPPS,  
    psp.asc_override_id = tvp.asc_override_id,  
    psp.sqr_flag = tvp.sqr_flag,  
    psp.StateCCIValue = tvp.StateCCIValue,  
    psp.user_key = tvp.user_key,  
    psp.pay_except = tvp.pay_except,  
    psp.line_bypass = tvp.line_bypass,  
    psp.icd9_routing = tvp.icd9_routing,  
    psp.apc_override_id = tvp.apc_override_id,  
    psp.vers_qual = tvp.vers_qual,  
    psp.edit_req2 = tvp.edit_req2,  
    psp.[analyzer_type] = tvp.[analyzer_type],  
    psp.[analyzer_type_rsvd] = tvp.[analyzer_type_rsvd],  
    psp.[analyzer_vers] = tvp.[analyzer_vers],  
    psp.[analyzer_vers_rsvd] = tvp.[analyzer_vers_rsvd],  
    psp.[start_lvl_option1] = tvp.[start_lvl_option1],  
    psp.[start_lvl_option2] = tvp.[start_lvl_option2],  
    psp.[start_lvl_option3] = tvp.[start_lvl_option3],  
    psp.[start_lvl_option4] = tvp.[start_lvl_option4],  
    psp.[start_lvl_option5] = tvp.[start_lvl_option5],  
    psp.[lvl_change_option] = tvp.[lvl_change_option],  
    psp.[edc_action] = tvp.[edc_action],  
    psp.[facility_type] = tvp.[facility_type],  
    psp.[rf_vers] = tvp.[rf_vers],  
    psp.[PhysEdit_MaxDME] = tvp.[PhysEdit_MaxDME],  
    psp.[moe_flag] = tvp.[moe_flag],  
    psp.[mcd_override_id] = tvp.[mcd_override_id],  
    psp.[cah_oce_flag] = tvp.[cah_oce_flag], 
    psp.grpr_date = tvp.[grpr_date],
    psp.[othermedicare_flag] = tvp.[othermedicare_flag],
    psp.ppc_vers =tvp.ppc_vers,
    psp.phys_rule_override_id = tvp.phys_rule_override_id,
    psp.phys_code_override_id = tvp.phys_code_override_id
   FROM DTA_PaySourcePricer psp  
    INNER JOIN #TMP_IM_config1InTmp tvp WITH (NOLOCK)  
     ON psp.DTAPSPID = tvp.DTAPSPID  
   WHERE psp.DTAPDID = @DTAPDID      
   END  
  
   -- update PaySourcePricer for medcalc import  
   ELSE IF(EXISTS (SELECT TOP 1 IMSource FROM TMP_IM_config WHERE IMSource IN (2,3)))                             
   BEGIN  
   UPDATE psp  
   SET LoginSessionGUID = @LoginSessionGUID,  
    LoginUser = @LoginUser,  
    psp.effdate = tvp.effdate,  
    psp.LUTPTID = tvp.LUTPTID,  
    psp.pricer_type = tvp.pricer_type,  
    psp.ImportedTS = GETDATE(),  
    psp.ModifiedTS = GETDATE(),  
    psp.[version] = tvp.[version],  
    psp.havewt = tvp.havewt,  
    psp.tab_filename = tvp.tab_filename,  
    psp.grpr_type=(CASE WHEN RTRIM(LTRIM(ISNULL(psp.grpr_type,'')))='' THEN tvp.grpr_type ELSE psp.grpr_type END),  
    psp.grpr_vers=(CASE WHEN RTRIM(LTRIM(ISNULL(psp.grpr_vers,'')))='' THEN tvp.grpr_vers ELSE psp.grpr_vers END),  
    psp.edit_date = CAST(tvp.edit_date AS bit),  
    psp.TMPIMCID = tvp.TMPIMCID  
  
   FROM DTA_PaySourcePricer psp  
    INNER JOIN #TMP_IM_config1InTmp tvp WITH (NOLOCK)  
     ON psp.DTAPSPID = tvp.DTAPSPID  
   WHERE   
    psp.DTAPDID = @DTAPDID  
   END          
  
   -- log          
   SET @EffectRows = @@ROWCOUNT  
   SET @currentStep = 'update PaySourcePricer for existing PaySource - end.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            @EffectRows,  
            @DTAELID  
  
   --log          
   SET @currentStep = 'insert PaySourcePricer for existing PaySource - start.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            NULL,  
            @DTAELID  
  
   -- insert PaySourcePricer for existing PaySource          
   SELECT  
    * INTO #TMP_IM_config2InTmp  
   FROM TMP_IM_config WITH (NOLOCK)  
   WHERE TMPIMID NOT IN (SELECT  
    TMPIMID  
   FROM #ExistPaySourcePricer WITH (NOLOCK))  
  
   CREATE CLUSTERED INDEX #tmp_idx_TMP_IM_config2InTmp ON #TMP_IM_config2InTmp (TMPIMID, TMPPSID)  
  
   INSERT INTO DTA_PaySourcePricer (DTAPSID, LoginSessionGUID, LoginUser, effdate, LUTPTID, pricer_type, InsertedTS, ImportedTS  
   , grpr_type, grpr_vers, hac_override_id, dsc_flag, oce_flag, ocewp_flag  
   , nonoce_flag, lcd_flag, poa_flag, hac_flag  
   , icd9_map, map_override_id, map_category, map_type, closed_fac_sw, ace_override_id  
   , [version], havewt, tab_filename, edit_date, TMPIMCID, DoNotExport, bwgt_option, disch_drg_option, hac_version  
   , CCIRequest_flag, CCIBypass_flag, PhysicianEdit_flag, reimbdate, TRICAREOPPS, asc_override_id, sqr_flag, StateCCIValue, user_key, [pay_except], line_bypass, icd9_routing, apc_override_id, vers_qual, edit_req2  
   , [analyzer_type],[analyzer_type_rsvd],[analyzer_vers],[analyzer_vers_rsvd],[start_lvl_option1],[start_lvl_option2],[start_lvl_option3],[start_lvl_option4],[start_lvl_option5],[lvl_change_option],[edc_action]  
   , [facility_type], [rf_vers], [PhysEdit_MaxDME],[moe_flag],[mcd_override_id],[cah_oce_flag],[grpr_date],[othermedicare_flag],ppc_vers,phys_rule_override_id, phys_code_override_id,DTAPDID  
   )  
    SELECT  
     tps.DTAPSID,  
     @LoginSessionGuid,  
     @LoginUser,  
     tvp.effdate,  
     tvp.LUTPTID,  
     tvp.pricer_type,  
     GETDATE(),  
     GETDATE(),  
     tvp.grpr_type,  
     tvp.grpr_vers,  
     tvp.hac_override_id,  
     tvp.dsc_flag,  
     tvp.OCE_flag,  
     tvp.ocewp_flag,  
     tvp.nonoce_flag,  
     tvp.LCD_flag,  
     tvp.POA_flag,  
     tvp.HAC_flag,  
     tvp.icd9_map,  
     tvp.map_override_id,  
     tvp.map_category,  
     tvp.map_type,  
     tvp.closed_fac_sw,  
     ace_override_id,  
     tvp.[version],  
     tvp.havewt,  
     tvp.tab_filename,  
     CAST(tvp.edit_date AS bit),  
     tvp.TMPIMCID,  
     0,  
     tvp.bwgt_option,  
     tvp.disch_drg_option,  
     tvp.hac_version,  
     tvp.CCIRequest_flag,  
     tvp.CCIBypass_flag,  
     tvp.PhysicianEdit_flag,  
     tvp.reimbdate,  
     tvp.TRICAREOPPS,  
     tvp.asc_override_id,  
     tvp.sqr_flag,  
     tvp.StateCCIValue,  
     tvp.user_key,  
     tvp.pay_except,  
     tvp.line_bypass,  
     tvp.icd9_routing,  
     tvp.apc_override_id,  
     tvp.vers_qual,  
     tvp.edit_req2,  
     tvp.[analyzer_type],  
     tvp.[analyzer_type_rsvd],  
     tvp.[analyzer_vers],  
     tvp.[analyzer_vers_rsvd],  
     tvp.[start_lvl_option1],  
     tvp.[start_lvl_option2],  
     tvp.[start_lvl_option3],  
     tvp.[start_lvl_option4],  
     tvp.[start_lvl_option5],  
     tvp.[lvl_change_option],  
     tvp.[edc_action],  
     tvp.[facility_type],  
     tvp.[rf_vers],  
     tvp.[PhysEdit_MaxDME],  
     tvp.[moe_flag],  
     tvp.[mcd_override_id],  
     tvp.[cah_oce_flag], 
     tvp.[grpr_date],   
     tvp.[othermedicare_flag],
     tvp.ppc_vers,
     tvp.phys_rule_override_id,
     tvp.phys_code_override_id,
     @DTAPDID  
    FROM #TMP_IM_config2InTmp tvp WITH (NOLOCK)  
    INNER JOIN #ExistPaySource tps WITH (NOLOCK)  
     ON tvp.TMPPSID = tps.TMPPSID  
   --WHERE tvp.TMPIMID NOT IN (SELECT TMPIMID FROM #ExistPaySourcePricer)             
  
   -- log          
   SET @EffectRows = @@ROWCOUNT  
   SET @currentStep = 'Insert PaySourcePricer for existing PaySource - end.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            @EffectRows,  
            @DTAELID  
  
   -- log          
   SET @currentStep = 'Insert new PaySource - start.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            NULL,  
            @DTAELID  
  
   ---Inserting into DTA_PaySource in which the values which doesnt exist on TMP_IM_config table-----/*  
  
   --SELECT * INTO #TMP_IM_config3InTmp FROM TMP_IM_config WITH (NOLOCK) WHERE TMPPSID NOT IN (SELECT TMPPSID FROM #ExistPaySource)          
   SELECT  
    TMP_IM_config.* INTO #TMP_IM_config3InTmp  
   FROM TMP_IM_config WITH (NOLOCK)  
   LEFT OUTER JOIN #ExistPaySource  
    ON TMP_IM_config.TMPPSID = #ExistPaySource.TMPPSID  
   WHERE #ExistPaySource.TMPPSID IS NULL  
  
   CREATE CLUSTERED INDEX #tmp_idx_TMP_IM_config3InTmp ON #TMP_IM_config3InTmp (TMPIMID, TMPPSID)  
  
   INSERT INTO DTA_PaySource (LoginSessionGUID, LoginUser, facility_id, payer_id, npi, taxonomy, pattype, npi_flag, [Enabled], InsertedTS, TMPPSID, DTAPDID)  
    SELECT DISTINCT  
     LoginSessionGUID,  
     @LoginUser,  
     pfac,  
     psrc,  
     npi,  
     taxonomy,  
     pattype,  
     npi_flag,  
     1,  
     GETDATE(),  
     TMPPSID,  
     @DTAPDID  
    FROM #TMP_IM_config3InTmp tvp WITH (NOLOCK)  
    --WHERE TMPPSID NOT IN (SELECT TMPPSID FROM #ExistPaySource)          
    ORDER BY TMPPSID  
  
   --Inserting into   DTA_PaySourcePricer tables --------          
  
   -- log          
   SET @EffectRows = @@ROWCOUNT  
   SET @currentStep = 'Insert new PaySource - end.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            @EffectRows,  
            @DTAELID  
  
   -- log          
   SET @currentStep = 'Insert PaySourcePricer for new PaySource - start.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            NULL,  
            @DTAELID  
  
   --SELECT * INTO #DTA_PaySourceInTmp FROM DTA_PaySource WITH (NOLOCK) WHERE DTAPSID NOT IN(SELECT DTAPSID FROM #ExistPaySource WITH (NOLOCK) )            
   SELECT  
    DTA_PaySource.* INTO #DTA_PaySourceInTmp  
   FROM DTA_PaySource WITH (NOLOCK)  
   LEFT OUTER JOIN #ExistPaySource WITH (NOLOCK)  
    ON DTA_PaySource.DTAPSID = #ExistPaySource.DTAPSID   
   WHERE   
    DTAPDID = @DTAPDID  
    AND #ExistPaySource.DTAPSID IS NULL  
  
   CREATE CLUSTERED INDEX #tmp_idx_DTA_PaySourceInTmp ON #DTA_PaySourceInTmp (DTAPSID, TMPPSID)  
  
   INSERT INTO DTA_PaySourcePricer (DTAPSID, LUTPTID, LoginSessionGUID,  
   LoginUser,  
   InsertedTS,  
   ImportedTS,  
   DoNotExport,  
   effdate,  
   grpr_type,  
   grpr_vers,  
   pricer_type,  
   hac_override_id,  
   dsc_flag,  
   oce_flag,  
   ocewp_flag,  
   nonoce_flag,  
   lcd_flag,  
   poa_flag,  
   hac_flag,  
   icd9_map,  
   map_override_id,  
   map_category,  
   map_type,  
   closed_fac_sw,  
   ace_override_id,  
   [version],  
   havewt,  
   tab_filename,  
   edit_date,  
   TMPIMCID,  
   bwgt_option,  
   disch_drg_option,  
   hac_version,  
   CCIRequest_flag,  
   CCIBypass_flag,  
   PhysicianEdit_flag,  
   reimbdate,  
   TRICAREOPPS,  
   asc_override_id,  
   sqr_flag,  
   StateCCIValue,  
   user_key,  
   pay_except,  
   line_bypass,  
   icd9_routing,  
   apc_override_id,  
   vers_qual, 
   edit_req2,  
   [analyzer_type],  
   [analyzer_type_rsvd],  
   [analyzer_vers],  
   [analyzer_vers_rsvd],  
   [start_lvl_option1],  
   [start_lvl_option2],  
   [start_lvl_option3],  
   [start_lvl_option4],  
   [start_lvl_option5],  
   [lvl_change_option],  
   [edc_action],  
   [facility_type],  
   [rf_vers],  
   [PhysEdit_MaxDME],  
   [moe_flag],  
   [mcd_override_id],  
   [cah_oce_flag],
   [grpr_date],   
   othermedicare_flag,
   ppc_vers,
   phys_rule_override_id,
   phys_code_override_id,
   DTAPDID  
   )  
    SELECT  
     DTPSRC.DTAPSID,  
     tvp.LUTPTID,  
     tvp.LoginSessionGUID,  
     @LoginUser,  
     GETDATE(),  
     GETDATE(),  
     0,  
     tvp.effdate,  
     tvp.grpr_type,  
     tvp.grpr_vers,  
     tvp.pricer_type,  
     tvp.hac_override_id,  
     tvp.dsc_flag,  
     tvp.OCE_flag,  
     tvp.ocewp_flag,  
     tvp.nonoce_flag,  
     tvp.LCD_flag,  
     tvp.POA_flag,  
     tvp.HAC_flag,  
     tvp.icd9_map,  
     tvp.map_override_id,  
     tvp.map_category,  
     tvp.map_type,  
     tvp.closed_fac_sw,  
     ace_override_id,  
     tvp.[version],  
     tvp.havewt,  
     tvp.tab_filename,  
     CAST(tvp.edit_date AS bit),  
     tvp.TMPIMCID,  
     tvp.bwgt_option,  
     tvp.disch_drg_option,  
     tvp.hac_version,  
     tvp.CCIRequest_flag,  
     tvp.CCIBypass_flag,  
     tvp.PhysicianEdit_flag,  
     tvp.reimbdate,  
     tvp.TRICAREOPPS,  
     tvp.asc_override_id,  
     tvp.sqr_flag,  
     tvp.StateCCIValue,  
     tvp.user_key,  
     tvp.pay_except,  
     tvp.line_bypass,  
     icd9_routing,  
     apc_override_id,  
     tvp.vers_qual,  
     tvp.edit_req2,  
     tvp.[analyzer_type],  
     tvp.[analyzer_type_rsvd],  
     tvp.[analyzer_vers],  
     tvp.[analyzer_vers_rsvd],  
     tvp.[start_lvl_option1],  
     tvp.[start_lvl_option2],  
     tvp.[start_lvl_option3],  
     tvp.[start_lvl_option4],  
     tvp.[start_lvl_option5],  
     tvp.[lvl_change_option],  
     tvp.[edc_action],  
     tvp.[facility_type],  
     tvp.[rf_vers],  
     tvp.[PhysEdit_MaxDME],  
     tvp.[moe_flag],  
     tvp.[mcd_override_id],  
     tvp.[cah_oce_flag], 
     tvp.[grpr_date],   
     tvp.othermedicare_flag,
     tvp.ppc_vers,
     tvp.phys_rule_override_id,
     tvp.phys_code_override_id,
     @DTAPDID  
    FROM #DTA_PaySourceInTmp DTPSRC WITH (NOLOCK)  
    INNER JOIN #TMP_IM_config3InTmp tvp WITH (NOLOCK)  
     ON DTPSRC.TMPPSID = tvp.TMPPSID  
   -- WHERE tvp.TMPPSID NOT IN(SELECT TMPPSID FROM #ExistPaySource )           
   --AND DTPSRC.DTAPSID NOT IN(SELECT DTAPSID FROM #ExistPaySource )   
  
   -- log          
   SET @EffectRows = @@ROWCOUNT  
   SET @currentStep = 'Insert PaySourcePricer for new PaySource - end.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            @EffectRows,  
            @DTAELID  
  
   -- update SharedWeight(we don't update shared weight for config)  
   IF(@ImportedFileWithoutExt NOT IN('config', 'cfgout', 'cfgirf', 'cfgphys', 'cfgcah', 'cfgsnf'))  
   BEGIN      
  
    -- put shared weight to tmp     
    SELECT  
     tic.TMPIMCID,  
     pspv.DTAPSPID  
    INTO #SharedPaySourcesInTMP  
    FROM TMP_IM_config tic  
    LEFT OUTER JOIN DTA_PaySourceKey_VW pspv WITH (NOLOCK)  
     ON pspv.facility_id = tic.ratefac  
     AND pspv.payer_id = tic.ratepsrc  
     AND pspv.npi = tic.ratenpi  
     AND pspv.taxonomy = tic.ratetaxonomy  
     AND (  
      pspv.pricer_type COLLATE Latin1_General_CS_AS = tic.pricer_type COLLATE Latin1_General_CS_AS OR  
      pspv.pricer_type = 'i' AND tic.pricer_type = 'h' OR  
      pspv.pricer_type = 'h' AND tic.pricer_type = 'i'  
      )  
     AND pspv.effdate = tic.rateeffdate  
    WHERE  
     pspv.DTAPDID=@DTAPDID  
  
    CREATE CLUSTERED INDEX #tmp_idx ON #SharedPaySourcesInTMP (TMPIMCID)  
  
    -- update SharedDTAPSPID  
    UPDATE DTA_PaySourcePricer  
    SET SharedWeightDTAPSPID = t.DTAPSPID  
    FROM DTA_PaySourcePricer psp  
    LEFT OUTER JOIN #SharedPaySourcesInTMP t  
     ON psp.TMPIMCID = t.TMPIMCID  
    WHERE psp.DTAPDID = @DTAPDID  
    AND psp.TMPIMCID IS NOT NULL  
    AND psp.havewt = 'L'  
  
    DROP TABLE #SharedPaySourcesInTMP  
  
    SET @currentStep = 'Update SharedWeightDTAPSPID in table DTA_PaySourcePricer from TMP_IM_config.' + @DTAPDIDLabel  
    EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
             '[SP_Import_config]',  
             '',  
             @currentStep,  
             @@ROWCOUNT,  
             @DTAELID  
   END  
  
   -- handle AuditTrail  
   IF(@DTAPDID = 0)  
   BEGIN          
    EXEC dbo.[sp_DTA_AuditTrail_Insert_IM] @LoginSessionGUID, @ImportType, @DefaultUser  
   END  
  
   DROP TABLE #ExistPaySource  
   DROP TABLE #ExistPaySourcePricer  
   DROP TABLE #NeedRemovePPSTables  
  
   SET @currentStep = 'Transferring from TMP_IM_config is completed.' + @DTAPDIDLabel  
   EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
            '[SP_Import_config]',  
            '',  
            @currentStep,  
            NULL,  
            @DTAELID  
  
  COMMIT TRAN  
  
 END TRY  
 BEGIN CATCH  
  SELECT  
   @errSeverity = ERROR_SEVERITY(),  
   @errMsg = ERROR_MESSAGE() + @DTAPDIDLabel  
  EXEC dbo.[SP_DTA_EventLog_Insert_SP] @LoginSessionGUID,  
            '[SP_Import_config]',  
            @@ERROR,  
            @errSeverity,  
            @errMsg,  
            @@TRANCOUNT,  
            @currentStep  
 END CATCH  
END
GO
PRINT N'Altering Procedure [dbo].[SP_DTA_PaySourcePricer_GetByDTAPSID]...';


GO
 -- ================================================================================              
-- Author:  Balaji              
-- Create date:               
-- Description:    
-- Modified by Dinaakr 05/18/2021 - New columnd added  
-- 20220311. US874687: Divya Added grpr_date field.  
-- 20230323. US1023967: Krishnam Added pay_except field.  
-- 20250925 .US1461731: Manisha Updated ppc version format
-- ================================================================================              
/**********************************************************************************              
EXEC [SP_DTA_PaySourcePricer_GetByDTAPSID] 353117,1          
**********************************************************************************/  
  
ALTER PROCEDURE [dbo].[SP_DTA_PaySourcePricer_GetByDTAPSID] (@DTAPSID bigint, @DTAPDID int = 0)
AS  
BEGIN  
 SELECT  
  ISNULL(psp.DTAPSPID, 0) AS DTAPSPID,  
  ps.DTAPSID,  
  psp.LUTPTID,  
  ps.[LoginSessionGUID],  
  ps.[LoginUser],  
  psp.[Enabled],  
  psp.[DoNotExport],  
  psp.[InsertedTS],  
  psp.[ModifiedTS],  
  psp.[ImportedTS],  
  psp.[ExportedTS],  
  psp.[ExportedUID],  
  psp.[SharedWeightDTAPSPID],  
  psp.CopiedFromDTAPSPID,  
  psp.[version],  
  psp.[effdate],  
  psp.[tab_filename],  
  psp.[havewt],  
  psp.[grpr_type],  
  CASE   
   WHEN psp.[grpr_vers] IS NULL OR RTRIM(LTRIM(psp.[grpr_vers])) = '' THEN ''  
   WHEN LEFT(rg.GrouperVersionFormat,7) = 'INTEGER' THEN LEFT(psp.[grpr_vers],2)  
   WHEN LEFT(rg.GrouperVersionFormat,7) = 'DECIMAL' and rg.LutRGID = 22 THEN IIF(LEN(psp.[grpr_vers]) = 3, LEFT(psp.[grpr_vers],1)+'.'+RIGHT(psp.[grpr_vers],2), '0'+'.'+LEFT(psp.[grpr_vers],2))   
   ELSE CONCAT(LEFT(psp.[grpr_vers],2),'.',IIF(LEN(psp.[grpr_vers]) = 3, RIGHT(psp.[grpr_vers],1), '0'))  
  END AS [grpr_vers],  
  psp.[grpr_date],  
  psp.[pricer_type],  
  psp.[icd9_map],  
  psp.[edit_date],  
  psp.[dsc_flag],  
  psp.[poa_flag],  
  psp.[hac_flag],  
  psp.[hac_override_id],  
  psp.[oce_flag],  
  psp.[ocewp_flag],  
  psp.[nonoce_flag],  
  psp.[lcd_flag],  
  psp.[map_override_id],  
  psp.[map_category],  
  psp.[map_type],  
  psp.[closed_fac_sw],  
  ace_override_id,  
  psp.TMPWID,  
  psp.TMPIMCID,  
  psp.bwgt_option,  
  psp.disch_drg_option,  
  CASE   
   WHEN psp.[hac_version] IS NULL OR RTRIM(LTRIM(psp.[hac_version])) = '' THEN ''  
   WHEN LEFT(rg.GrouperVersionFormat,7) = 'INTEGER' THEN LEFT(psp.[hac_version],2)  
   ELSE CONCAT(SUBSTRING(psp.[hac_version], 1, LEN(psp.[hac_version]) - 1), '.', RIGHT(psp.[hac_version], 1))  
  END AS [hac_version],  
  psp.CCIRequest_flag,  
  psp.CCIBypass_flag,  
  psp.PhysicianEdit_flag,  
  psp.TRICAREOPPS,  
  psp.reimbdate,  
  psp.asc_override_id,  
  psp.paysrc_notes,  
  psp.sqr_flag,  
  psp.StateCCIValue,  
  psp.user_key,  
  psp.[pay_except],  
  psp.line_bypass,  
  psp.icd9_routing, --AS ICD9Routing, -- this alias doesn't work with EF Core    
  psp.apc_override_id,  
  psp.vers_qual,  
  psp.edit_req2,
  psp.[analyzer_type],  
  psp.[analyzer_type_rsvd],  
  psp.[analyzer_vers],  
  psp.[analyzer_vers_rsvd],  
  psp.[start_lvl_option1],  
  psp.[start_lvl_option2],  
  psp.[start_lvl_option3],  
  psp.[start_lvl_option4],  
  psp.[start_lvl_option5],  
  psp.[lvl_change_option],  
  psp.[edc_action],  
  psp.[facility_type],  
  psp.[rf_vers],  
  psp.[LUTWTID],  
  psp.[PhysEdit_MaxDME],  
  psp.[moe_flag],  
  psp.[mcd_override_id],  
  psp.[cah_oce_flag], -- new column Din 
  psp.othermedicare_flag,
  psp.[phys_rule_override_id],
  psp.[phys_code_override_id],
  CASE  
   WHEN psp.[ppc_vers] IS NULL OR RTRIM(LTRIM(psp.[ppc_vers])) = '' THEN ''  
 ELSE CONCAT(LEFT(psp.[ppc_vers],2),'.',IIF(LEN(psp.[ppc_vers]) = 3, RIGHT(psp.[ppc_vers],1), '0'))
 END AS [ppc_vers], 
 psp.DTAPDID
 FROM dbo.DTA_PaySource ps  
 LEFT OUTER JOIN dbo.DTA_PaySourcePricer psp  
  ON ps.DTAPSID = psp.DTAPSID  
 LEFT OUTER JOIN dbo.LUT_RateGrouper rg  
  ON rg.GrouperValue = psp.grpr_type   
  AND rg.pattype = ps.pattype  
 WHERE ps.DTAPSID = @DTAPSID  
 AND ps.DTAPDID = @DTAPDID  
 AND psp.DTAPDID = @DTAPDID  
 ORDER BY effdate DESC  
END
GO
PRINT N'Altering Procedure [dbo].[SP_LUT_RateEditingMapping_Get]...';


GO
 -- ============================================================================              
-- Author:  Amy Zhao              
-- Modified by Dinakar 4/15/2020 - Supplied DTAPDID to get the correct results          
-- Modified by Dinaakr 05/18/2021 - New columnd added    
-- Modified by Krishnam 03/23/2023 - New column added    
-- Create date: 11/18/2011              
-- Description:               
-- This stored procedure is to get LUT_RateEditiongMapping data by LUTPTID and @DTAPSPID              
-- If @DTAPSPID = 0, return all the data into table LUT_RateEditingMapping              
-- else, get the existing data from DTA_PaySourcePricer              
-- =============================================================================              
    
/*******************************************************************************              
EXEC [SP_LUT_RateEditingMapping_Get] 27, 481              
EXEC [SP_LUT_RateEditingMapping_Get] 13, 0              
********************************************************************************/    
    
ALTER PROCEDURE [dbo].[SP_LUT_RateEditingMapping_Get] (@LUTPTID int, @DTAPSPID bigint, @DTAPDID int)    
AS    
BEGIN    
 IF (@DTAPSPID IN (0, -1))    
 BEGIN    
  SELECT    
   lre.*    
  FROM dbo.LUT_RateEditingMapping lre    
  INNER JOIN LUT_PricerType lpt    
   ON lre.LUTPTID = lpt.LUTPTID    
  WHERE lpt.LUTPTID = @LUTPTID    
 END    
 ELSE    
 BEGIN    
  SELECT    
   lre.[LUTREMID],    
   lre.LUTPTID,    
   lre.[DSCVisible],    
   psp.dsc_flag AS [DSCValue],    
   lre.[POAVisible],    
   psp.poa_flag AS [POAValue],    
   lre.[HACVisible],    
   psp.hac_flag AS [HACValue],    
   psp.hac_override_id AS [HACIDValue],    
   lre.[OCEVisible],    
   psp.oce_flag AS [OCEValue],    
   lre.[OCEWPairsVisible],    
   psp.ocewp_flag AS [OCEWParsValue],    
   lre.[NONOCEVisible],    
   psp.nonoce_flag AS [NONOCEValue],    
   lre.[LCDVisible],    
   psp.lcd_flag AS [LCDValue],    
   lre.[MappingVisible],    
   psp.icd9_map AS [MappingValue],    
   lre.[MapCategoryVisible],    
   psp.map_category AS [MapCategoryValue],    
   lre.[MapTypeVisible],    
   psp.map_type AS [MapTypeValue],    
   lre.[MapIDVisible],    
   psp.map_override_id AS [MapIDValue],    
   lre.ace_override_idVisible,    
   psp.ace_override_id AS [ace_override_idValue],    
   lre.CCIRequestVisible,    
   psp.CCIRequest_flag AS [CCIRequestValue],    
   lre.CCIBypassVisible,    
   psp.CCIBypass_flag AS [CCIBypassValue],    
   lre.PhysicianEditVisible,    
   psp.PhysicianEdit_flag AS [PhysicianEditValue],    
   lre.TRICAREOPPSVisible,    
   psp.TRICAREOPPS AS [TRICAREOPPSValue],    
   lre.asc_override_idVisible,    
   psp.asc_override_id AS [asc_override_idValue],    
   lre.state_cci_Visible,    
   psp.StateCCIValue AS [StateCCIValue],    
   ISNULL(lre.user_keyValue, '') + '|' + ISNULL(psp.user_key, '') AS [user_keyValue]  -- default value | pps data        
   ,    
   ISNULL(psp.line_bypass, 0) AS [line_bypassValue],    
   psp.icd9_routing AS [icd9_routingvalue],    
   psp.apc_override_id,    
   lre.apc_override_idVisible,    
   psp.apc_override_id AS [apc_override_idValue],    
   ISNULL(psp.vers_qual, 0) AS [vers_qualValue],    
   lre.[edit_req2Visible],    
   psp.[edit_req2] as [edit_req2Value],    
   ISNULL(psp.facility_type, '00') AS [facility_typeValue],    
   lre.PhysEdit_MaxDMEVisible,    
   psp.PhysEdit_MaxDME AS [PhysEdit_MaxDMEValue],    
   lre.moe_flagVisible,    
   psp.moe_flag AS [moe_flagValue],    
   lre.mcd_override_idVisible,    
   psp.mcd_override_id AS [mcd_override_idValue],    
   lre.cah_oceVisible,    
   psp.cah_oce_flag AS [cah_oceValue], -- new coumn Din  
   lre.grpr_dateVisible,    
   psp.grpr_date AS [grpr_dateValue],    
   psp.pay_except AS [pay_exceptValue], -- new column krishnam    
   lre.[othermedicare_flagVisible],  
   psp.[othermedicare_flag] as [othermedicare_flagValue],
   lre.phys_rule_override_idVisible as [phys_rule_override_idVisible],  
   psp.phys_rule_override_id as [phys_rule_override_idValue],  
   lre.phys_code_override_idVisible as [phys_code_override_idVisible],
   psp.phys_code_override_id as [phys_code_override_idValue]  
  FROM dbo.LUT_RateEditingMapping lre    
  INNER JOIN LUT_PricerType lpt    
   ON lre.LUTPTID = lpt.LUTPTID    
  INNER JOIN DTA_PaySourcePricer psp    
   ON lpt.LUTPTID = psp.LUTPTID    
  WHERE lpt.LUTPTID = @LUTPTID    
  AND psp.DTAPSPID = @DTAPSPID    
  AND psp.DTAPDID = @DTAPDID    
 END    
END
GO
PRINT N'Altering Procedure [dbo].[SP_Export_config]...';


GO
-- ============================================================================        
-- Author:  Balaji        
-- Modified by: Amy Zhao        
-- Create date: 09/23/2011    
-- Modified by: Callie Ju  
-- Modified date: 12/08/2015      
-- Description:         
-- This stored procedure is to export data from paysource table to config.dat        
-- the format of the file is based on pdf file ConfigFile.pdf          
-- 20170626.US354377.Vadim Follow the same logic for analyzer version (revised) as grouper version: empty for C and filled with 0-s for Cobol.  
-- 20190517.US542829.Mrunal Added two new fields moe_flag(89) and mcd_override_id(238-302)  
-- -- 05/26/2021: Modified by Raghu: As per US769608 added a field cah_oce_flag for CAH at 90th position and export operation for cfgcah where pattype is 05  
-- 20220311. US874687: Divya Added grpr_date field (151).  
-- 20220317.DE229066.Vadim group date flag should NOT be exported into Cobol config files  
-- 20220325.DE229556.Divya  Grouper Date Flag position updated to 304.  
-- 20230323.US1023967.Krishnam Payer Exceptions to be exported in 305-306  
-- 20250904.US1023967.Rakshitha PPC Version to be exported in 307-309 
-- =============================================================================        
  
/*******************************************************************************        
exec [SP_Export_config] '',0,'','','','',0,0     
exec [SP_Export_config] '',0,'','','','',13,1      
********************************************************************************/  
ALTER PROCEDURE [dbo].[SP_Export_config] @ImportedFileWithoutExt varchar(20) = '',  
@FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(10), @PayerID varchar(13),   
@PayerName varchar(50), @PricerTypeID int, @FromDate DateTime = NULL, @ToDate DateTime = NULL, @InExportQueue BIT, @DTAPDID INT = 0  
AS  
BEGIN  
  
 DECLARE @QueryString nvarchar(max),  
   @ParameterList nvarchar(max),  
   @pricer_type char(2),  
   @PricerTableName varchar(30),  
   @hasFilters bit,  
   @pattype char(2)  
  
 SET @pattype = dbo.udf_GetPatType(@ImportedFileWithoutExt)  
  
 SET @ParameterList = N'@FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(10), @PayerID varchar(13), @PayerName varchar(50), @PricerTypeID int, @FromDate DateTime, @ToDate DateTime, @InExportQueue bit, @DTAPDID int, @pattype char(2)'  
  
 SET @QueryString = N'SELECT ' + CHAR(13) + CHAR(10)  
 SET @QueryString = @QueryString + N' DTAPSPID' + CHAR(13) + CHAR(10)  
 SET @QueryString = @QueryString + N' , paysource' + CHAR(13) + CHAR(10)  
 SET @QueryString = @QueryString + N' ,pattype' + CHAR(13) + CHAR(10)  
 SET @QueryString = @QueryString + N' , RIGHT(''0000''+CAST(DENSE_RANK() OVER (PARTITION BY DTAPSID,pattype ORDER BY pattype, effdate desc)as VARCHAR(4)),4)' + CHAR(13) + CHAR(10) -- eseq 32-35        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(8),effdate,112)' + CHAR(13) + CHAR(10) -- effdate 36-43        
 SET @QueryString = @QueryString + N' , SPACE(8)' + CHAR(13) + CHAR(10) -- filler for effective stop  
 SET @QueryString = @QueryString + N' ,PricerTypeName COLLATE Latin1_General_CS_AS' + CHAR(13) + CHAR(10)  
  
 SET @QueryString = @QueryString + N' , SPACE(2)' + CHAR(13) + CHAR(10) -- pricertype reserved        
 SET @QueryString = @QueryString + N' , ISNULL(grpr_type,SPACE(2)) ' + CHAR(13) + CHAR(10) --grpr_type 56-57        
 SET @QueryString = @QueryString + N' , SPACE(2)' + CHAR(13) + CHAR(10) -- Grouper Type Reserved        
  
  
  SET @QueryString = @QueryString + N' , CASE LEN(ISNULL(RTRIM(LTRIM(grpr_vers)),''''))' + CHAR(13) + CHAR(10)     
  SET @QueryString = @QueryString + N'   WHEN 0 THEN SPACE(3)' + CHAR(13) + CHAR(10)       
  SET @QueryString = @QueryString + N'   WHEN 1 THEN CONCAT(''0'',RTRIM(LTRIM(grpr_vers)),''0'')' + CHAR(13) + CHAR(10)       
  SET @QueryString = @QueryString + N'   WHEN 2 THEN CONCAT(RTRIM(LTRIM(grpr_vers)),''0'')' + CHAR(13) + CHAR(10)    
  -- Additional check for EPAG Grouper     
  SET @QueryString = @QueryString + N'   ELSE' + CHAR(13) + CHAR(10)    
  SET @QueryString = @QueryString + N'   CASE WHEN grpr_type = 61 THEN' + CHAR(13) + CHAR(10)    
  SET @QueryString = @QueryString + N'   IIF(LEN(grpr_vers) = 3, (CONCAT(RIGHT(grpr_vers, 2), LEFT(grpr_vers, 1))),(CONCAT(LEFT(grpr_vers, 2), ''0'')))' + CHAR(13) + CHAR(10)    
  SET @QueryString = @QueryString + N'   ELSE grpr_vers END END' + CHAR(13) + CHAR(10) --grpr_vers 60-62    
  --SET @QueryString = @QueryString + N' , RIGHT(SPACE(3)+ISNULL(grpr_vers,SPACE(3)),3) ' + CHAR(13) + CHAR(10) --grpr_vers 60-62        
 --END  
  
 SET @QueryString = @QueryString + N' , REPLICATE(''0'',3)' + CHAR(13) + CHAR(10) --grpr_vers_rsvd 63-65        
 SET @QueryString = @QueryString + N' , SPACE(4)' + CHAR(13) + CHAR(10) --future work 66-69        
 SET @QueryString = @QueryString + N' , REPLICATE(''0'',2)' + CHAR(13) + CHAR(10) --editor Version 70-71        
 SET @QueryString = @QueryString + N' , SPACE(4)' + CHAR(13) + CHAR(10) --future work 72-75   
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(dsc_flag,0))' + CHAR(13) + CHAR(10) --dsc_flag 76-76        
 SET @QueryString = @QueryString + N' , REPLICATE(''0'',1)' + CHAR(13) + CHAR(10) --Space for Easy Edit,CCI -- 76 - 77       
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(CCIRequest_flag,0)) ' + CHAR(13) + CHAR(10) --CCI 78      
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(oce_flag,0))' + CHAR(13) + CHAR(10) --oce_flag  79-79        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(ocewp_flag,0))' + CHAR(13) + CHAR(10) --ocewp_flag 80-80        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(lcd_flag,0))' + CHAR(13) + CHAR(10) --lcd_flag 81-81        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(nonoce_flag,0))' + CHAR(13) + CHAR(10) --nonoce_flag 82-82        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(poa_flag,0))' + CHAR(13) + CHAR(10) --poa_flag 83-83        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(hac_flag,0))' + CHAR(13) + CHAR(10) --hac_flag 84-84        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(TRICAREOPPS,0))' + CHAR(13) + CHAR(10) -- future work Medicare APR and Washington Medicaid 85-85       
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(PhysicianEdit_flag,0))' + CHAR(13) + CHAR(10)     --PhysicianEdit_flag 86-86       
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(edit_req2,0))' + CHAR(13) + CHAR(10) --edit_req2 87-87   
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(PhysEdit_MaxDME,0))' + CHAR(13) + CHAR(10)     --PhysEdit_MaxDME 88-88  
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(moe_flag,0))' + CHAR(13) + CHAR(10)     --moe_flag 89-89     
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(cah_oce_flag,0))' + CHAR(13) + CHAR(10) --cah_oce_flag 90-90  
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(othermedicare_flag,0))' + CHAR(13) + CHAR(10) --othermedicare_flag 91-91  
 SET @QueryString = @QueryString + N'    , REPLICATE(''0'',4)' + CHAR(13) + CHAR(10) -- future work 92-95    
 SET @QueryString = @QueryString + N' , SPACE(20)' + CHAR(13) + CHAR(10)  -- future work 96-115  
 SET @QueryString = @QueryString + N' , RIGHT(''0''+RTRIM(ISNULL(icd9_map,'''')), 1)' + CHAR(13) + CHAR(10)   --- icd9_map 116-116        
 SET @QueryString = @QueryString + N' , ''0''' + CHAR(13) + CHAR(10)  -- future work - grpr_option 117        
 SET @QueryString = @QueryString + N' , SPACE(1)' + CHAR(13) + CHAR(10)  -- wgt_option 118        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(ace_override_id,'''') + SPACE(20), 20)' + CHAR(13) + CHAR(10)  --ace_override_id 119-138        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(hac_override_id,'''') + SPACE(10), 10)' + CHAR(13) + CHAR(10)   --hac_id 139-148        
 SET @QueryString = @QueryString + N' , SPACE(1)' + CHAR(13) + CHAR(10)  -- 149 ACE_flag        
 SET @QueryString = @QueryString + N' , CONVERT(int,''0'')' + CHAR(13) + CHAR(10)   --DSC_FLAG 150   
 SET @QueryString = @QueryString + N' , SPACE(8)' + CHAR(13) + CHAR(10)         -- future work 151-158   
 SET @QueryString = @QueryString + N' , [npi_flag]' + CHAR(13) + CHAR(10)  -- key_type 159--      
 SET @QueryString = @QueryString + N' , LEFT(ISNULL([reimbdate],'''') + SPACE(1), 1)' + CHAR(13) + CHAR(10) --Reimbdate --159      
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(CCIBypass_flag,0))' + CHAR(13) + CHAR(10)  --CCIBypass 160      
 SET @QueryString = @QueryString + N' , SPACE(16)' + CHAR(13) + CHAR(10)   -- future work  161-177      
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(20),ISNULL(asc_override_id,''''))' + CHAR(13) + CHAR(10) --asc_override_id--178-197      
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(map_override_id,'''') + SPACE(20), 20)' + CHAR(13) + CHAR(10)  --Key_type 198-217        
 SET @QueryString = @QueryString + N' , ISNULL(map_category,SPACE(2))' + CHAR(13) + CHAR(10)     --Key_type  218-219        
 SET @QueryString = @QueryString + N' , ISNULL(map_type,SPACE(2))' + CHAR(13) + CHAR(10)         --Key_type 220-221        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(closed_fac_sw,0))' + CHAR(13) + CHAR(10)    -- closed facility - 222-222        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(bwgt_option,'''') + SPACE(1), 1)' + CHAR(13) + CHAR(10) --birth weight -223        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(disch_drg_option,'''') + SPACE(1), 1)' + CHAR(13) + CHAR(10) --disch DRG option -224        
 SET @QueryString = @QueryString + N' , RIGHT(''000'' + ISNULL(hac_version,''''), 3)' + CHAR(13) + CHAR(10) --HAC Version 225-227         
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(sqr_flag,0))' + CHAR(13) + CHAR(10)            --sqr_flag 228-228     
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(2),ISNULL(StateCCIValue,''''))' + CHAR(13) + CHAR(10)          --State CCI 229-230    
 SET @QueryString = @QueryString + N' , LEFT(RTRIM(ISNULL(user_key,'''')) + SPACE(3), 3)' + CHAR(13) + CHAR(10)  --User Key 231-233    
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(line_bypass,0))' + CHAR(13) + CHAR(10)  --Line Bypass 234    
 SET @QueryString = @QueryString + N' , CASE WHEN icd9_routing IS NULL THEN SPACE(1) ELSE CONVERT(CHAR(1),icd9_routing) END' + CHAR(13) + CHAR(10)  --ICD-9 Routing 235    
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(20),ISNULL(apc_override_id,''''))' + CHAR(13) + CHAR(10) --apc_override_id--178-197    
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(vers_qual,'''') + ''0'', 1)' + CHAR(13) + CHAR(10) --Version Qualifier -256      
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(analyzer_type,'''') + SPACE(2), 2)' + CHAR(13) + CHAR(10)   --analyzer_type 257-258        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(analyzer_type_rsvd,'''') + SPACE(2), 2)' + CHAR(13) + CHAR(10)   --analyzer_type_rsvd 259-260        
   
 SET @QueryString = @QueryString + N' , RIGHT(SPACE(2)+RTRIM(LTRIM(ISNULL(analyzer_vers, ''''))), 2) ' + CHAR(13) + CHAR(10) --analyzer_vers 261-262        
 SET @QueryString = @QueryString + N' , RIGHT(SPACE(4)+RTRIM(LTRIM(ISNULL(analyzer_vers_rsvd, ''''))), 4) ' + CHAR(13) + CHAR(10) --analyzer_vers_rsvd 263-266        
 -- END.20170626.US354377.Vadim   
  
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(start_lvl_option1, 0))' + CHAR(13) + CHAR(10) --start_lvl_option1 267        
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(start_lvl_option2, 0))' + CHAR(13) + CHAR(10) --start_lvl_option2 268   
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(start_lvl_option3, 0))' + CHAR(13) + CHAR(10) --start_lvl_option3 269   
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(start_lvl_option4, 0))' + CHAR(13) + CHAR(10) --start_lvl_option4 270  
 SET @QueryString = @QueryString + N' , CONVERT(CHAR(1),ISNULL(start_lvl_option5, 0))' + CHAR(13) + CHAR(10) --start_lvl_option5 271   
 SET @QueryString = @QueryString + N' , RIGHT(''0''+ISNULL(lvl_change_option, ''0''), 1)'  + CHAR(13) + CHAR(10) --lvl_change_option 272  
 SET @QueryString = @QueryString + N' , RIGHT(''0''+ISNULL(edc_action, ''0''), 1)'  + CHAR(13) + CHAR(10) --edc_action 273   
 SET @QueryString = @QueryString + N' , RIGHT(''00''+RTRIM(LTRIM(ISNULL(facility_type, ''''))), 2)' + CHAR(13) + CHAR(10) --analyzer_vers_rsvd 274-275        
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(rf_vers,'''') + SPACE(7), 7)' + CHAR(13) + CHAR(10)   --rf_vers 276-282  
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(mcd_override_id,'''') + SPACE(20), 20)' + CHAR(13) + CHAR(10)  --mcd_override_id 283-302   
 SET @QueryString = @QueryString + N' , SPACE(1)' + CHAR(13) + CHAR(10)  -- future work 303  
  
 SET @QueryString = @QueryString + N' , LEFT(ISNULL([grpr_date],'''') + SPACE(1), 1)' + CHAR(13) + CHAR(10) -- grpr_date 304  
 SET @QueryString = @QueryString + N' , LEFT(ISNULL([pay_except],'''') + SPACE(2), 2)' + CHAR(13) + CHAR(10) -- payer_except 305-306  
 SET @QueryString = @QueryString + N' , LEFT(ISNULL([ppc_vers],'''') + SPACE(3), 3)' + CHAR(13) + CHAR(10) -- ppc_vers 307-309  
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(phys_rule_override_id,'''') + SPACE(20), 20)' + CHAR(13) + CHAR(10)  --phys_rule_override_id 310-329   
 SET @QueryString = @QueryString + N' , LEFT(ISNULL(phys_code_override_id,'''') + SPACE(20), 20)' + CHAR(13) + CHAR(10)  --phys_code_override_id 330-349
 SET @QueryString = @QueryString + N' , SPACE(451)' + CHAR(13) + CHAR(10)  -- future work 350-800   
  
 SET @QueryString = @QueryString + N'FROM ' + CHAR(13) + CHAR(10)  
  
 SET @hasFilters = 0  
 IF (@FacilityID <> ''  
  OR @NPI <> ''  
  OR @Taxonomy <> ''  
  OR @PayerID <> ''  
  OR @PayerName <> ''  
  OR @PricerTypeID > 0  
  OR @FromDate IS NOT NULL  
  OR @ToDate IS NOT NULL  
  OR ISNULL(@InExportQueue, 0) = 1)  
  BEGIN  
   SET @hasFilters = 1  
   SELECT @FromDate = COALESCE(@FromDate, '1/1/1753'),   
    @ToDate = COALESCE(@ToDate, '12/31/9999')  
   SET @QueryString = @QueryString + N' [dbo].udf_Export_Search(@FacilityID, @NPI, @Taxonomy, @PayerID, @PayerName, @PricerTypeID, @InExportQueue, @FromDate, @ToDate)' + CHAR(13) + CHAR(10)  
  END  
 ELSE  
 BEGIN  
  SET @QueryString = @QueryString + N' [dbo].VW_Config_Export WITH (NOLOCK)' + CHAR(13) + CHAR(10)  
 END  
  
 SET @QueryString = @QueryString + N'WHERE (@DTAPDID > 0 OR ISNULL(DoNotExport,0)=0) ' + CHAR(13) + CHAR(10)   
 SET @QueryString = @QueryString + N'AND effdate >= ''2008-10-01''' + CHAR(13) + CHAR(10)  
  
 SET @QueryString = @QueryString + N' AND pattype = @pattype' + CHAR(13) + CHAR(10)  
   
 --US679717.Naga Archive Export - Export  
     IF(@hasFilters = 0)  
  SET @QueryString = @QueryString + N' AND DTAPDID = @DTAPDID'    + CHAR(13) + CHAR(10)  
  
 SET @QueryString = @QueryString + N'ORDER BY paysource Collate SQL_Latin1_General_CP850_BIN, pattype, npi_flag desc, effdate desc' + CHAR(13) + CHAR(10)  
  
 PRINT @QueryString  
  
 -- exec the dynamic sql to return pps table  
 EXEC SP_EXECUTESQL @QueryString,  
      @ParameterList,  
      @FacilityID = @FacilityID,  
      @NPI = @NPI,  
      @Taxonomy = @Taxonomy,  
      @PayerID = @PayerID,  
      @PayerName = @PayerName,  
      @PricerTypeID = @PricerTypeID,  
      @FromDate = @FromDate,  
      @ToDate = @ToDate,  
      @InExportQueue = @InExportQueue,  
      @DTAPDID = @DTAPDID,  
      @pattype = @pattype  
  
END
GO
PRINT N'Altering Procedure [dbo].[SP_DTA_PaySource_Copy]...';


GO
-- ============================================================================      
-- Author:  Mrigank Khemka (copied from SP_DTA_PaySource_CopyDelete)   
-- Create date: 07/07/2023      
-- Description:      
-- This stored procedure is to COPY paysource and paysourcepricer data   
  
-- Modified: 09/27/2023  
-- US1109564: Copy - tempdb usage  
-- Replced the case statements with dynamic SQL query  
  
-- Modified: 12/07/2023  
-- US1127486: V2312.00 - Add new Pro pricer: Medicaid MS-DRG Pro - Rate and Metadata  
-- Added condition for Pro Pricer

-- Modified: 04/07/2026  
-- US1566826: V2604.00 - Add a New Physician Pro Payment System
-- Added condition for Pro Pricer 
/*******************************************************************************      
      
--Copy  Test Cases      
--Using Pricer Type: 36 = Medicare (CMS)      
---------------------------------------      
Case 1:      
declare @loginGuid uniqueidentifier      
set @loginGuid=newid()      
exec [SP_DTA_PaySource_Copy]  @FacilityID=NULL,@NPI=NULL,@Taxonomy=NULL,@PayerID='09',@PayerName=NULL,@PricerTypeID=-1,@DonotExport=NULL,@InExportQueue=0,@AdvFilterXml=NULL,@DTAPDID=0,@Abbr=NULL,@LoginSessionGUID=@loginGuid,@payer_idto='10',@dtToEffDate=n
ull    
Business Case:      
 All effective dates from Payer 09 records are copyied to new payer ID 10 records. Current functionality in SL & H5 won't copy TO a paysource that already exists.       
 This is expected functionality. Utilized by customers who want to create a custom rate suite using Optum's NMPRF or State Rate Files as a template.      
Result:      
 Creating new Payer ID      
---------------------------------------      
Case 2:      
declare @loginGuid uniqueidentifier      
set @loginGuid=newid()      
exec [SP_DTA_PaySource_Copy]  @loginGuid, null,87, null,'2019-7-1', '2019-10-1', 0      
Business Case:      
 Any CMS records with an effective date of 10012018 would create a new 02012019 record using the data from 10012018.       
 Utilized by customers who support custom rate files that include multiple Payer IDs for a single Pricer Type.       
 This would allow them to BULK add a new effective date for each Payer ID without going into the individual Payer ID record and manually creating one.      
Results:      
 Creating new effective date for existing Payer IDs      
---------------------------------------      
Case 3:      
declare @loginGuid uniqueidentifier        
set @loginGuid=newid()        
exec [SP_DTA_PaySource_Copy]  @loginGuid, '09', 36, '10','2018-10-1', '2019-2-2' 0      
Business Case:      
 CMS records with Payer ID 09 and effective date 10/1/2018, will be used to create a duplicate record using Payer ID 10 and effective date 02/02/2019.       
 This was existing functionality that would be used by customers to create custom rate record using Optum's NMPRF and State Rate File.       
 Mainly used for quick testing purposes. Virtually rendered obsolete due to Save-As functionality that was implemented. Still supported      
Results:      
 Creating new Payer ID using specific Payer ID      
---------------------------------------      
Case 4:      
declare @loginGuid uniqueidentifier        
set @loginGuid=newid()        
exec [SP_DTA_PaySource_Copy]  @loginGuid, '09', 36, '10','2018-10-1', '2019-2-3' 0      
Business Case:      
 CMS records with Payer ID 09 and effective date 10/1/2018, will be used to add a new 02/03/2019 effective date to all records with Payer ID 09.       
 The new 02/03/2019 effective date would only be added to CMS records with Payer ID 09.       
 This functionality is utilized by customers using the Optum NMPRF  and State Rate Files (larger data sets), that make custom changes to those rate records.        
Results:      
 Creating new effective date using a specific Payer ID      
---------------------------------------      
--UI validation, these case are handled in the UI, but documented here.      
Case 1:      
From PayerID:10, From Eff Date: Blank, Medicare (CMS), To Payer ID: Blank, To Eff Date: Blank; UI Validation Rule: "Copy TO Payer ID required".      
      
Case 2:      
From PayerID:10, From Eff Date: 10/1/2018, Medicare (CMS), To Payer ID: Blank, To Eff Date: Blank; UI Validation Rule: "Copy TO Effective Date required".      
      
Case 3:      
From PayerID: Blank, From Eff Date: Blank, Medicare (CMS), To Payer ID: Blank, To Eff Date: Blank; UI Validation Rule: "Both Effective Dates are required".      
********************************************************************************/  
ALTER PROCEDURE [dbo].[SP_DTA_PaySource_Copy] (@FacilityID varchar(16),  
@NPI varchar(10),  
@Taxonomy varchar(10),  
@PayerID varchar(13),  
@PayerName varchar(50),  
@PricerTypeID int,  
@DonotExport varchar(10),  
@InExportQueue bit = 0,  
@AdvFilterXml varchar(max) = NULL,  
@DTAPDID int = 0,  
@Abbr varchar(5),  
@EffectiveDate varchar(10) = '',  
@LoginSessionGUID uniqueidentifier,  
@payer_idto varchar(13),  
@dtToEffDate datetime = NULL,  
@DTABOID int = -1)  
  
AS  
BEGIN  
    SET NOCOUNT ON;  
    -- variables for try-catch          
    DECLARE @retVal AS int,  
            @errSeverity AS int,  
            @errMsg AS varchar(max),  
            @currentStep varchar(500),  
            @totalOfAllRecordsForDeletion int,  
            @copyFromXml varchar(max);  
  
    SET @totalOfAllRecordsForDeletion = 0  
    SET @retVal = 0  
  
    DECLARE @LoginUser varchar(500);  
    DECLARE @queryString nvarchar(max),  
            @ppsTable nvarchar(30),  
            @weightTable nvarchar(30);  
    DECLARE @DTAELID bigint;  
    DECLARE @weightIndex int,  
            @totalWeight int,  
            @LUTPTID_NewYorkMedicaidAPG_Enhanced int = 87,  
            @DTA_WeightData_RATENY varchar(21) = 'DTA_WeightData_RATENY',  
            @completionPercentage int = 0,  
            @ptCompletionPercentage float = 0,  
            @CurrentPtCount int = 0,  
            @TotalTblIDsForCopy int = 0,  
            @TotalCompletedTblIDsForCopy int = 0;  
    IF OBJECT_ID('tempdb..#tblIDsForCopy') IS NOT NULL  
    BEGIN  
        DROP TABLE #tblIDsForCopy  
    END  
    IF OBJECT_ID('tempdb..#tblCountPerLUTPTID') IS NOT NULL  
    BEGIN  
        DROP TABLE #tblCountPerLUTPTID  
    END  
    IF OBJECT_ID('tempdb..#PPS') IS NOT NULL  
    BEGIN  
        DROP TABLE #PPS  
    END  
    IF OBJECT_ID('tempdb..#Weight') IS NOT NULL  
    BEGIN  
        DROP TABLE #Weight  
    END  
    IF OBJECT_ID('tempdb..#LUTPTIDs') IS NOT NULL  
    BEGIN  
        DROP TABLE #LUTPTIDs  
    END  
    IF OBJECT_ID('tempdb..#copyfrom') IS NOT NULL  
    BEGIN  
        DROP TABLE #copyfrom  
    END  
    IF OBJECT_ID('tempdb..#tmpPS') IS NOT NULL  
    BEGIN  
        DROP TABLE #tmpPS  
    END  
    IF OBJECT_ID('tempdb..#tmpSamePayerIDPSP') IS NOT NULL  
    BEGIN  
        DROP TABLE #tmpSamePayerIDPSP  
    END  
    IF OBJECT_ID('tempdb..#tmpDifferentPayerIDPSP') IS NOT NULL  
    BEGIN  
        DROP TABLE #tmpDifferentPayerIDPSP  
    END  
    IF OBJECT_ID('tempdb..#DTA_PaySourcePricer') IS NOT NULL  
    BEGIN  
        DROP TABLE #DTA_PaySourcePricer  
    END  
    IF OBJECT_ID('tempdb..#DTA_PaySourcePricer_Blind') IS NOT NULL  
    BEGIN  
        DROP TABLE #DTA_PaySourcePricer_Blind  
    END  
    IF OBJECT_ID('tempdb..#tblIDsForCopyUnfiltered') IS NOT NULL  
    BEGIN  
        DROP TABLE #tblIDsForCopyUnfiltered  
    END  
    IF OBJECT_ID('tempdb..#tblIDsForDelete') IS NOT NULL  
    BEGIN  
        DROP TABLE #tblIDsForDelete  
    END  
    IF OBJECT_ID('tempdb..#DTA_PaySource') IS NOT NULL  
    BEGIN  
        DROP TABLE #DTA_PaySource  
    END  
    IF OBJECT_ID('tempdb..#tempWeightTables') IS NOT NULL  
    BEGIN  
        DROP TABLE #tempWeightTables  
    END  
    IF OBJECT_ID('tempdb..#DTAPSPIDtobeDeleted') IS NOT NULL  
    BEGIN  
        DROP TABLE #DTAPSPIDtobeDeleted  
    END  
    IF OBJECT_ID('tempdb..#tmpDTAPSPIDtobeDeleted') IS NOT NULL  
    BEGIN  
        DROP TABLE #tmpDTAPSPIDtobeDeleted  
    END  
    IF OBJECT_ID('tempdb..#DTAPSIDtobeDeleted') IS NOT NULL  
    BEGIN  
        DROP TABLE #DTAPSIDtobeDeleted  
    END  
    IF OBJECT_ID('tempdb..#LUTPTIDsForDelete') IS NOT NULL  
    BEGIN  
        DROP TABLE #LUTPTIDsForDelete  
    END      
    IF OBJECT_ID('tempdb..#tblDTAPSIDsForInsert') IS NOT NULL  
    BEGIN  
        DROP TABLE #tblDTAPSIDsForInsert  
    END  
  
    CREATE TABLE #tblIDsForCopy (  
        DTAPSID bigint,  
        DTAPSPID bigint,  
        facility_id varchar(16),  
        npi varchar(10),  
        taxonomy varchar(10),  
        LUTPTID int,  
        effdate datetime,  
        pattype varchar(2)  
    )  
  
    CREATE TABLE #tblIDsForCopyUnfiltered (  
        DTAPSID bigint,  
        DTAPSPID bigint,  
        facility_id varchar(16),  
        npi varchar(10),  
        taxonomy varchar(10),  
        LUTPTID int,  
        effdate datetime,  
        pattype varchar(2)  
    )  
  
    CREATE TABLE #DTA_PaySourcePricer_Blind (  
        LoginSessionGUID uniqueidentifier NULL,  
        LoginUser varchar(500) NULL,  
        facility_id varchar(16) NULL,  
        payer_id varchar(13) NULL,  
        npi varchar(10) NULL,  
        taxonomy varchar(10) NULL,  
        pricer_type varchar(2) NULL,  
        effdate datetime NULL,  
        field_name varchar(13) NULL,  
        old_value varchar(900) NULL,  
        new_value varchar(900) NULL,  
        LUTPTID int  
    )  
  
    CREATE TABLE #DTA_PaySourcePricer (  
        DTAPSPID bigint,  
        field_name varchar(13),  
        new_value varchar(900)  
    )  
  
    CREATE TABLE #DTA_PaySource (  
        DTAPSID bigint,  
        field_name varchar(13),  
        new_value varchar(900)  
    )  
  
    CREATE TABLE #copyfrom (  
        facility_id varchar(16) NULL,  
        payer_id varchar(13) NULL,  
        npi varchar(10) NULL,  
        taxonomy varchar(10) NULL,  
        DTAPSPID bigint,  
        CopiedFromDTAPSPID bigint,  
        EffDate date NULL  
    )  
  
  CREATE TABLE #tblIDsForDelete (  
    DTAPSID bigint,  
    DTAPSPID bigint,  
    LUTPTID int  
  )  
  
  CREATE TABLE #tblDTAPSIDsForInsert (  
    DTAPSID bigint  
  )  
  
    CREATE TABLE #tempWeightTables (  
        id bigint IDENTITY (1, 1),  
        WeightTableName varchar(50)  
    )  
  
    BEGIN TRY  
  
        RAISERROR ('Operation has begun.', 0, 1) WITH NOWAIT  
  
        SET @currentStep = 'Get login user name.'  
        EXEC sp_GetLoguser @LoginSessionGUID,  
                           @LoginUser OUT  
  
        --step 0 prepare all id for copying      
        RAISERROR ('Preparing data for processing.', 0, 1) WITH NOWAIT  
  
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 1  
  
        --    BEGIN;  
        INSERT INTO #tblIDsForCopyUnfiltered (DTAPSID, DTAPSPID, facility_id, npi, taxonomy, LUTPTID, effdate)  
        EXEC [SP_DTA_PaySourceRptSearch] @FacilityID,  
                                         @NPI,  
                                         @Taxonomy,  
                                         @PayerID,  
                                         @PayerName,  
                                         @PricerTypeID,  
                                         @DonotExport,  
                                         1,  
                                         NULL,  
                                         NULL,  
                                         NULL,  
                                         @InExportQueue,  
                                         @AdvFilterXml,  
                                         @DTAPDID,  
                                         @Abbr,  
                                         @EffectiveDate,  
                                         'DTAPSID, DTAPSPID, facility_id, npi, taxonomy, LUTPTID, effdate',  
                                         0,  
                                         1  
        --  END;  
          
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 20  
  
        -- cover case when this parameter value is set to not null, but empty string, which is not a valid date  
        IF (@dtToEffDate = '')  
            SET @dtToEffDate = NULL  
  
        IF (@dtToEffDate IS NOT NULL)  
        BEGIN  
            INSERT INTO #tblIDsForCopy (DTAPSID, DTAPSPID, facility_id, npi, taxonomy, LUTPTID, effdate, pattype)  
                SELECT  
                    tc.DTAPSID,  
                    tc.DTAPSPID,  
                    tc.facility_id,  
                    tc.npi,  
                    tc.taxonomy,  
                    tc.LUTPTID,  
                    tc.effdate,  
                    pt.pattype  
                FROM #tblIDsForCopyUnfiltered tc  
                LEFT OUTER JOIN #tblIDsForCopyUnfiltered tc2  
                    ON tc.DTAPSID = tc2.DTAPSID  
                    AND tc.effdate < tc2.effdate  
                JOIN DTA_PaySource pt  
                    ON pt.DTAPSID = tc.DTAPSID  
                WHERE tc2.DTAPSID IS NULL;  
        END  
        ELSE  
        BEGIN  
            INSERT INTO #tblIDsForCopy (DTAPSID, DTAPSPID, facility_id, npi, taxonomy, LUTPTID, effdate, pattype)  
                SELECT  
                    DTAPSID,  
                    DTAPSPID,  
                    facility_id,  
                    npi,  
                    taxonomy,  
                    tc.LUTPTID,  
                    effdate,  
                    pt.pattype  
                FROM #tblIDsForCopyUnfiltered tc  
                JOIN LUT_PricerType pt  
                    ON pt.LUTPTID = tc.LUTPTID  
        END  
          
        -----------------------------------------------------------------------------------------  
        --debug      
        --SELECT '#tblIDsForCopy' AS '#tblIDsForCopy', * FROM #tblIDsForCopy      
        --These indicies are critial for increasing the execution speed for later joins and where statements against this table.      
        --Need index only for copy operation      
        CREATE INDEX ix_DTAPSID ON #tblIDsForCopy (DTAPSID)  
        CREATE INDEX ix_DTAPSPID ON #tblIDsForCopy (DTAPSPID)  
        CREATE INDEX ix_FACILITY_ID ON #tblIDsForCopy (facility_id)  
        CREATE INDEX ix_NPI ON #tblIDsForCopy (npi)  
        CREATE INDEX ix_TAXONOMY ON #tblIDsForCopy (taxonomy)  
        CREATE INDEX ix_LUTPTID ON #tblIDsForCopy (LUTPTID)  
        CREATE INDEX ix_EFFDATE ON #tblIDsForCopy (effdate)  
        CREATE INDEX ix_PATTYPE ON #tblIDsForCopy (pattype)  
  
        DECLARE @DynamicQuery NVARCHAR(MAX) = ''  
        DECLARE @DynamicQueryParams  NVARCHAR(MAX) = N'@payer_idto varchar(13), @dtToEffDate DATETIME '  
  
      
       SET @DynamicQuery += 'INSERT INTO #tblIDsForDelete (DTAPSID, DTAPSPID, LUTPTID) ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '  SELECT ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    psp.DTAPSID, ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    psp.DTAPSPID, ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    psp.LUTPTID ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '  FROM #tblIDsForCopy copyfrom WITH (NOLOCK) ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '  INNER JOIN DTA_PaySourceAll_VW copyFromExtendedValues ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    ON copyFromExtendedValues.DTAPSID = copyfrom.DTAPSID ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '  INNER JOIN DTA_PaySourceAll_VW psp ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    ON psp.pattype = copyFromExtendedValues.pattype ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    AND psp.payer_id = ' + CHAR(13) + CHAR(10)  
       IF ISNULL(@payer_idto, '') = ''  
            SET @DynamicQuery += '    copyFromExtendedValues.payer_id ' + CHAR(13) + CHAR(10)  
       ELSE   
            SET @DynamicQuery += '    @payer_idto ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    AND psp.facility_id = copyfrom.facility_id ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    AND psp.npi = copyfrom.npi ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    AND psp.taxonomy = copyfrom.taxonomy ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += '    AND psp.effdate = ' + CHAR(13) + CHAR(10)  
       IF @dtToEffDate IS NULL  
            SET @DynamicQuery += ' copyfrom.effdate ' + CHAR(13) + CHAR(10)  
       ELSE  
            SET @DynamicQuery += ' @dtToEffDate ' + CHAR(13) + CHAR(10)  
       SET @DynamicQuery += ' GROUP BY psp.DTAPSID, psp.DTAPSPID, psp.LUTPTID ' + CHAR(13) + CHAR(10)  
       EXEC SP_EXECUTESQL @DynamicQuery,  
          @DynamicQueryParams,  
                            @payer_idto = @payer_idto,  
                            @dtToEffDate = @dtToEffDate  
    --WHERE psp.payer_id = @payer_idto        
    --debug       
    --select 'Line 142 #tblIDsForDelete' AS '#tblIDsForDelete', * from #tblIDsForDelete        
      
    EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
    @DTABOID = @DTABOID,    
    @LoginSessionGUID= @LoginSessionGUID,     
    @CompletionPercentage = 25  
  
    -- Clear out redundant copies  
    IF OBJECT_ID('tempdb..#SameDTAPSIDs') IS NOT NULL  
    BEGIN  
        DROP TABLE #SameDTAPSIDs  
    END  
  
    SELECT c.DTAPSID INTO #SameDTAPSIDs FROM #tblIDsForCopy c JOIN #tblIDsForDelete d ON c.DTAPSID = d.DTAPSID;  
    DELETE c FROM  #tblIDsForCopy c INNER JOIN #SameDTAPSIDs s ON c.DTAPSID = s.DTAPSID;  
    DELETE d FROM  #tblIDsForDelete d INNER JOIN #SameDTAPSIDs s ON d.DTAPSID = s.DTAPSID;  
  
  
    SELECT  
      @retVal = COUNT(1)  
    FROM #tblIDsForCopy  
    -->      
    --step 2.1: create tmp tables for deleting        
    CREATE TABLE #DTAPSPIDtobeDeleted (  
      DTAPSPID bigint  
    );  
    CREATE INDEX ix_DTAPSPID_ToBeDeleted ON #DTAPSPIDtobeDeleted (DTAPSPID)  
    CREATE TABLE #tmpDTAPSPIDtobeDeleted (  
      ROW_ID bigint IDENTITY (1, 1),  
      DTAPSPID bigint  
    );  
  
    CREATE UNIQUE CLUSTERED INDEX ix_ROW_ID ON #tmpDTAPSPIDtobeDeleted (ROW_ID)  
    CREATE TABLE #DTAPSIDtobeDeleted (  
      DTAPSID bigint,  
      TotalCount int  
    );  
  
    --step 2.2: create variables for deleting        
    DECLARE @indexfordelete int,  
            @totalLUTPTIDfordelete int,  
            @LUTPTIDfordelete int  
    SELECT  
      id = ROW_NUMBER() OVER (ORDER BY LUTPTID),  
      LUTPTID INTO #LUTPTIDsForDelete  
    FROM #tblIDsForDelete  
    GROUP BY LUTPTID  
  
    SELECT  
      @indexfordelete = 1,  
      @totalLUTPTIDfordelete = COUNT(1)  
    FROM #LUTPTIDsForDelete  
  
    --set 2.3: delete in a loop by LUTPTID      
    --BEGIN TRAN      
  
    EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all"  
  
    WHILE ISNULL(@indexfordelete, 0) <= ISNULL(@totalLUTPTIDfordelete, 0)  
    BEGIN  
      --step 2.3.1: initial the data      
      DELETE FROM #DTAPSIDtobeDeleted  
      DELETE FROM #DTAPSPIDtobeDeleted  
  
      SELECT  
        @LUTPTIDfordelete = LUTPTID  
      FROM #LUTPTIDsForDelete  
      WHERE id = @indexfordelete  
  
      --step 2.3.2-1: get the pps table and weight table name        
      SELECT  
        @ppsTable = pt.PricerTableName  
      FROM LUT_PricerType pt WITH (NOLOCK)  
      WHERE LUTPTID = @LUTPTIDfordelete  
        
      --get all weight tables      
      TRUNCATE TABLE #tempWeightTables  
      INSERT INTO #tempWeightTables  
        SELECT  
          wt.WeightTableName  
        FROM VW_LUT_PricerType_LUT_WeightType pt WITH (NOLOCK)  
        LEFT OUTER JOIN LUT_WeightType wt WITH (NOLOCK)  
          ON pt.LUTWTID = wt.LUTWTID  
        WHERE LUTPTID = @LUTPTIDfordelete  
        AND wt.LUTWTID IS NOT NULL  
  
      SELECT  
        @weightIndex = 1,  
        @totalWeight = COUNT(*)  
      FROM #tempWeightTables  
  
      SET @QueryString = ''  
      RAISERROR ('Reindexing %s table', 0, 1, @ppsTable) WITH NOWAIT  
      SET @QueryString = 'UPDATE STATISTICS ' + @ppsTable  
      EXECUTE (@QueryString)  
      PRINT @totalWeight  
      WHILE ISNULL(@weightIndex, 1) <= ISNULL(@totalWeight, 0)  
      BEGIN  
        SELECT  
          @weightTable = WeightTableName  
        FROM #tempWeightTables  
        WHERE id = @weightIndex  
        RAISERROR ('Reindexing %s table', 0, 1, @weightTable) WITH NOWAIT  
        SET @QueryString = 'UPDATE STATISTICS ' + @weightTable  
        EXECUTE (@QueryString)  
        SET @weightIndex = @weightIndex + 1  
      END  
  
      RAISERROR ('Delete data from table: %s', 0, 1, @ppsTable) WITH NOWAIT  
      -- set 2.3.3: populate tmp tables for deleting      
  
      INSERT INTO #tmpDTAPSPIDtobeDeleted  
        SELECT  
          DTAPSPID  
        FROM #tblIDsForDelete  
        WHERE LUTPTID = @LUTPTIDfordelete  
  
      INSERT INTO #DTAPSIDtobeDeleted  
        SELECT  
          psp.DTAPSID,  
          COUNT(psp.DTAPSID)  
        FROM DTA_PaySourceAll_VW psp WITH (NOLOCK)  
        INNER JOIN #tmpDTAPSPIDtobeDeleted idscopydelete WITH (NOLOCK)  
          ON idscopydelete.DTAPSPID = psp.DTAPSPID  
        GROUP BY psp.DTAPSID  
  
      --step 2.3.3: don't delete DTAPSID if they have more than one paysourcepricer        
      DELETE #DTAPSIDtobeDeleted  
        FROM #DTAPSIDtobeDeleted  
        INNER JOIN (SELECT  
          DTAPSID,  
          COUNT(DTAPSID) AS totalcount  
        FROM DTA_PaySourceAll_VW WITH (NOLOCK)  
        GROUP BY DTAPSID) AS psp  
          ON #DTAPSIDtobeDeleted.DTAPSID = psp.DTAPSID  
      WHERE #DTAPSIDtobeDeleted.TotalCount < psp.totalcount  
        
      --debug      
      --select '2-#DTAPSIDtobeDeleted' AS '#DTAPSIDtobeDeleted',* from #DTAPSIDtobeDeleted      
  
      --step 2.3.4: delete paysource, paysourcepricer, pps and weight data based table #DTAPSIDtobeDeleted and #DTAPSPIDtobeDeleted        
  
      DECLARE @startRowIndex int = 1;  
      DECLARE @lastRowIndex int = 10000;--2;      
      DECLARE @deleteRecordsPerLoop int = @lastRowIndex;  
      DECLARE @totalNumberOfRecords int;  
      DECLARE @indexCounter int = 1;  
      DECLARE @countForMessage int = 0  
      SET @totalNumberOfRecords = (SELECT  
        COUNT(*)  
      FROM #tmpDTAPSPIDtobeDeleted)  
        
      SET @totalOfAllRecordsForDeletion = @totalOfAllRecordsForDeletion + @totalNumberOfRecords;  
      IF (@totalOfAllRecordsForDeletion > 0)  
      BEGIN  
        --audit trail the DTA_PaySourcePricer          
        SET @currentStep = 'Insert into  DTA_AuditTrail from #DTAPSPIDtobeDeleted.'  
        DECLARE @count bigint,  
                @DTAPSID bigint  
  
        SELECT  
          @count = COUNT([LoginUser])  
        FROM DTA_PaySourcePricer psp  
        INNER JOIN #tmpDTAPSPIDtobeDeleted DTAPSPIDtobeDelted WITH (NOLOCK)  
          ON psp.DTAPSPID = DTAPSPIDtobeDelted.DTAPSPID  
  
        SELECT  
          @DTAPSID = DTAPSID  
        FROM DTA_PaySourcePricer psp  
        INNER JOIN #tmpDTAPSPIDtobeDeleted DTAPSPIDtobeDelted WITH (NOLOCK)  
          ON psp.DTAPSPID = DTAPSPIDtobeDelted.DTAPSPID  
  
        INSERT INTO #DTA_PaySourcePricer  
          SELECT  
          TOP 1  
            DTAPSPID,  
            'User Deleted' AS field_name,  
            ('Deleted ' + STR(@count) + ' Ratecalculator(s)') AS new_value  
          FROM #tmpDTAPSPIDtobeDeleted  
  
        IF (@dtToEffDate IS NOT NULL  
          AND @count <= 1)  
          EXEC sp_DTA_AuditTrail_Insert @LoginSessionGuid,  
                                        'UI'  
        ELSE  
        BEGIN  
          INSERT INTO #DTA_PaySourcePricer_Blind  
            SELECT  
            TOP 1  
              @LoginSessionGUID AS LoginSessionGUID,  
              @LoginUser AS LoginUser,  
              ps.facility_id,  
              ps.payer_id,  
              ps.npi,  
              ps.taxonomy,  
              pt.PricerTypeName AS pricer_type,  
              NULL AS effdate,  
              'User Deleted' AS field_name,  
              NULL AS old_value,  
              'Deleted ' + STR(@count) + ' Ratecalculator(s)' AS new_value,  
              psp.LUTPTID AS LUTPTID  
            FROM DTA_PaySourcePricer psp  
            INNER JOIN DTA_Paysource ps  
              ON psp.DTAPSID = ps.DTAPSID  
            INNER JOIN LUT_PricerType pt  
              ON psp.LUTPTID = pt.LUTPTID  
            WHERE psp.DTAPSID = @DTAPSID  
          --call proc sp_DTA_AuditTrail_Blind_Insert          
          EXEC sp_DTA_AuditTrail_Blind_Insert @LoginSessionGuid,  
                                              'UI'  
  
          DELETE FROM #DTA_PaySourcePricer  
          DELETE FROM #DTA_PaySourcePricer_Blind  
  
        END  
      END  
      SET @lastRowIndex = @startRowIndex + @deleteRecordsPerLoop  
      WHILE (@startRowIndex <= @totalNumberOfRecords)  
      BEGIN  
        BEGIN TRAN  
          IF @lastRowIndex >= @totalNumberOfRecords  
          BEGIN  
            SET @countForMessage = @totalNumberOfRecords  
          END  
          ELSE  
          BEGIN  
            SET @countForMessage = @lastRowIndex  
          END  
  
          RAISERROR ('Deleted a total of %d records from %d records', 0, 1, @countForMessage, @totalNumberOfRecords) WITH NOWAIT  
  
          INSERT INTO #DTAPSPIDtobeDeleted (DTAPSPID)  
            SELECT  
              DTAPSPID  
            FROM #tmpDTAPSPIDtobeDeleted  
            WHERE ROW_ID BETWEEN @startRowIndex AND @lastRowIndex  
            ORDER BY #tmpDTAPSPIDtobeDeleted.DTAPSPID  
  
          -- EXEC sp_DTA_PaySource_Delete_Internal @LoginSessionGuid, @ppsTable, @weightTable,@dtToEffDate       
  
          SET @queryString = ''  
          SET @QueryString = @QueryString + N'DECLARE @errMsg AS varchar(max), @errSeverity AS int, @currentStep varchar(50)' + CHAR(13) + CHAR(10)  
          SET @QueryString = @QueryString + N'BEGIN TRY' + CHAR(13) + CHAR(10)  
  
          IF (RTRIM(@ppsTable) <> '')  
          BEGIN  
            SET @QueryString = @QueryString + N'SET @currentStep = ''Delete existing data in PPS table.''' + CHAR(13) + CHAR(10)  
            SET @QueryString = @QueryString + N'DELETE pps FROM ' + @ppsTable + ' pps INNER JOIN #DTAPSPIDtobeDeleted DTAPSPIDtobeDelted with (nolock) ON pps.DTAPSPID = DTAPSPIDtobeDelted.DTAPSPID' + CHAR(13) + CHAR(10)  
          END  
  
          SET @weightIndex = 1  
          WHILE @weightIndex <= ISNULL(@totalWeight, 0)  
          BEGIN  
            SELECT  
              @weightTable = WeightTableName  
            FROM #tempWeightTables  
            WHERE id = @weightIndex  
            IF (@weightTable <> @DTA_WeightData_RATENY)  
            BEGIN  
              SET @QueryString = @QueryString + N'SET @currentStep = ''Delete existing data in Weight table.''' + CHAR(13) + CHAR(10)  
              SET @QueryString = @QueryString + N'DELETE weight FROM ' + @weightTable + ' weight INNER JOIN #DTAPSPIDtobeDeleted DTAPSPIDtobeDelted with (nolock) ON weight.DTAPSPID = DTAPSPIDtobeDelted.DTAPSPID' + CHAR(13) + CHAR(10)  
            END  
            SET @weightIndex = @weightIndex + 1  
          END  
          SET @QueryString = @QueryString + N'END TRY' + CHAR(13) + CHAR(10)  
          SET @QueryString = @QueryString + N'BEGIN CATCH ' + CHAR(13) + CHAR(10)  
          SET @QueryString = @QueryString + N'   SELECT @errSeverity = ERROR_SEVERITY(), @errMsg = ERROR_MESSAGE()' + CHAR(13) + CHAR(10)  
          SET @QueryString = @QueryString + N'   EXEC SP_DTA_EventLog_Insert_SP ''' + CAST(@LoginSessionGUID AS varchar(36)) + ''', ''[SP_PaySourceDelete_' + ISNULL(@ppsTable, '') + '_' + ISNULL(@weightTable, '') + ']'', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT,      
            
     @currentStep' + CHAR(13) + CHAR(10)  
          SET @QueryString = @QueryString + N'END CATCH  ' + CHAR(13) + CHAR(10)  
          EXECUTE (@QueryString)  
  
          DELETE psp  
            FROM DTA_PaySourcePricer psp  
            INNER JOIN #DTAPSPIDtobeDeleted DTAPSPIDtobeDelted WITH (NOLOCK)  
              ON psp.DTAPSPID = DTAPSPIDtobeDelted.DTAPSPID  
  
          DELETE FROM #DTAPSPIDtobeDeleted  
  
          SET @startRowIndex = @deleteRecordsPerLoop * @indexCounter  
          SET @lastRowIndex = @startRowIndex + @deleteRecordsPerLoop  
          SET @startRowIndex = @startRowIndex + 1;  
          SET @indexCounter = @indexCounter + 1;  
        COMMIT TRAN  
      END  
  
      SET @indexfordelete = @indexfordelete + 1  
    END  
      
    EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]  
    @DTABOID = @DTABOID,  
    @LoginSessionGUID= @LoginSessionGUID,  
    @CompletionPercentage = 30  
    -- delete data from DTA_PaySource          
    IF OBJECT_ID('tempdb..#DTAPSIDtobeDeleted') IS NOT NULL  
    BEGIN  
      SET @currentStep = 'Insert into  DTA_AuditTrail from #DTAPSIDtobeDeleted.'  
      SELECT  
        @count = COUNT(ps.[DTAPSID])  
      FROM DTA_PaySource ps  
      INNER JOIN #DTAPSIDtobeDeleted tempt WITH (NOLOCK)  
        ON ps.[DTAPSID] = tempt.[DTAPSID]  
  
      INSERT INTO #DTA_PaySource  
        SELECT TOP 1  
          DTAPSID,  
          'User Deleted' AS field_name,  
          ('Deleted ' + STR(@count) + ' Paysource(s)') AS new_value  
        FROM #DTAPSIDtobeDeleted  
      EXEC sp_DTA_AuditTrail_Insert @LoginSessionGuid,  
                                    'UI'  
  
      SET @currentStep = 'Delete data from DTA_PaySource.'  
      DELETE ps  
        FROM DTA_PaySource ps  
        INNER JOIN #DTAPSIDtobeDeleted DTAPSIDtobeDelted WITH (NOLOCK)  
          ON ps.DTAPSID = DTAPSIDtobeDelted.DTAPSID  
      -- clean up          
      IF OBJECT_ID('tempdb..#DTA_PaySource') IS NOT NULL  
      BEGIN  
        DROP TABLE #DTA_PaySource  
      END  
    END  
      
    --DELETE ps FROM DTA_PaySource ps INNER JOIN #DTAPSIDtobeDeleted DTAPSIDtobeDelted with (nolock) ON ps.DTAPSID = DTAPSIDtobeDelted.DTAPSID          
  
    IF (@totalOfAllRecordsForDeletion > 0)  
    BEGIN  
      RAISERROR ('Total number of records deleted %d', 0, 1, @totalOfAllRecordsForDeletion) WITH NOWAIT  
    END  
    ELSE  
    BEGIN  
      RAISERROR ('No records needed to be deleted.', 0, 1, @totalOfAllRecordsForDeletion) WITH NOWAIT  
    END  
    --if @globalTotal > 0 then show records to be deleted.      
    --else show records to be deleted.      
    --        
    --RAISERROR ('Deleting of is done.', 0, 1) WITH NOWAIT      
    --step 5: copy         
    --5.0 update existing pay source      
    RAISERROR ('Preparing data to be copied.', 0, 1) WITH NOWAIT  
    IF ISNULL(@payer_idto, '') = ''  
    BEGIN  
        UPDATE DTA_PaySource  
        SET [LoginSessionGUID] = @LoginSessionGUID,  
            [CopiedFromDTAPSID] = copyfrom.DTAPSID  
        FROM #tblIDsForCopy copyfrom WITH (NOLOCK)  
        INNER JOIN DTA_PaySource copyfromExtendedValues  
          ON copyfromExtendedValues.DTAPSID = copyfrom.DTAPSID  
        INNER JOIN DTA_PaySource  
          ON DTA_PaySource.[facility_id] = copyfrom.[facility_id]  
          AND DTA_PaySource.[npi] = copyfrom.[npi]  
          AND DTA_PaySource.[taxonomy] = copyfrom.[taxonomy]  
          AND DTA_PaySource.[payer_id] = copyfromExtendedValues.payer_id  
          AND DTA_PaySource.[pattype] = copyfromExtendedValues.[pattype]  
      END  
      ELSE  
      BEGIN  
          UPDATE DTA_PaySource  
        SET [LoginSessionGUID] = @LoginSessionGUID,  
            [CopiedFromDTAPSID] = copyfrom.DTAPSID  
        FROM #tblIDsForCopy copyfrom WITH (NOLOCK)  
        INNER JOIN DTA_PaySource copyfromExtendedValues  
          ON copyfromExtendedValues.DTAPSID = copyfrom.DTAPSID  
        INNER JOIN DTA_PaySource  
          ON DTA_PaySource.[facility_id] = copyfrom.[facility_id]  
          AND DTA_PaySource.[npi] = copyfrom.[npi]  
          AND DTA_PaySource.[taxonomy] = copyfrom.[taxonomy]  
          AND DTA_PaySource.[payer_id] = @payer_idto   
          AND DTA_PaySource.[pattype]  = copyfromExtendedValues.[pattype]  
      END  
  
  
      --5.1 get the DTAPSIDs for insert    
      IF ISNULL(@payer_idto, '') = ''  
      BEGIN  
        INSERT INTO #tblDTAPSIDsForInsert (DTAPSID)  
            SELECT   
                copyfrom.DTAPSID  
            FROM #tblIDsForCopy copyfrom  
            LEFT OUTER JOIN DTA_PaySource ps WITH (NOLOCK)  
                ON copyFrom.DTAPSID = ps.CopiedFromDTAPSID  
                AND ps.payer_id = ps.payer_id  
            WHERE ps.CopiedFromDTAPSID IS NULL  
            GROUP BY copyfrom.DTAPSID  
        END  
        ELSE  
        BEGIN  
            INSERT INTO #tblDTAPSIDsForInsert (DTAPSID)  
            SELECT   
                copyfrom.DTAPSID  
            FROM #tblIDsForCopy copyfrom  
            LEFT OUTER JOIN DTA_PaySource ps WITH (NOLOCK)  
                ON copyFrom.DTAPSID = ps.CopiedFromDTAPSID  
                AND ps.payer_id = @payer_idto  
            WHERE ps.CopiedFromDTAPSID IS NULL  
            GROUP BY copyfrom.DTAPSID  
        END  
  
  
        --debug      
        --select '#tblDTAPSIDsForInsert' AS '#tblDTAPSIDsForInsert', * from #tblDTAPSIDsForInsert      
          
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 35  
        --5.2 DTA_PaySource      
        IF (ISNULL(@payer_idto, '') <> '')  
        BEGIN  
            SELECT  
                @LoginSessionGUID AS LoginSessionGUID,  
                @LoginUser AS LoginUser,  
                [facility_id],  
                @payer_idto AS payer_id,  
                [npi],  
                [taxonomy],  
                [pattype],  
                [npi_flag],  
                [LUTPSCID],  
                ps.DTAPSID AS 'CopiedFromDTAPSID',  
                [date_flag],  
                [paysource_name],  
                [abbrev_name],  
                GETDATE() AS 'InsertedTS',  
                1 AS [Enabled],  
                InExportQueue INTO #tmpPS  
            FROM dbo.DTA_PaySource ps WITH (NOLOCK)  
            INNER JOIN #tblDTAPSIDsForInsert idinsert  
                ON ps.DTAPSID = idinsert.DTAPSID  
  
            INSERT INTO dbo.DTA_PaySource ([LoginSessionGUID], [LoginUser], [facility_id],  
            [payer_id], [npi], [taxonomy], [pattype], [npi_flag], [LUTPSCID],  
            [CopiedFromDTAPSID], [date_flag], [paysource_name], [abbrev_name], [InsertedTS]  
            , [Enabled], InExportQueue)  
                SELECT  
                    *  
                FROM #tmpPS  
            RAISERROR ('Copying of data for Pay source done.', 0, 1) WITH NOWAIT  
            -- log        
  
            EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
                                             'SP_DTA_PaySource_Copy',  
                                             NULL,  
                                             'Insert into pay source',  
                                             @@ROWCOUNT,  
                                             @DTAELID OUT  
            SELECT  
                ps.[DTAPSID],  
                psp.LUTPTID,  
                @LoginSessionGUID AS 'LoginSessionGUID',  
                @LoginUser AS 'LoginUser',  
                [DoNotExport],  
                [SharedWeightDTAPSPID],  
                psp.[DTAPSPID],  
                [version],  
                (CASE  
                    WHEN @dtToEffDate IS NULL THEN copyfrom.effdate  
                    ELSE @dtToEffDate  
                END) AS 'effdate',  
                [tab_filename],  
                [havewt],  
                [grpr_type],  
                [grpr_vers],  
                [grpr_date],  
                [pricer_type],  
                [icd9_map],  
                [edit_date],  
                [dsc_flag],  
                [poa_flag],  
                [hac_flag],  
                [hac_override_id],  
                [oce_flag],  
                [ocewp_flag],  
                [nonoce_flag],  
                [lcd_flag],  
                [map_override_id],  
                [map_category],  
                [map_type],  
                [ace_override_id],  
                [closed_fac_sw],  
                [bwgt_option],  
                [disch_drg_option],  
                [hac_version],  
                [CCIRequest_flag],  
                [CCIBypass_flag],  
                [PhysicianEdit_flag],  
                [reimbdate],  
                [TRICAREOPPS],  
                [asc_override_id],  
                [paysrc_notes],  
                [sqr_flag],  
                psp.[StateCCIValue],  
                psp.[user_key],  
                psp.[pay_except],  
                psp.[line_bypass],  
                psp.icd9_routing,  
                psp.apc_override_id,  
                psp.[vers_qual],  
                psp.[edit_req2],  
                psp.[analyzer_type],  
                psp.[analyzer_type_rsvd],  
                psp.[analyzer_vers],  
                psp.[analyzer_vers_rsvd],  
                psp.[start_lvl_option1],  
                psp.[start_lvl_option2],  
                psp.[start_lvl_option3],  
                psp.[start_lvl_option4],  
                psp.[start_lvl_option5],  
                psp.[lvl_change_option],  
                psp.[edc_action],  
                psp.[facility_type],  
                psp.[rf_vers],  
                psp.[LUTWTID],  
                psp.[PhysEdit_MaxDME],  
                psp.[moe_flag],  
                psp.[mcd_override_id],  
                psp.[cah_oce_flag], -- new column Din  
				psp.[othermedicare_flag],
                psp.[ppc_vers],
                psp.[phys_rule_override_id],
                psp.[phys_code_override_id]
            INTO #tmpDifferentPayerIDPSP  
            FROM dbo.DTA_PaySource ps WITH (NOLOCK)  
            INNER JOIN DTA_PaySourcePricer psp WITH (NOLOCK)  
                ON ps.CopiedFromDTAPSID = psp.DTAPSID  
            INNER JOIN #tblIDsForCopy copyfrom  
                ON psp.DTAPSPID = copyfrom.DTAPSPID  
            WHERE ps.payer_id = @payer_idto  
  
            INSERT INTO DTA_PaySourcePricer ([DTAPSID], [LUTPTID], [LoginSessionGUID], [LoginUser], [DoNotExport], [SharedWeightDTAPSPID],  
            [CopiedFromDTAPSPID], [version],  
            [effdate],  
            [tab_filename], [havewt], [grpr_type], [grpr_vers], [grpr_date],  
            [pricer_type], [icd9_map], [edit_date], [dsc_flag], [poa_flag], [hac_flag], [hac_override_id]  
            , [oce_flag], [ocewp_flag], [nonoce_flag], [lcd_flag], [map_override_id], [map_category]  
            , [map_type], [ace_override_id], [closed_fac_sw], [bwgt_option], [disch_drg_option], [hac_version]  
            , [CCIRequest_flag], [CCIBypass_flag], [PhysicianEdit_flag], [reimbdate]  
            , [TRICAREOPPS], [asc_override_id], [paysrc_notes], [sqr_flag], [StateCCIValue]  
            , [user_key], [pay_except], [line_bypass], [icd9_routing], [apc_override_id], [vers_qual], [edit_req2]  
            , [analyzer_type], [analyzer_type_rsvd], [analyzer_vers], [analyzer_vers_rsvd]  
            , [start_lvl_option1], [start_lvl_option2], [start_lvl_option3], [start_lvl_option4], [start_lvl_option5]  
            , [lvl_change_option], [edc_action], [facility_type], [rf_vers], [LUTWTID], [PhysEdit_MaxDME], [moe_flag], [mcd_override_id], [cah_oce_flag],[othermedicare_flag], [ppc_vers], [phys_rule_override_id], [phys_code_override_id]       
            )  
                SELECT  
                    *  
                FROM #tmpDifferentPayerIDPSP  
            RAISERROR ('Copying of data for Pay source pricer done.', 0, 1) WITH NOWAIT  
        END  
        ELSE  
        BEGIN  
            SELECT  
                ps.[DTAPSID],  
                psp.LUTPTID,  
                @LoginSessionGUID AS 'LoginSessionGUID',  
                @LoginUser AS 'LoginUser',  
                [DoNotExport],  
                [SharedWeightDTAPSPID],  
                psp.[DTAPSPID],  
                [version],  
                (CASE  
                    WHEN @dtToEffDate IS NULL THEN copyfrom.effdate  
                    ELSE @dtToEffDate  
                END) AS 'effdate',  
                [tab_filename],  
                [havewt],  
                [grpr_type],  
                [grpr_vers],  
                [grpr_date],  
                [pricer_type],  
                [icd9_map],  
                [edit_date],  
                [dsc_flag],  
                [poa_flag],  
                [hac_flag],  
                [hac_override_id],  
                [oce_flag],  
                [ocewp_flag],  
                [nonoce_flag],  
                [lcd_flag],  
                [map_override_id],  
                [map_category],  
                [map_type],  
                [ace_override_id],  
                [closed_fac_sw],  
                [bwgt_option],  
                [disch_drg_option],  
                [hac_version],  
                [CCIRequest_flag],  
                [CCIBypass_flag],  
                [PhysicianEdit_flag],  
                [reimbdate],  
                [TRICAREOPPS],  
                [asc_override_id],  
                [paysrc_notes],  
                [sqr_flag],  
                psp.[StateCCIValue],  
                psp.[user_key],  
                psp.[pay_except],  
                psp.[line_bypass],  
                psp.icd9_routing,  
                psp.apc_override_id,  
                psp.vers_qual,  
                psp.[edit_req2],  
                psp.[analyzer_type],  
                psp.[analyzer_type_rsvd],  
                psp.[analyzer_vers],  
                psp.[analyzer_vers_rsvd],  
                psp.[start_lvl_option1],  
                psp.[start_lvl_option2],  
                psp.[start_lvl_option3],  
                psp.[start_lvl_option4],  
                psp.[start_lvl_option5],  
                psp.[lvl_change_option],  
                psp.[edc_action],  
                psp.[facility_type],  
                psp.[rf_vers],  
                psp.[LUTWTID],  
                psp.[PhysEdit_MaxDME],  
                psp.[moe_flag],  
                psp.[mcd_override_id],  
                psp.[cah_oce_flag], -- new column Din    
				psp.[othermedicare_flag],
                psp.ppc_vers,
                psp.phys_rule_override_id,
                psp.phys_code_override_id
            INTO #tmpSamePayerIDPSP  
            FROM dbo.DTA_PaySource ps WITH (NOLOCK)  
            INNER JOIN DTA_PaySourcePricer psp WITH (NOLOCK)  
                ON ps.DTAPSID = psp.DTAPSID  
            INNER JOIN #tblIDsForCopy copyfrom  
                ON psp.DTAPSPID = copyfrom.DTAPSPID  
            --WHERE ps.payer_id =  
            --                   CASE  
            --                       WHEN ISNULL(@payer_idto, '') = '' THEN ps.payer_id  
            --                       ELSE @payer_idto  
            --                   END  
  
            INSERT INTO DTA_PaySourcePricer ([DTAPSID], [LUTPTID], [LoginSessionGUID], [LoginUser], [DoNotExport], [SharedWeightDTAPSPID],  
            [CopiedFromDTAPSPID], [version],  
            [effdate],  
            [tab_filename], [havewt], [grpr_type], [grpr_vers], [grpr_date],  
            [pricer_type], [icd9_map], [edit_date], [dsc_flag], [poa_flag], [hac_flag], [hac_override_id]  
            , [oce_flag], [ocewp_flag], [nonoce_flag], [lcd_flag], [map_override_id], [map_category]  
            , [map_type], [ace_override_id], [closed_fac_sw], [bwgt_option], [disch_drg_option], [hac_version]  
            , [CCIRequest_flag], [CCIBypass_flag], [PhysicianEdit_flag], [reimbdate]  
            , [TRICAREOPPS], [asc_override_id], [paysrc_notes], [sqr_flag], [StateCCIValue]  
            , [user_key], [pay_except], [line_bypass], [icd9_routing], [apc_override_id], [vers_qual], [edit_req2]  
            , [analyzer_type], [analyzer_type_rsvd], [analyzer_vers], [analyzer_vers_rsvd]  
            , [start_lvl_option1], [start_lvl_option2], [start_lvl_option3], [start_lvl_option4], [start_lvl_option5]  
            , [lvl_change_option], [edc_action], [facility_type], [rf_vers], [LUTWTID], [PhysEdit_MaxDME], [moe_flag], [mcd_override_id], [cah_oce_flag],[othermedicare_flag], [ppc_vers], [phys_rule_override_id], [phys_code_override_id]    
            )  
                SELECT  
                    *  
                FROM #tmpSamePayerIDPSP  
  
            RAISERROR ('Copying of data for pay source pricer done.', 0, 1) WITH NOWAIT  
  
        END  
        --5.3 insert into DTA_PaySourcePricer       
          
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 55  
        -- return value        
        --SET @retVal = @@ROWCOUNT       
  
        -- log        
        EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
                                         'SP_DTA_PaySource_Copy',  
                                         NULL,  
                                         'Insert into Pay Source Pricer.',  
                                       @retVal,  
                                         @DTAELID OUT  
  
        --5.4 get the pair of DTAPSPID, and CopiedFromDTAPSPID which need to be inserted into PPS and weight table  
        SET @DynamicQuery  = ''  
        SET @DynamicQueryParams  = N'@payer_idto varchar(13), @dtToEffDate DATETIME '  
        SET @DynamicQuery += 'INSERT INTO #copyfrom ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '    SELECT ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ps.facility_id, ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ps.payer_id, ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ps.npi, ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ps.taxonomy, ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        psp.DTAPSPID, ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        psp.CopiedFromDTAPSPID, ' + CHAR(13) + CHAR(10)  
        IF @dtToEffDate IS NULL  
        BEGIN  
            SET @DynamicQuery += '    psp.effdate AS ''effdate'' ' + CHAR(13) + CHAR(10)  
        END  
        ELSE  
        BEGIN  
            SET @DynamicQuery += '    @dtToEffDate AS ''effdate'' ' + CHAR(13) + CHAR(10)  
        END  
        SET @DynamicQuery += '    FROM DTA_PaySource ps WITH (NOLOCK) ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '    INNER JOIN DTA_PaySourcePricer psp WITH (NOLOCK) ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ON ps.DTAPSID = psp.DTAPSID ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '    INNER JOIN #tblIDsForCopy idscopydelete ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '        ON psp.CopiedFromDTAPSPID = idscopydelete.DTAPSPID ' + CHAR(13) + CHAR(10)  
        SET @DynamicQuery += '    WHERE ps.payer_id = ' + CHAR(13) + CHAR(10)  
  
        IF ISNULL(@payer_idto, '') = ''  
        BEGIN  
            SET @DynamicQuery += ' ps.payer_id ' + CHAR(13) + CHAR(10)  
        END  
        ELSE  
        BEGIN  
            SET @DynamicQuery += ' @payer_idto ' + CHAR(13) + CHAR(10)  
        END  
  
        SET @DynamicQuery += '    AND psp.effdate = ' + CHAR(13) + CHAR(10)  
  
        IF @dtToEffDate IS NULL  
        BEGIN  
            SET @DynamicQuery += ' psp.effdate ' + CHAR(13) + CHAR(10)  
        END  
        ELSE  
        BEGIN  
            SET @DynamicQuery += ' @dtToEffDate ' + CHAR(13) + CHAR(10)  
        END  
  
        EXEC SP_EXECUTESQL @DynamicQuery,  
      @DynamicQueryParams,  
                        @payer_idto = @payer_idto,  
                        @dtToEffDate = @dtToEffDate  
        --debug      
        --select '#copyfrom' AS '#copyfrom', * from #copyfrom      
  
        --5.5 get the PricerTableName and WeightTableName  
  
        select LUTPTID, COUNT(1) as [count]  
        INTO #tblCountPerLUTPTID  
        FROM #tblIDsForCopy  
        GROUP BY LUTPTID  
  
        DECLARE @index int,  
                @totalLUTPTID int,  
                @LUTPTID int  
        SELECT  
            id = ROW_NUMBER() OVER (ORDER BY LUTPTID),  
            LUTPTID, [count] INTO #LUTPTIDs  
        FROM #tblCountPerLUTPTID  
  
        SELECT  
            @index = 1,  
            @totalLUTPTID = COUNT(1),  
            @TotalTblIDsForCopy = SUM([count])  
        FROM #LUTPTIDs  
          
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 65  
        --set 2.3: copy pricing section data (PPS tables) in a loop by LUTPTID      
        --BEGIN TRAN      
  
        WHILE ISNULL(@index, 0) <= ISNULL(@totalLUTPTID, 0)  
        BEGIN  
            --step 2.3.1: initial the data      
            SELECT  
                @LUTPTID = LUTPTID,  
                @CurrentPtCount = [count]  
            FROM #LUTPTIDs  
            WHERE id = @index  
  
            SET @ptCompletionPercentage = 0;  
            SET @completionPercentage =    CAST( ( ( CAST(@TotalCompletedTblIDsForCopy AS FLOAT) +   
                                                    ( CAST(@CurrentPtCount AS FLOAT) * @ptCompletionPercentage ) )   
                                                / CAST(@TotalTblIDsForCopy AS FLOAT)  
                                              * 30 ) AS INT ) + 65  
              
            EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
            @DTABOID = @DTABOID,    
            @LoginSessionGUID= @LoginSessionGUID,     
            @CompletionPercentage = @completionPercentage  
              
            SELECT  
                @ppsTable = pt.PricerTableName  
            FROM LUT_PricerType pt WITH (NOLOCK)  
            WHERE LUTPTID = @LUTPTID  
  
            --5.6 copy into PPS table     
            DECLARE @Columns nvarchar(max) = ''  
            DECLARE @ParameterList nvarchar(50) = N'  @EffDate DATE '  
            IF @LUTPTID = 84  
                OR @LUTPTID = 86  
    OR @LUTPTID = 96  
    OR @LUTPTID = 98 -- We should exclude columns logic for Medicaid APR-DRG and Pro and DRG Pro  
                SET @Columns = ', pps.* '  
            ELSE  
            IF (ISNULL(@dtToEffDate, 0) = 0)  --US1049340: Build columns sql in such a way that, if field is with in display start and end date, then it's default value should be used.  
                SELECT  
                    @Columns = COALESCE(@Columns + ' , ' + REPLACE(ColumnQuery, '##ColumnName##', 'pps.' + ColumnName), ColumnQuery)  
                FROM udf_GetPpsTableColumns(@LUTPTID, NULL)  
                ORDER BY ColumnOrder  
            ELSE  
                SELECT  
                    @Columns = COALESCE(@Columns + ' , ' + REPLACE(ColumnQuery, '##ColumnName##', 'pps.' + ColumnName), ColumnQuery)  
                FROM udf_GetPpsTableColumns(@LUTPTID, @dtToEffDate)  
                ORDER BY ColumnOrder  
              
            SET @queryString = ''  
            SET @QueryString = @QueryString + N'SELECT psp.DTAPSPID as NewDTAPSPID ' + @Columns + ' INTO #PPS FROM ' + @ppsTable + ' pps WITH (NOLOCK) INNER JOIN #copyfrom psp WITH (NOLOCK) ON psp.CopiedFromDTAPSPID = pps.DTAPSPID' + CHAR(13) + CHAR(10)  
            SET @QueryString = @QueryString + N'ALTER TABLE #PPS DROP COLUMN PPSID, DTAPSPID' + CHAR(13) + CHAR(10)  
            SET @QueryString = @QueryString + N'INSERT INTO ' + @ppsTable + ' SELECT * FROM #PPS' + CHAR(13) + CHAR(10)  
  
            EXEC SP_EXECUTESQL @QueryString,  
                               @ParameterList,  
                               @EffDate = @dtToEffDate  
  
            RAISERROR ('Copying of data for %s done.', 0, 1, @ppsTable) WITH NOWAIT  
            -- log        
            SET @ptCompletionPercentage = 0.25;  
            SET @completionPercentage =    CAST( ( ( CAST(@TotalCompletedTblIDsForCopy AS FLOAT) +   
                                                    ( CAST(@CurrentPtCount AS FLOAT) * @ptCompletionPercentage ) )   
                                                / CAST(@TotalTblIDsForCopy AS FLOAT)  
                                              * 30 ) AS INT ) + 65  
              
            EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
            @DTABOID = @DTABOID,    
            @LoginSessionGUID= @LoginSessionGUID,     
            @CompletionPercentage = @completionPercentage  
              
            EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
                                             'SP_DTA_PaySource_Copy',  
                                             NULL,  
                                             'Insert into PPS table.',  
                                             @@ROWCOUNT,  
                                             @DTAELID OUT  
  
            -- US691044: Copy old fields values to new across given eff date      
            EXEC [dbo].[sp_DTA_CopyPPSFieldsFromOldToNew]  
            SET @ptCompletionPercentage = 0.50;  
            SET @completionPercentage =    CAST( ( ( CAST(@TotalCompletedTblIDsForCopy AS FLOAT) +   
                                                    ( CAST(@CurrentPtCount AS FLOAT) * @ptCompletionPercentage ) )   
                                                / CAST(@TotalTblIDsForCopy AS FLOAT)  
                                              * 30 ) AS INT ) + 65  
              
            EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
            @DTABOID = @DTABOID,    
            @LoginSessionGUID= @LoginSessionGUID,     
            @CompletionPercentage = @completionPercentage  
              
            -- This block will recalculate the calculated field values  
            IF @LUTPTID = 36  
                OR @LUTPTID = 41 -- Medicare DRG and Tricare/Champus  
            BEGIN  
                DECLARE @DTAPSPIDs dbo.DTAPSPIDTableType  
                INSERT INTO @DTAPSPIDs (DTAPSPID)  
                    SELECT  
                        DTAPSPID  
                    FROM #copyfrom  
  
                EXEC [SP_DTA_Pricer_Calculate_CalculatedFieldsValues] @LUTPTID,  
                                                                      @DTAPSPIDs  
            END  
  
            --5.6 copy into weight table       
            TRUNCATE TABLE #tempWeightTables  
            INSERT INTO #tempWeightTables  
                SELECT  
                    wt.WeightTableName  
                FROM VW_LUT_PricerType_LUT_WeightType pt WITH (NOLOCK)  
                LEFT OUTER JOIN LUT_WeightType wt WITH (NOLOCK)  
                    ON pt.LUTWTID = wt.LUTWTID  
                WHERE LUTPTID = @LUTPTID  
                AND wt.LUTWTID IS NOT NULL  
  
            IF (@LUTPTID = @LUTPTID_NewYorkMedicaidAPG_Enhanced)  
            BEGIN  
                INSERT INTO #tempWeightTables  
                    VALUES (@DTA_WeightData_RATENY)  
            END  
  
            SELECT  
                @weightIndex = 1,  
                @totalWeight = COUNT(*)  
            FROM #tempWeightTables  
  
            WHILE ISNULL(@weightIndex, 1) <= ISNULL(@totalWeight, 0)  
            BEGIN  
  
                SELECT  
                    @weightTable = WeightTableName  
                FROM #tempWeightTables  
                WHERE id = @weightIndex  
  
                IF OBJECT_ID('tempdb..#Weight') IS NOT NULL  
                BEGIN  
                    DROP TABLE #Weight  
                END  
  
                SET @queryString = ''  
                IF (@weightTable <> @DTA_WeightData_RATENY)  
                BEGIN  
                    SET @QueryString = @QueryString + N'SELECT psp.DTAPSPID as NewDTAPSPID, weight.* INTO #Weight FROM ' + @weightTable + ' weight WITH (NOLOCK) INNER JOIN #copyfrom psp WITH (NOLOCK) ON psp.CopiedFromDTAPSPID = weight.DTAPSPID' + CHAR(13) + CHAR(10)  
                    SET @QueryString = @QueryString + N'ALTER TABLE #Weight DROP COLUMN DTAWDID, DTAPSPID' + CHAR(13) + CHAR(10)  
                    SET @QueryString = @QueryString + N'INSERT INTO ' + @weightTable + ' SELECT * FROM #Weight' + CHAR(13) + CHAR(10)  
                END  
                ELSE  
                IF (@weightTable = @DTA_WeightData_RATENY  
                    AND ISNULL(@payer_idto, '') <> '')  
                BEGIN  
                    SET @copyFromXml = (SELECT  
                        ROW_NUMBER() OVER (ORDER BY facility_id ASC) AS RowNumber,  
                        ISNULL(RTRIM(LTRIM(facility_id)), '') AS facility_id,  
                        ISNULL(RTRIM(LTRIM(payer_id)), '') AS payer_id,  
                        ISNULL(RTRIM(LTRIM(npi)), '') AS npi,  
                        ISNULL(RTRIM(LTRIM(taxonomy)), '') AS taxonomy,  
                        ISNULL(MIN(CopiedFromDTAPSPID), 0) AS CopiedFromDTAPSPID  
                    FROM #copyfrom  
                    GROUP BY facility_id,  
                             payer_id,  
                             npi,  
                             taxonomy  
                    FOR xml PATH ('row'), ROOT ('PaySourceData'))  
                    EXEC sp_DTA_WeightDataRateNY_COPY @copyFromXml,  
                                                      @LoginSessionGUID  
       END  
  
                EXECUTE (@QueryString)  
                IF (@weightTable IS NOT NULL)  
                BEGIN  
                    RAISERROR ('Copying of data for %s done.', 0, 1, @weightTable) WITH NOWAIT  
                END  
                -- log        
                EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
                                                 'SP_DTA_PaySource_Copy',  
                                                 NULL,  
                                                 'Insert into Weight table.',  
                                                 @@ROWCOUNT,  
                                                 @DTAELID OUT  
                SET @weightIndex = @weightIndex + 1  
            END  
            SET @ptCompletionPercentage = 0.85;  
            SET @completionPercentage =    CAST( ( ( CAST(@TotalCompletedTblIDsForCopy AS FLOAT) +   
                                                    ( CAST(@CurrentPtCount AS FLOAT) * @ptCompletionPercentage ) )   
                                                / CAST(@TotalTblIDsForCopy AS FLOAT)  
                                              * 30 ) AS INT ) + 65  
              
            EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
            @DTABOID = @DTABOID,    
            @LoginSessionGUID= @LoginSessionGUID,     
            @CompletionPercentage = @completionPercentage  
              
            -- move the weight data to new table       
            IF (@LUTPTID = 13  
                OR @LUTPTID = 14) --Amy: hard code for now, we can make this dynamic if we have more      
            BEGIN  
                DECLARE @dtaidsToBeMove AS dbo.DTAPSPIDTableType  
                INSERT INTO @dtaidsToBeMove (DTAPSPID)  
                    SELECT  
                        DTAPSPID  
                    FROM #copyfrom  
                EXEC [sp_DTA_WeightData_MoveToNew] @LoginSessionGUID,  
                                                   @dtaidsToBeMove  
            END  
              
            SET @ptCompletionPercentage = 1;  
            SET @completionPercentage =    CAST( ( ( CAST(@TotalCompletedTblIDsForCopy AS FLOAT) +   
                                                    ( CAST(@CurrentPtCount AS FLOAT) * @ptCompletionPercentage ) )   
                                                / CAST(@TotalTblIDsForCopy AS FLOAT)  
                                              * 30 ) AS INT ) + 65  
              
            EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
            @DTABOID = @DTABOID,    
            @LoginSessionGUID= @LoginSessionGUID,     
            @CompletionPercentage = @completionPercentage  
              
            SET @currentStep = 'Commiting tran for inserting.'  
              
            SET @TotalCompletedTblIDsForCopy = @TotalCompletedTblIDsForCopy + @CurrentPtCount;  
            SET @index = @index + 1;  
  
        END  
  
  
  
        EXEC sp_msforeachtable "ALTER TABLE ? CHECK CONSTRAINT all"  
  
        --COMMIT TRAN           
  
        --step 6: new code        
        SET @currentStep = 'Insert into  DTA_AuditTrail from #DTA_PaySourcePricer_Blind.'  
        DECLARE @DTAPSPID bigint,  
                @copydelete char(11)--,@DTAPSID bigint        
        SET @copydelete = 'User Copied'  
  
        --create table #DTA_PaySourcePricer_Blind and insert the data          
        SELECT  
            @DTAPSPID = DTAPSPID,  
            @DTAPSID = DTAPSID  
        FROM #tblIDsForCopy  
  
        INSERT INTO #DTA_PaySourcePricer  
            SELECT  
                DTAPSPID,  
                @copydelete AS field_name,  
                ('To PayerID "' + @payer_idto + '" copied ' + STR(COUNT(1)) + ' record(s)') AS new_value  
            FROM #tblIDsForCopy  
            GROUP BY DTAPSPID  
  
  
        INSERT INTO #DTA_PaySourcePricer_Blind  
            SELECT  
                @LoginSessionGUID AS LoginSessionGUID,  
                @LoginUser AS LoginUser,  
                ps.facility_id,  
                ps.payer_id,  
                ps.npi,  
                ps.taxonomy,  
                pt.PricerTypeName AS pricer_type,  
                NULL AS effdate,  
                field_name,  
                NULL AS old_value,  
                new_value,  
                psp.LUTPTID AS LUTPTID  
            FROM DTA_PaySourcePricer psp  
            INNER JOIN DTA_Paysource ps  
                ON psp.DTAPSID = ps.DTAPSID  
            INNER JOIN LUT_PricerType pt  
                ON psp.LUTPTID = pt.LUTPTID  
            INNER JOIN #DTA_PaySourcePricer tmppsp  
                ON psp.DTAPSPID = tmppsp.DTAPSPID  
            WHERE psp.DTAPSID = @DTAPSID  
  
        --call proc sp_DTA_AuditTrail_Blind_Insert        
        EXEC sp_DTA_AuditTrail_Blind_Insert @LoginSessionGuid,  
                                            'UI'  
        --end new code       
  
        EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID,  
                                         'SP_DTA_PaySource_Copy',  
                                         NULL,  
                                         'Copied Total',  
                                         @retVal,  
                                         @DTAELID OUT  
                                           
        RAISERROR ('Reindexing Pay source pricer', 0, 1) WITH NOWAIT  
        UPDATE STATISTICS DTA_PaySourcePricer  
        RAISERROR ('Reindexing Pay source', 0, 1) WITH NOWAIT  
        UPDATE STATISTICS DTA_PaySource  
  
        EXEC [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]     
        @DTABOID = @DTABOID,    
        @LoginSessionGUID= @LoginSessionGUID,     
        @CompletionPercentage = 100,  
        @OperationStatus = N'Completed'  
  
        -- return          
        --SELECT @retVal AS TOTALCOUNT FOR XML RAW('RESULTS')        
        DECLARE @reValMsg varchar(70)  
        SET @reValMsg = 'Rate Manager - Copied: ' + CAST(@retVal AS varchar(7)) + '.'  
        RAISERROR (@reValMsg, 0, 1) WITH NOWAIT  
        RAISERROR ('Operation is done.', 0, 1) WITH NOWAIT  
    END TRY  
    BEGIN CATCH  
        PRINT ERROR_MESSAGE();  
        SELECT  
            @errSeverity = ERROR_SEVERITY(),  
            @errMsg = ERROR_MESSAGE()  
  
        EXECUTE [dbo].[sp_DTA_BatchOperationStack_UpdateColumns]    @DTABOID,  
                                                                    @LoginSessionGUID= @LoginSessionGUID,     
                                                                    @OperationStatus = 'Error',  
                                                                    @StatusMessage = @errMsg  
  
        EXEC dbo.[SP_DTA_EventLog_Insert_SP] @LoginSessionGUID,  
                                             '[SP_DTA_PaySource_Copy]',  
                                             @@ERROR,  
                                             @errSeverity,  
                                             @errMsg,  
                                             @@TRANCOUNT,  
                                             @currentStep  
    END CATCH  
END
GO
PRINT N'Refreshing Procedure [dbo].[SP_Import_ratexxx_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Import_ratexxx_Update]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_WeightData_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_WeightData_Update]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_AuditTrail_Insert]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_AuditTrail_Insert]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_AuditTrail_Insert_IM]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_AuditTrail_Insert_IM]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_PaySource_Delete_Internal]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_PaySource_Delete_Internal]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_PaySource_Delete_Internal_byIDs]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_PaySource_Delete_Internal_byIDs]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceSharedWeight_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceSharedWeight_Save]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_Pricer_Calculate_CalculatedFieldsValues]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_Pricer_Calculate_CalculatedFieldsValues]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Import_ratexxx]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Import_ratexxx]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_CopyPPSFieldsFromOldToNew]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_CopyPPSFieldsFromOldToNew]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_GetPricerTypeByDTAPDID]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_GetPricerTypeByDTAPDID]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_GetSharedWeightsRecordsCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_GetSharedWeightsRecordsCount]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_Ids_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_Ids_Get]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourcePricer_GetHistoryInfo]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourcePricer_GetHistoryInfo]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceRatesRptSearch_Internal]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceRatesRptSearch_Internal]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceSharedWeightSearch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceSharedWeightSearch]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_WeightData_MoveToNew]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_WeightData_MoveToNew]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_WeightListEditor]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_WeightListEditor]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_WeightListEditor_APC]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_WeightListEditor_APC]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Dynamic_WeightListDetails_xml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Dynamic_WeightListDetails_xml]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_GetRateFileNames]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_GetRateFileNames]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_PricerTypeDetailsRpt]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_PricerTypeDetailsRpt]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Import_GetDTAPSPTMPIMCID]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Import_GetDTAPSPTMPIMCID]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_LUT_Dynamic_WeightData_xml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_LUT_Dynamic_WeightData_xml]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_LUT_PricerType_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_LUT_PricerType_Get]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_LUT_PricerTypeVariable_Fields_GetXml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_LUT_PricerTypeVariable_Fields_GetXml]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_RateCalculator_Weight]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_RateCalculator_Weight]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_TML_PricerPageTL_ForPTDetailRpt_GetXml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_TML_PricerPageTL_ForPTDetailRpt_GetXml]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_TML_PricerPageTL_GetXml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_TML_PricerPageTL_GetXml]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_AuditTrail_Insert_PS]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_AuditTrail_Insert_PS]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_GetDTAPSID]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_GetDTAPSID]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_medext]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_medext]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_payxxx]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_payxxx]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceSearch_xml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceSearch_xml]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_Import_medext_UpdatePaySourceByPref]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_Import_medext_UpdatePaySourceByPref]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceRptSearch_Internal]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceRptSearch_Internal]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceSearch_PricerType]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceSearch_PricerType]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_Save]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_Delete]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_PaySourceRatesRpt]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_PaySourceRatesRpt]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_medxxx]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_medxxx]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_rateny]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_rateny]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Export_PaySourceRpt]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Export_PaySourceRpt]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySourceRptSearch_TotalCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySourceRptSearch_TotalCount]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_AuditTrailRateItems_GetXml]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_AuditTrailRateItems_GetXml]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_LUT_RateEditingMapping_GetByLUTPTID]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_LUT_RateEditingMapping_GetByLUTPTID]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Import_ClearTemp]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Import_ClearTemp]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_EditAll_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_EditAll_Save]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_PPS_tables_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_PPS_tables_Save]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_GlobalEdit_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_GlobalEdit_Delete]';


GO
PRINT N'Refreshing Procedure [dbo].[sp_DTA_PaySourcePricer_Copy]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[sp_DTA_PaySourcePricer_Copy]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_GlobalEditorDoNotExport_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_GlobalEditorDoNotExport_Update]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_Import_medext]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_Import_medext]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_PaySource_SaveAs]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_PaySource_SaveAs]';


GO
PRINT N'Update complete.';


GO


GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2605.01', N'2605.01', NULL, GETDATE())

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

    --US1598134: V2605.01 - Contract APC - Default Value Update
    UPDATE LUT_PricerTypeVariable SET 
    DefaultValue = '1.0000', 
    [ModifiedTS]='20260521 00:00:00.000' 
    WHERE LUTPTVID = 4509

    --US1598744: Medicare SNF
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'Indicator used to request fee schedule pricing for SNF Part B items. Check this box to request fee schedule pricing. If you do not want fee schedule pricing, do not check this box and do not complete the remaining fee schedule fields below (SEQ F.2 – SEQ K.3).' 
    WHERE LUTPTVID = 1034

    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'A 2% reduction will apply to all Medicare payments per the Protecting Medicare andAmerican Farmers from Sequester Cuts Act, which required a mandatory reduction in Federal spending also known as sequestration. To apply this reduction, the Markup\Discount Factor Part B (SEQ E.2) can be set as shown above. Since this reduction only applies to the Medicare payments and not to the patient co-payments, this reduction needs to be removed from the Ambulance co-payment by dividing the Ambulance co-payment factor by 0.9800.

The Ambulance co-payment factor can be set in one of three different ways:
1. Enter 0.0000 if co-payment is not desired.
2. Enter 0.2000 if the standard 20% co-payment is desired and sequester reductions have not been applied.
3. Enter 0.2041 (0.2000/0.9800) if the standard 20% co-payment is desired and sequester reductions have been applied.' 
    WHERE LUTPTVID = 1039
    
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000',
    VariableDescr = N'A 2% reduction will apply to all Medicare payments per the Protecting Medicare and American Farmers from Sequester Cuts Act, which required a mandatory reduction in Federal spending also known as sequestration. To apply this reduction, the Markup\Discount Factor Part B (SEQ E.2) can be set as shown above. Since this reduction only applies to the Medicare payments and not to the patient co-payments, this reduction needs to be removed from the DMEPOS co-payment by dividing the DMEPOS co-payment factor by 0.9800.

The DMEPOS co-payment factor can be set in one of three different ways:
1. Enter 0.0000 if co-payment is not desired.
2. Enter 0.2000 if the standard 20% co-payment is desired and sequester reductions have not been applied.
3. Enter 0.2041(0.2000/0.9800) if the standard 20% co-payment is desired and sequester reductions have been applied.' 
    WHERE LUTPTVID = 1042
    
    
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'A 2% reduction will apply to all Medicare payments per the Protecting Medicare and American Farmers from Sequester Cuts Act, which required a mandatory reduction in Federal spending also known as sequestration. To apply this reduction, the Markup\Discount Factor Part B (SEQ E.2) can be set as shown above. Since this reduction only applies to the Medicare payments and not to the patient co-payments, this reduction needs to be removed from the National co-payment by dividing the National co-payment factor by 0.9800.

The National co-payment factor can be set in one of three different ways:
1. Enter 0.0000 if co-payment is not desired.
2. Enter 0.2000 if the standard 20% co-payment is desired and sequester reductions have not been applied.
3. Enter 0.2041 (0.2000/0.9800) if the standard 20% co-payment is desired and sequester reductions have been applied.' 
    WHERE LUTPTVID = 1048
    
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'A 2% reduction will apply to all Medicare payments per the Protecting Medicare and American Farmers from Sequester Cuts Act, which required a mandatory reduction in Federal spending also known as sequestration. To apply this reduction, the Markup\Discount Factor Part B (SEQ E.2) can be set as shown above. Since this reduction only applies to the Medicare payments and not to the patient co-payments, this reduction needs to be removed from the Physician co-payment by dividing the Physician co-payment factor by 0.9800.

The Physician co-payment factor can be set in one of three different ways:
1. Enter 0.0000 if co-payment is not desired.
2. Enter 0.2000 if the standard 20% co-payment is desired and sequester reductions have not been applied.
3. Enter 0.2041 (0.2000/0.9800) if the standard 20% co-payment is desired and sequester reductions have been applied.' 
    WHERE LUTPTVID = 1051

    --US1598744: Medicare ASC
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'Used to specify the payment factor for colonoscopy and sigmoidoscopy screenings.

Note: Set to 1.0000 if co-payment is not desired. If both SEQ F.6 and SEQ F.7 are set to 0.0000, the Contract ASC Pricer will default this field to 0.7500.' 
    WHERE LUTPTVID = 3460
    
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'Used to specify the co-payment factor for colonoscopy and sigmoidoscopy screenings.

Note: Set to 0.0000 if co-payment is not desired. If both SEQ F.6 and SEQ F.7 are set to 0.0000, the Contract ASC Pricer will default this field to 0.2500.' 
    WHERE LUTPTVID = 3461
    
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'If total payment is to be reduced or increased by a standard factor, enter that factor here. This adjustment will be applied to payment at the line level. If no reduction or increase is appropriate, set this field to 1.0000.
This factor is applied to all lines unless an exclusion flag is set in SEQ H.1 to SEQ H.20.' 
    WHERE LUTPTVID = 2252

    --US1598744: Medicare APC
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    DefaultValue = '1.0000',
    VariableDescr = N'Enter the mandated reduction factor if this facility did not meet the OPPS quality reporting requirements.

Note: This factor will not be applied unless Met Quality Standards (SEQ E.5) is unchecked, indicating that a facility has not met CMS quality reporting requirements. For facilities that have met CMS quality reporting requirements, this field will not have an impact on reimbursement.' 
    WHERE LUTPTVID = 114

    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'The implantable device Ratio of Costs-to-Charges (RCCs). If available, this figure is used to calculate reimbursement for services assigned to Payment Status Indicator H (Pass-Through Device Categories) or Payment Status Indicator H1 (Non-Opioid Medical Devices for Post-Surgical Pain Relief). If not available, the outpatient RCC (SEQ H.1) is used.' 
    WHERE LUTPTVID = 3430

    --US1598744: New York Medicaid Psychiatric Exempt
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'The facility-specific add-on amount for Safety Net hospitals or facilities that have been identified as financially distressed. This add-on amount is applied for each day of the stay.

Note: This add-on payment applies only to claims from MMC payers for certain psychiatric services during approved time periods.' 
    WHERE LUTPTVID = 4317

    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'The facility-specific Average Commercial Rate (ACR) add-on amount for facilities that are part of the NY Health and Hospitals Corporation (HHC). This add-on amount is applied for each day of the stay.

This add-on payment applies only to claims from MMC payers for certain psychiatric services.' 
    WHERE LUTPTVID = 4518

    --US1598744: New York Medicaid APR-DRG
    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'The base rate as specified by the NYSDOH. Do not apply Wage Equalization Factor (WEF) or Indirect Medical Education (IME) adjustments to this base rate.

Medicaid Managed Care (MMC) rates provided by the NYSDOH contain the following three fields:

-Discharge Rate - "DEFAULT & CONTRACT" DISCHARGE CASE PAYMENT RATE (INCLUDING PHL § 2807-c(33) - Excluding IME)
-Statewide Price - MA HMO - "DEFAULT & CONTRACT" STATEWIDE BASE PRICE (INCLUDING PHL § 2807-c(33))
-ISAF - INSTITUTION SPECIFIC ADJUSTMENT FACTOR' 
    WHERE LUTPTVID = 2105

    UPDATE LUT_PricerTypeVariable SET 
    [ModifiedTS]='20260521 00:00:00.000', 
    VariableDescr = N'Facility-specific, per discharge add-on amount for Safety Net Hospitals or facilities that have been identified as financially distressed.

Note: This add-on payment applies only to claims from MMC payers for certain newborn, maternity, and medical/surgical services during approved time periods.' 
    WHERE LUTPTVID = 4316

    --US1599743: Virginia Medicaid APG Pro - State Procedure Updates
    INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (85, 86, N'VA', N'Virginia', CAST(N'2025-07-01T00:00:00.000' AS DateTime), 7, 1)
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 19, 1, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 20, 2, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 37, 3, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 51, 4, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 21, 5, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 22, 6, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 52, 7, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 72, 8, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 83, 9, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 23, 10, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 25, 11, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 26, 12, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 118, 13, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 39, 14, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 65, 15, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 152, 16, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 58, 17, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 27, 18, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 28, 19, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 29, 20, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 30, 21, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 31, 22, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 32, 23, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 24, 24, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 71, 25, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 33, 26, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 73, 27, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 34, 28, CAST(N'2026-05-21T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (85, 53, 29, CAST(N'2026-05-21T00:00:00.000' AS DateTime))

    -- US1596565 - V2605.01 - Physician Pro and Medicare Physician Pricer - UI and State Procedure Updates
    UPDATE LUT_PricerType SET ShowAnalyzing = 0 WHERE lutptid = 65
    UPDATE LUT_RateEditingMapping SET [MappingVisible] = 0,  [grpr_dateVisible] = 0  WHERE lutptid = 65
    

    UPDATE LUT_PricerType SET ShowAnalyzing = 0 WHERE lutptid = 98
    UPDATE LUT_RateEditingMapping SET [MappingVisible] = 0,  [grpr_dateVisible] = 0  WHERE lutptid = 98
    UPDATE LUT_RateEditingMapping SET [grpr_dateVisible] = 1 WHERE lutptid NOT IN (65, 98)
    UPDATE LUT_PricerTypeVariable SET LabelOnUI = 'Status Code Pricing:', [ModifiedTS] = '20260521 00:00:00.000' WHERE lutptvid = 4520
    UPDATE LUT_PricerTypeVariable SET LabelOnUI = 'Payer:', [ModifiedTS] = '20260521 00:00:00.000' WHERE lutptvid = 4521

    DELETE FROM LUT_PricerTypeAPRPro_StateProcedure where lutsid = 82 
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 260, 1, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 001
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 264, 2, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 005
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 266, 3, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 007
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 265, 4, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 006
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 263, 5, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 004
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 261, 6, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 002
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 286, 7, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 100
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 317, 8, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 131
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 296, 9, CAST(N'2026-05-21T00:00:00.000' AS DateTime))  -- PCode: 110
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 262, 10, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 003
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 297, 11, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 111
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 268, 12, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 051
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 269, 13, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 052
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 285, 14, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 068
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 366, 15, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 180
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 292, 16, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 106
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 272, 17, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 055
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 280, 18, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 063
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 367, 19, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 181
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 284, 20, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 067
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 273, 21, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 056
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 274, 22, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 057
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 298, 23, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 112
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 287, 24, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 101
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 281, 25, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 064
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 293, 26, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 107
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 294, 27, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 108
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 299, 28, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 113
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 275, 29, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 058
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 306, 30, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 120
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 276, 31, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 059
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 267, 32, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 050
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 277, 33, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 060
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 270, 34, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 053
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 271, 35, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 054
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 278, 36, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 061
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 289, 37, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 103
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 279, 38, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 062
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 288, 39, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 102
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 307, 40, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 121
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 309, 41, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 123
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 315, 42, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 129
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 316, 43, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 130
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 318, 44, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 132
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 319, 45, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 133
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 322, 46, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 136
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 321, 47, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 135
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 320, 48, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 134
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 304, 49, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 118
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 305, 50, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 119
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 295, 51, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 109
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 351, 52, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 165
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 314, 53, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 128
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 283, 54, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 066
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 308, 55, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 122
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 323, 56, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 137
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 328, 57, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 142
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 329, 58, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 143
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 330, 59, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 144
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 331, 60, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 145
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 332, 61, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 146
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 334, 62, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 148
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 335, 63, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 149
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 336, 64, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 150
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 337, 65, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 151
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 339, 66, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 153
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 341, 67, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 155
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 364, 68, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 178
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 356, 69, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 170
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 358, 70, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 172
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 359, 71, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 173
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 360, 72, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 174
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 361, 73, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 175
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 301, 74, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 115
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 324, 75, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 138
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 325, 76, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 139
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 310, 77, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 124
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 312, 78, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 126
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 282, 79, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 065
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 344, 80, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 158
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 343, 81, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 157
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 342, 82, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 156
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 340, 83, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 154
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 345, 84, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 159
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 346, 85, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 160
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 347, 86, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 161
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 348, 87, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 162
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 349, 88, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 163
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 350, 89, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 164
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 352, 90, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 166
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 338, 91, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 152
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 327, 92, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 141
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 326, 93, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 140
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 353, 94, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 167
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 354, 95, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 168
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 355, 96, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 169
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 290, 97, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 104
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 357, 98, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 171
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 363, 99, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 177
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 362, 100, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 176
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 365, 101, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 179
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 302, 102, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 116
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 303, 103, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 117
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 368, 104, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 182
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 311, 105, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 125
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 291, 106, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 105
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 370, 107, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 184
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 313, 108, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 127
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 300, 109, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 114
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 333, 110, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 147
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 369, 111, CAST(N'2026-05-21T00:00:00.000' AS DateTime)) -- PCode: 183

    -- US1596692 - V2605.01 - Physician Pro and Medicare Physician Pricer - Physician Override ID Integration
   INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10865, 98, N'E', N'phys_rule_override_id', 22, N'Physician Edit Override ID', N'The Physician Edit Override ID invokes override functionality. The Edit Override functionality allows the user to turn particular Physician Edits on or off.

Note: This is an optional field; refer to the EASYGroup™ Technical Reference Guide for further information. This field should be entered in all uppercase letters.', N'1', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'TEXT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260521 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10866, 98, N'E', N'phys_code_override_id', 23, N'Physician Override ID', N'The Physician Code Override ID invokes override functionality. This override functionality allows the user to override effective dates, Status Codes, and maximum allowable units assignment for a particular procedure code. If this field is left blank, the Physician Code Override ID (SEQ xx) will be utilized.

Note: This is an optional field; please refer to the EASYGroup™ Technical Reference Guide for further information.', N'1', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'TEXT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260521 00:00:00.000', NULL, N'U', 1, N'0')
    
     INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10867, 65, N'E', N'phys_rule_override_id', 22, N'Physician Edit Override ID', N'The Physician Edit Override ID invokes override functionality. The Edit Override functionality allows the user to turn particular Physician Edits on or off.

Note: This is an optional field; refer to the EASYGroup™ Technical Reference Guide for further information. This field should be entered in all uppercase letters.', N'1', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'TEXT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260521 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10868, 65, N'E', N'phys_code_override_id', 23, N'Physician Override ID', N'The Physician Code Override ID invokes override functionality. This override functionality allows the user to override effective dates, Status Codes, and maximum allowable units assignment for a particular procedure code. If this field is left blank, the Physician Code Override ID (SEQ xx) will be utilized.

Note: This is an optional field; please refer to the EASYGroup™ Technical Reference Guide for further information.', N'1', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'TEXT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260521 00:00:00.000', NULL, N'U', 1, N'0')

    UPDATE [dbo].[LUT_RateEditingMapping] SET [phys_rule_override_idVisible]=1, [phys_code_override_idVisible]=1 WHERE [LUTREMID]=27
    UPDATE [dbo].[LUT_RateEditingMapping] SET [phys_rule_override_idVisible]=1, [phys_code_override_idVisible]=1 WHERE [LUTREMID]=70

    INSERT [dbo].[LUT_PaySourceVariable] ([LUTPSVID], [Section], [pattype], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [LabelOnUI], [DefaultValue], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [Enabled], [InsertedTS], [ModifiedTS], [LUTPTID]) VALUES (77, N'E', NULL, N'phys_rule_override_id', N'Physician Edit Override ID', N'TEXT', NULL, NULL, N'X20', N'Physician Edit Override ID', NULL, NULL, NULL, NULL, NULL, 1, '20260521 00:00:00.000', NULL, NULL)
    INSERT [dbo].[LUT_PaySourceVariable] ([LUTPSVID], [Section], [pattype], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [LabelOnUI], [DefaultValue], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [Enabled], [InsertedTS], [ModifiedTS], [LUTPTID]) VALUES (78, N'E', NULL, N'phys_code_override_id', N'Physician Code Override ID', N'TEXT', NULL, NULL, N'X20', N'Physician Override ID', NULL, NULL, NULL, NULL, NULL, 1, '20260521 00:00:00.000', NULL, NULL)

    INSERT [dbo].[LUT_RateEditingLabel] ([LUTRELID], [VariableName], [LabelOnUI], [LUTREMColumn]) VALUES (45, N'phys_rule_override_id', N'Physician Edit Override ID', N'phys_rule_override_idVisible')
    INSERT [dbo].[LUT_RateEditingLabel] ([LUTRELID], [VariableName], [LabelOnUI], [LUTREMColumn]) VALUES (46, N'phys_code_override_id', N'Physician Override ID', N'phys_code_override_idVisible')

    INSERT [dbo].[LUT_ReportFieldMapping] ([LUTRPMID], [ReportField], [ReportDbMapping]) VALUES (49, N'phys_rule_override_id_report', N'psp.phys_rule_override_id AS [Physician Edit Override ID]')
    INSERT [dbo].[LUT_ReportFieldMapping] ([LUTRPMID], [ReportField], [ReportDbMapping]) VALUES (50, N'phys_code_override_id_report', N'psp.phys_code_override_id AS [Physician Override ID]')

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
