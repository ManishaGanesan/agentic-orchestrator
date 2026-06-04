USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v250500 to V250501.
Run this script on [RateManager] v250500 to upgrade it to [RateManager] V250501.
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
SET @FromDVersion = '2505.00'; -- the DVersion in the database
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

GO
    PRINT N'Altering Table [dbo].[PPS_nyapgeprc_45]...';

    GO
    IF NOT EXISTS (
      SELECT 1 
      FROM   sys.columns 
      WHERE  object_id = OBJECT_ID(N'[dbo].[PPS_nyapgeprc_45]') 
             AND name = 'econsult_adj'
    )
    BEGIN
	    ALTER TABLE [dbo].[PPS_nyapgeprc_45] ADD econsult_adj  VARCHAR (200) NULL;
END

GO

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
    psp.[rf_vers],
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

-- =======================================================================  
-- Author: Raghu Malladi  
-- Create date: 09/02/2020  
-- Description:   
-- 1. This sp is for pay source report page and will select from VW_PaySourceRptSearch  
--    data based on the advanced search criteria  
-- 2. if @TotalCount is null, this sp will return  the data  
--  else will return the total records  
-- 20230705.DE254893.Vadim		Return only columns from VW_DTA_PaySourceRptSearch
-- 20230717.DE254874.Vadim		Allow retrieving only data summary 
-- 20230803.US1084850.Mani		Removed PATINDEX from order by to improve performance
-- ========================================================================    
/*********************************************************************************************
DECLARE @XmlStr VARCHAR(MAX), @iDoc AS INT
SET @XmlStr = 
'<AdvanceSearchDetails>
	<AdvancedSearchDetail>
		<Condition>AND</Condition>
		<VariableLabel>Name</VariableLabel>
		<ComparisonLabel>Equals</ComparisonLabel>
		<InputUILable>LEE MEMORIAL HEALTH SYSTE</InputUILable>
		<DTADID>0</DTADID>
		<DTAID>0</DTAID>
		<SearchType>Config</SearchType>
		<LUTPTID></LUTPTID>
		<VariableName>paysource_name</VariableName>
		<ComparisonName>=</ComparisonName>
		<InputVariable></InputVariable>
		<InputValue>LEE MEMORIAL HEALTH SYSTE</InputValue>
		<InputVariableLabel></InputVariableLabel>
		<VariableTypeAndName>TEXT;paysource_name</VariableTypeAndName>
		<InputValueForSP>LEE MEMORIAL HEALTH SYSTE</InputValueForSP>
		<ConditionDescription>AND Name Equals LEE MEMORIAL HEALTH SYSTE</ConditionDescription>
	</AdvancedSearchDetail>
	<AdvancedSearchDetail>
		<Condition>AND</Condition>
		<VariableLabel>Payer ID</VariableLabel>
		<ComparisonLabel>Is greater than or equal to</ComparisonLabel>
		<InputUILable>20</InputUILable>
		<DTADID>0</DTADID>
		<DTAID>0</DTAID>
		<SearchType>Config</SearchType>
		<LUTPTID></LUTPTID>
		<VariableName>payer_id</VariableName>
		<ComparisonName>&gt;=</ComparisonName>
		<InputVariable></InputVariable>
		<InputValue>20</InputValue>
		<InputVariableLabel></InputVariableLabel>
		<VariableTypeAndName>TEXT;payer_id</VariableTypeAndName>
		<InputValueForSP>20</InputValueForSP>
		<ConditionDescription>AND Payer ID Is greater than or equal to 20</ConditionDescription>
	</AdvancedSearchDetail>
</AdvanceSearchDetails>'
EXEC	[dbo].[SP_DTA_PaySourceRptSearch]
		@FacilityID = NULL,
		@NPI = NULL,
		@Taxonomy = NULL,
		@PayerID = NULL,
		@PayerName = NULL,
		@PricerTypeID = -1,
		@DonotExport = NULL,
		@CurrentPage = 1,
		@RecsPerPage = 25,
		@ColumnName = N'facility_id',
		@SortOrder = N'Asc',
		@InExportQueue = 0,
		@AdvFilterXml = @XmlStr,
		@DTAPDID = 0
***************************************************************************************/

ALTER PROCEDURE [dbo].[SP_DTA_PaySourceRptSearch_Advance] (
@ColumnName nvarchar(50) = null, 
@SortOrder nvarchar(10) = null,
@FacilityID varchar(50), 
@NPI varchar(50), 
@Taxonomy varchar(50),
@PayerID varchar(50), 
@PayerName varchar(50), 
@PricerTypeID int,
@DoNotExport varchar(10), 
@FirstRec int,
@LastRec int, 
@RecsPerPage int = NULL, 
@TotalPages int OUTPUT,
@TotalCount int OUT, 
@AdvFilterXml varchar(max) = NULL,
@DTAPDID int = 0,
@IsExport bit,
@Abbr varchar(5),
@EffectiveDate varchar(10) = '',
@ColumnList varchar(max) = NULL,
@IsSummaryOnly bit = 1,
@ExcludePricerTypes bit = 0
)
AS
BEGIN
	--DECLARE @sttime datetime  
	--SET @sttime=getdate()       

	SET NOCOUNT ON

	DECLARE	@QueryString nvarchar(max),
			@QueryForView nvarchar(max),
			@QueryForWhere nvarchar(max),
			@QueryForOrderBy nvarchar(1000),
			@ParameterList nvarchar(max),
			@AdvFilterWhereStr nvarchar(max),
			@AdvFilterTableStr nvarchar(max),
			@FinalSelectClause nvarchar(max),
			@FormattedEffDate Date,
			@FormattedColumnsList VARCHAR(MAX);

	-- add adv search
	IF (ISNULL(@AdvFilterXml, '') <> '')
	BEGIN
		DECLARE @iDoc int
		SET @iDoc = NULL
		EXEC sp_xml_preparedocument	@iDoc OUTPUT,
									@AdvFilterXml
		SELECT
			@AdvFilterWhereStr = WhereString,
			@AdvFilterTableStr = TableString
		FROM [dbo].[udf_XMLToAdvanceSearchDetailStrings](@iDoc)

		EXEC sp_xml_removedocument @iDoc
		SET @iDoc = NULL
	END

	SET @ParameterList = N'@DTAPDID int, @FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(30), @PayerID varchar(13), @PayerName varchar(50), @PricerTypeID int, @DoNotExport varchar(10), @RecsPerPage int, @TotalPages int OUTPUT, @TotalCount int OUTPUT, @FirstRec int, @LastRec int, @Abbr varchar(5), @FormattedEffDate DATE'
	SET @QueryForView = ''
	SET @QueryForView += N'		dbo.VW_DTA_PaySourceRptSearch WITH(NOLOCK) ' + CHAR(13) + CHAR(10)
	
	SET @QueryForView += N'		' + REPLACE(REPLACE(ISNULL(@AdvFilterTableStr, ''), '<SOURCE>.', ''),'PSP.','') + CHAR(13) + CHAR(10)

	-- set the search variables  
	SELECT
		@DTAPDID = ISNULL(@DTAPDID, 0),
		@FacilityID = LTRIM(ISNULL(@FacilityID, '')),
		@PayerID = LTRIM(ISNULL(@PayerID, '')),
		@NPI = LTRIM(ISNULL(@NPI, '')),
		@PayerName = LTRIM(ISNULL(@PayerName, '')),
		@PricerTypeID = ISNULL(@PricerTypeID, 0),
		@Abbr = RTRIM(LTRIM(ISNULL(@Abbr, ''))),
		@EffectiveDate = RTRIM(LTRIM(ISNULL(@EffectiveDate, '')))


	SET @QueryForWhere = ''
	SET @QueryForOrderBy = ''
	IF @ExcludePricerTypes = 1
	BEGIN
		SET  @QueryForWhere += N' AND IsEditAll = 1 ' +  CHAR(13) + CHAR(10)
	END
	IF (@PricerTypeID > 0)
		SET @QueryForWhere = @QueryForWhere + N'	AND LUTPTID = @PricerTypeID ' + CHAR(13) + CHAR(10)
	IF (@FacilityID <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND facility_id like ''%'' + @FacilityID + ''%''' + CHAR(13) + CHAR(10)
	END
	IF (@PayerID <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND payer_id like ''%'' + @PayerID + ''%''' + CHAR(13) + CHAR(10)
	END
	IF (@Taxonomy <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND taxonomy like ''%'' + @Taxonomy + ''%''' + CHAR(13) + CHAR(10)
	END
	IF (@NPI <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND npi like ''%'' + @NPI + ''%''' + CHAR(13) + CHAR(10)
	END
	IF (@PayerName <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND ISNULL(paysource_name,'''') like ''%'' + @PayerName + ''%''' + CHAR(13) + CHAR(10)
	END
	IF (ISNULL(@DoNotExport,'') <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND ISNULL(DoNotExport,''False'') like ''%''+@DoNotExport +''%'''+ CHAR(13) + CHAR(10)
	END
	IF (ISNULL(@Abbr,'') <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + N'	AND ISNULL(abbrev_name,'''') like ''%'' + @Abbr + ''%''' + CHAR(13) + CHAR(10)
	END

	IF (ISNULL(@EffectiveDate,'') <> '')
	BEGIN
		SET @FormattedEffDate = CONVERT(DATE, @EffectiveDate)
		SET @QueryForWhere = @QueryForWhere + N'	AND effDate  = @FormattedEffDate' + CHAR(13) + CHAR(10)
	END

	IF (ISNULL(@ColumnName, '') <> '' OR ISNULL(@SortOrder, '') <> '')
	BEGIN
		SET @QueryForOrderBy = N' ' + @ColumnName + ' ' + @SortOrder + ' ' + CHAR(13) + CHAR(10)
	END
	-- set the default if @QueryForOrderBy is empty
	IF (@QueryForOrderBy = '')
	BEGIN
		SET @QueryForOrderBy = ' RTRIM(facility_id) + RTRIM(npi),' + CHAR(13) + CHAR(10)
	END

	-- trim ending comma 
	SET @QueryForOrderBy = SUBSTRING(RTRIM(@QueryForOrderBy), 1, LEN(RTRIM(@QueryForOrderBy)) - 3)

	IF (@AdvFilterWhereStr <> '')
	BEGIN
		SET @QueryForWhere = @QueryForWhere + REPLACE(REPLACE(ISNULL(@AdvFilterWhereStr, ''), '<SOURCE>.', ''),'PSP.','') + CHAR(13) + CHAR(10)
	END

	-- build the final script for TotalPages
	SET @QueryString = ''

	IF (@FirstRec IS NULL
		AND @LastRec IS NULL)
	BEGIN
		SET @QueryString = @QueryString + N'SELECT	@TotalPages =
											CASE 
												WHEN @RecsPerPage is null THEN 1
												WHEN COUNT(DTAPSID) % @RecsPerPage = 0 THEN CEILING(COUNT(DTAPSID)/@RecsPerPage)
												ELSE CEILING(COUNT(DTAPSID)/@RecsPerPage) + 1
											END ,'
											--CEILING(COUNT(DTAPSID)/' + CAST(@RecsPerPage AS varchar(50)) + ') + 1, ' 
											+ CHAR(13) + CHAR(10)
		SET @QueryString += N'@TotalCount = COUNT(DTAPSID) ' + CHAR(13) + CHAR(10)
		SET @QueryString += N'FROM ' + CHAR(13) + CHAR(10)
		SET @QueryString += @QueryForView
		SET @QueryString += N'WHERE 1=1 ' + CHAR(13) + CHAR(10)
		IF (@DTAPDID > 0)
		BEGIN
			SET @QueryString += N'AND DTAPDID = @DTAPDID ' +  CHAR(13) + CHAR(10)
		END
		SET @QueryString += @QueryForWhere + CHAR(13) + CHAR(10)

		PRINT @QueryString
		EXEC SP_EXECUTESQL	@QueryString,
							@ParameterList,
							@DTAPDID = @DTAPDID,
							@FacilityID = @FacilityID,
							@NPI = @NPI,
							@Taxonomy = @Taxonomy,
							@PayerID = @PayerID,
							@PayerName = @PayerName,
							@PricerTypeID = @PricerTypeID,
							@DoNotExport = @DoNotExport,
							@RecsPerPage = @RecsPerPage,
							@TotalPages = @TotalPages OUT,
							@TotalCount = @TotalCount OUT,
							@FirstRec = @FirstRec,
							@LastRec = @LastRec,
							@Abbr = @Abbr,
							@FormattedEffDate = @FormattedEffDate
		RETURN
	END
	
	IF (@IsSummaryOnly = 1)
	BEGIN
		SET @FinalSelectClause = N'SELECT ' + @ColumnList;
	END
	ELSE IF(ISNULL(@ColumnList,'') <> '')
	BEGIN
		SELECT
			@FormattedColumnsList = CASE
				WHEN @FormattedColumnsList IS NULL
				THEN '' + LTRIM(RTRIM(value))
				ELSE @FormattedColumnsList + ', ' + LTRIM(RTRIM(value))
			END
		FROM
			STRING_SPLIT(@ColumnList, ',');

		SET @FinalSelectClause = N'SELECT ' +  @FormattedColumnsList + ' ';
	END
	ELSE
	BEGIN
		SET @FinalSelectClause = N'SELECT * ';
	END

	-- build the query string
	SET @QueryString = ''
	SET @QueryString = @QueryString + @FinalSelectClause + CHAR(13) + CHAR(10)
	SET @QueryString = @QueryString + N'	FROM  ' + CHAR(13) + CHAR(10)
	SET @QueryString = @QueryString + @QueryForView
	SET @QueryString = @QueryString + N'WHERE 1=1 ' + CHAR(13) + CHAR(10)
	IF (@DTAPDID > 0)
	BEGIN
		SET @QueryString += N'AND DTAPDID = @DTAPDID ' +  CHAR(13) + CHAR(10)
	END
	SET @QueryString = @QueryString + @QueryForWhere + CHAR(13) + CHAR(10)

	IF (@IsSummaryOnly = 1)
	BEGIN
		SET @QueryString = @QueryString + N'	GROUP BY LUTPTID ' + CHAR(13) + CHAR(10)
	END
	ELSE
	BEGIN
		SET @QueryString = @QueryString + N'	ORDER BY ' + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + @QueryForOrderBy + CHAR(13) + CHAR(10)
	
		IF(@RecsPerPage is not null)
		BEGIN
			SET @QueryString = @QueryString + N'	OFFSET @FirstRec ROWS FETCH NEXT @RecsPerPage ROWS ONLY' + CHAR(13) + CHAR(10)
		END
	END

	PRINT @QueryString
	EXEC SP_EXECUTESQL	@QueryString,
						@ParameterList,
						@DTAPDID = @DTAPDID,
						@FacilityID = @FacilityID,
						@NPI = @NPI,
						@Taxonomy = @Taxonomy,
						@PayerID = @PayerID,
						@PayerName = @PayerName,
						@PricerTypeID = @PricerTypeID,
						@DoNotExport = @DoNotExport,
						@RecsPerPage = @RecsPerPage,
						@TotalPages = @TotalPages OUT,
						@TotalCount = @TotalCount OUT,
						@FirstRec = @FirstRec,
						@LastRec = @LastRec,
						@Abbr = @Abbr,
						@FormattedEffDate = @FormattedEffDate
	SET NOCOUNT OFF
END
GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2505.01', N'2505.01', NULL, GETDATE())

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

    --US1391334: V2505.01 - Medicaid APR Pro - Adding New State Procedure for Missouri
    INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (80, 84, N'MO', N'Missouri', CAST(N'2025-04-01T00:00:00.000' AS DateTime), 5, 1)

    UPDATE [dbo].[LUT_PricerTypeAPRPro_Procedure] SET [PDescription] = 'Day Outlier (LOS, Variable Per Diem)' WHERE [PCode] = '0315'
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (254, N'0323', N'Day Outlier (Covered Days, Flat Per Diem)', 1, 84)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (255, N'0324', N'Set Day Outlier Threshold', 1, 84)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (256, N'1013', N'Set Covered Days', 1, 84)

    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 1, 1, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 2, 2, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 3, 3, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 256, 4, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 8, 5, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 173, 6, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 4, 7, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 45, 8, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 14, 9, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 16, 10, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 10, 11, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 109, 12, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 12, 13, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 255, 14, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 254, 15, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (80, 50, 16, CAST(N'2025-05-15T00:00:00.000' AS DateTime))
    
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (254, 3158)

	-- US1394550: V2505.01 - RHC Data Table Updates - New Field
    INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (814, 7, N'Column3', N'AIR-Eligible Flag', 1, 7, N'air_flag', N'0 = Not an AIR-Eligible Procedure Code
1 = Dental Services
2 = HIV Counselling Services', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 33, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

    UPDATE [dbo].[LUT_CodeTableField] SET [FieldLength] = 217, [FieldLeftCount] = 217, FieldFormat = 'X(217)', [ExportPosition]=34, [ModifiedDate]='20250515 00:00:00.000' WHERE FieldId = 63

	--US1391550: V2505.01 - New state added to Medicaid APR Pro: Missouri - Code Table support
	INSERT [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (50, N'codemo2.dat', CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL)
    INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (50, 84)

	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (815, 50, N'CodeType', N'Code Type', 1, 1, N'codetype', N'Colorado Medicaid:
B = UB-04 Bill Type Q = Discharge status
U = UB-04 admit source', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, 1, N'ASC')
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (816, 50, N'Code', N'Code', 1, 2, N'code', N'Code value will be one of the following:
-  Two digit discharge status code
-  Two digit UB-04 admit source
-  Two digit modifier
-  Two digit occurrence span code
-  Two digit value code
-  Four digit UB-04 Bill Type
-  Four digit psychiatric day identifier
-  Four digit revenue code
-  Five digit CPT®/HCPCS code
-  Ten digit ICD-10 procedure code or diagnosis code', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, 2, N'ASC')
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (817, 50, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'Sequence number for this code record.', NULL, 2, N'Decimal', 2, NULL, N'9(2)', 13, 0, 99, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (818, 50, N'StartDate', N'Start Date', 1, 3, N'startdate', N'YYYYMMDD = Date record is effective.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, 1, N'DESC', NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (819, 50, N'EndDate', N'End Date', 1, 4, N'enddate', N'YYYYMMDD = End date for record', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (820, 50, N'Column1', N'Transfer Flag', 1, 5, N'transfer', N'Colorado Medicaid:
1 = Transfer discharge status or admit source', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 31, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (821, 50, N'Column2', N'Non-Covered Bill Type', 1, 6, N'noncovbill', N'Colorado Medicaid:
1 = Non-covered bill type', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 32, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (822, 50, N'Column3', N'Interim Discharge Status', 1, 7, N'interim', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 33, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (823, 50, N'Column4', N'Long Acting Reversible Contraceptive (LARC) Code Combination', 1, 8, N'larccode', NULL, N'TextBox', 2, N'Text', 2, NULL, N'X(2)', 34, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (824, 50, N'Column5', N'Diagnosis Flag', 1, 9, N'dxflag', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 36, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (825, 50, N'Column6', N'Psychiatric Length of Stay Factor', 1, 10, N'factor', NULL, N'TextBox', 5, N'Decimal', 1, 4, N'9(1)v9(4)', 37, 0, 9.9999, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (826, 50, N'Column7', N'Span Code Flag', 1, 11, N'spanflag', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 42, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (827, 50, N'Column8', N'Revenue Code Flag', 1, 12, N'revflag', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 43, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (828, 50, N'Column9', N'Vagus Nerve Stimulator (VNS) Flag', 1, 13, N'vnsflag', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 44, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (829, 50, N'Column10', N'Exemption Flag', 1, 14, N'exempt', NULL, N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 45, 0, 9, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (830, 50, N'Column11', N'Fee Schedule Rate', 1, 15, N'fee', NULL, N'TextBox', 11, N'Decimal', 8, 3, N'9(8)v9(3)', 46, 0, 99999999.999, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (831, 50, N'Column12', N'Low Birth Weight', 1, 16, N'lbwgt', N'The minimum allowable birth weight in grams.', N'TextBox', 4, N'Integer', 4, NULL, N'9(4)', 57, 0, 9999, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (832, 50, N'Column13', N'High Birth Weight', 1, 17, N'hbwgt', N'The maximum allowable birth weight in grams.', N'TextBox', 4, N'Integer', 4, NULL, N'9(4)', 61, 0, 9999, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
	INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (833, 50, NULL, N'Filler', 0, NULL, N'filler1', NULL, NULL, 186, N'Filler', 186, NULL, N'X(186)', 65, NULL, NULL, NULL, NULL, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

	--US1391863: V2505.01 - New York Medicaid APG Enhanced - New Field and Updates
    DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4483
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.20', [ModifiedTS]='20250515 00:00:00.000' WHERE [LUTPTVID]=4322
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.21', [ModifiedTS]='20250515 00:00:00.000' WHERE [LUTPTVID]=4323
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.22', [ModifiedTS]='20250515 00:00:00.000' WHERE [LUTPTVID]=4324
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=41, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6832
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=42, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6833
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=43, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6834
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=44, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6835
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=45, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6836
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=46, [ModifiedTS]='20250515 00:00:00.000' WHERE [TMLPPTID]=6837
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4484, 87, N'G.19', N'econsult_adj', N'The adjustment to be applied to procedure codes 99451 or 99452 when Modifiers U1 and U1 are present.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'eConsult Adjustment:', N'2.0000', NULL, 5, 262, 0, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20250515 00:00:00.000', NULL, '20250601', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4485, 87, N'', N'filler1', N'', N'FILLER', 171, 0, N'X(171)', NULL, N'FILLER:', N'', NULL, 171, 267, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20250515 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7031, 87, 6370, N'TextBlock', N'Text', NULL, NULL, NULL, 39, 1, '20250515 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7032, 87, 6370, N'TextBox', N'Text', NULL, NULL, NULL, 40, 1, '20250515 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3903, 7031, 4484)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3904, 7032, 4484)
    
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

    --US1384976-V2505.01- ER - Advanced Filter - Add 'Last modified user' and 'Last modified date'
    ALTER TABLE [dbo].[LUT_PaySourceVariable] ALTER COLUMN [VariableName] [varchar](max) NOT NULL
    
    INSERT [dbo].[LUT_PaySourceVariable] ([LUTPSVID], [Section], [pattype], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [LabelOnUI], [DefaultValue], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [Enabled], [InsertedTS], [ModifiedTS], [LUTPTID]) VALUES (74, N'C', NULL, N'CAST(ISNULL(PSP.ModifiedTS, PSP.InsertedTS) AS DATE)', N'Last Modified Date', N'DATE', NULL, NULL, N'9(8)', N'Last Modified Date', NULL, NULL, NULL, NULL, NULL, 1, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL)
    INSERT [dbo].[LUT_PaySourceVariable] ([LUTPSVID], [Section], [pattype], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [LabelOnUI], [DefaultValue], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [Enabled], [InsertedTS], [ModifiedTS], [LUTPTID]) VALUES (75, N'C', NULL, N'PSP.LoginUser', N'Last Modified User', N'TEXT', NULL, NULL, N'X25', N'Last Modified User', NULL, NULL, NULL, NULL, NULL, 1, CAST(N'2025-05-15T00:00:00.000' AS DateTime), NULL, NULL)

    
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
