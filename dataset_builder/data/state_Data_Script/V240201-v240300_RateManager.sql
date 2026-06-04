USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from V240201 to v240300.
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
SET @FromDVersion = '2402.01'; -- the DVersion in the database
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

-- US1175052 - Contract APC Updates
GO
PRINT N'Altering Table [dbo].[PPS_apcpro_i]...';

IF NOT EXISTS (  
    SELECT 1  
    FROM sys.columns  
    WHERE Name IN ('drug_coins_flag')  
    AND Object_ID = OBJECT_ID('dbo.PPS_apcpro_i')  
)  
BEGIN
    ALTER TABLE [dbo].[PPS_apcpro_i]
    ADD [drug_coins_flag] VARCHAR (1) NULL;
END

GO
PRINT N'Altering Table [dbo].[TMP_IM_medext_i]...';

IF NOT EXISTS (  
    SELECT 1  
    FROM sys.columns  
    WHERE Name IN ('drug_coins_flag')  
    AND Object_ID = OBJECT_ID('dbo.TMP_IM_medext_i')  
)  
BEGIN
    ALTER TABLE [dbo].[TMP_IM_medext_i]
    ADD [drug_coins_flag] VARCHAR (1) NULL;
END

GO
PRINT N'Altering Table [dbo].[LUT_CodeTableField]...';

IF NOT EXISTS (  
    SELECT 1  
    FROM sys.columns  
    WHERE Name IN ('CodeSeqOrder', 'CodeSortOrder')  
    AND Object_ID = OBJECT_ID('dbo.LUT_CodeTableField')  
)  
BEGIN  
    ALTER TABLE dbo.LUT_CodeTableField  
    ADD CodeSeqOrder SMALLINT NULL,  
        CodeSortOrder VARCHAR(5) NULL;  
END  

GO
PRINT N'Creating User-Defined Function [dbo].[udf_CodeTable_GetSequenceOrderByClause]...';

IF OBJECT_ID('dbo.udf_CodeTable_GetSequenceOrderByClause', 'FN') IS NOT NULL  
    DROP FUNCTION dbo.udf_CodeTable_GetSequenceOrderByClause;    
GO
-- =============================================
-- Author:		Rakshitha
-- Create date: 03/07/2024
-- Description:	Returns OrderByClause for the given FileId
--SELECT [dbo].[udf_CodeTable_GetSequenceOrderByClause](38)
-- =============================================
CREATE FUNCTION [dbo].[udf_CodeTable_GetSequenceOrderByClause] (@FileId INT)  
RETURNS NVARCHAR(250)  
AS  
BEGIN  
    DECLARE @OrderByClause NVARCHAR(250);  
    SELECT @OrderByClause = COALESCE(@OrderByClause + ', ', '') + ColumnName + ' ' + COALESCE(CodeSortOrder, '')  
    FROM LUT_CodeTableField  
    WHERE FileId = @FileId  
    AND CodeSeqOrder IS NOT NULL  
    ORDER BY CodeSeqOrder;  
    RETURN @OrderByClause;  
END
Go

GO
PRINT N'Altering Procedure [dbo].[SP_Export_Codexxx]...';

GO
-- ============================================================================
-- Author:		Manisha G.
-- Modified by: 
-- Create date: 12/13/2023
-- Description:	
-- This stored procedure is to export data from CodeTables Data table to codexxx.dat
-- =============================================================================
-- 20240115.US1145445.Krishnam: ER - Code Table - Archive - Import

/*******************************************************************************
exec [SP_Export_Codexxx]
********************************************************************************/
ALTER PROCEDURE [dbo].[SP_Export_Codexxx] @FileName VARCHAR(50), @DTAPDID INT

AS
BEGIN
  DECLARE @CodeTableId INT
         ,@FileId INT
         ,@OrderByClause VARCHAR(250)
         ,@QueryString NVARCHAR(MAX)
         ,@ParameterList NVARCHAR(250) = N'@CodeTableId int, @DTAPDID int '

  SELECT @CodeTableId = cd.CodeTableId, @FileId= cd.FileId
  FROM EDR_CodeTable AS cd WITH (NOLOCK)
  WHERE cd.FileName = @FileName
  AND cd.ProductionDateId = @DTAPDID
  SELECT @OrderByClause = [dbo].[udf_CodeTable_GetSequenceOrderByClause](@FileId)

  --MetaData
  SELECT
    CT.ColumnName
   ,CT.LabelOnUI
   ,CT.DisplayOnUI
   ,CT.FieldName
   ,CT.FieldLength
   ,CT.FieldType
   ,CT.FieldLeftCount
   ,CT.FieldRightCount
   ,CT.FieldFormat
   ,CT.ExportPosition
  FROM LUT_CodeTableField CT WITH (NOLOCK)
  JOIN EDR_CodeTable ECT WITH (NOLOCK)
    ON CT.FileId = ECT.FileId
  WHERE ECT.CodeTableId = @CodeTableId
  AND ECT.ProductionDateId = @DTAPDID
  ORDER BY ExportPosition
  --COUNT
  SELECT
    COUNT(DataId)
  FROM EDR_CodeTableData WITH (NOLOCK)
  WHERE CodeTableId = @CodeTableId
  AND IsFinal = 1
  AND ProductionDateId = @DTAPDID
  AND RecordTypeId IN (1, 3)
  
  --Actual records
  SET @QueryString = ''
  SET @QueryString +=  N'SELECT CodeTableId, CodeType, Code, ' + CHAR(13) + CHAR(10)
  SET @QueryString +=  N'RIGHT(''00''+CAST(DENSE_RANK() OVER (PARTITION BY CodeType, Code ORDER BY ' + @OrderByClause + ') as VARCHAR(2)),2) AS codeseq,' + CHAR(13) + CHAR(10)
  SET @QueryString +=  N'StartDate, EndDate, Column1, Column2, Column3, Column4, 
        Column5, Column6, Column7, Column8, Column9, Column10, Column11, Column12, Column13, 
        Column14, Column15,Column16, Column17, Column18, Column19, Column20, Column21, Column22, 
        Column23, Column24, Column25, Column26,Column27, Column28, Column29, Column30, Column31, 
        Column32, Column33' + CHAR(13) + CHAR(10)
  SET @QueryString +=  N'FROM EDR_CodeTableData  WITH(NOLOCK)' + CHAR(13) + CHAR(10)
  SET @QueryString +=  N'WHERE CodeTableId = @CodeTableId AND IsFinal = 1 AND ProductionDateId = @DTAPDID AND RecordTypeId IN (1,3)'
  SET @QueryString +=  N'ORDER BY CodeType, Code,codeseq '

  PRINT @QueryString
  EXEC Sp_executesql @QueryString
                    ,@ParameterList
                    ,@CodeTableId = @CodeTableId
                    ,@DTAPDID = @DTAPDID


END

GO
PRINT N'Altering Procedure [dbo].[SP_Import_codetablexxx]...';

GO
-- =============================================
-- Author:		<Author,,Tarun Sahani>
-- Create date: <Create Date, 08/01/2023>
-- Description:	<Description, Import Code Table Data >
-- =============================================
ALTER PROCEDURE [dbo].[SP_Import_codetablexxx]
	-- Add the parameters for the stored procedure here
	@LoginSessionGUID uniqueidentifier,  @DTAPDID int = 0,  @CodeTableId int  
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- variables for try-catch    
 DECLARE @errSeverity int, @errMsg varchar(max), @currentStep varchar(50), @DTAPDIDLabel varchar(50)  

  BEGIN TRY  
  
  DECLARE @LoginUser varchar(200)  
  EXEC sp_GetLogUser @LoginSessionGUID, @LoginUser OUT         
  
  SET @DTAPDIDLabel =   
  (CASE  
   WHEN (@DTAPDID > 0) Then ' ProductionDateId: ' + cast(@DTAPDID as varchar)  
   ELSE ''  
  END)  
  
  
  SET @currentStep = 'Start to import code table data.' + @DTAPDIDLabel  
  DECLARE @DTAELID bigint, @EffectRows bigint  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID, '[SP_Import_codetablexxx]','', @currentStep,null,@DTAELID out    
   
  BEGIN TRAN  

  -- insert  
  SET @currentStep = 'Start - Insert into table EDR_CodeTableData.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID, '[SP_Import_codetablexxx]','', @currentStep,null,@DTAELID  
  
   INSERT INTO [dbo].[EDR_CodeTableData]  
	       (
	        [CodeTableId] ,
            [CodeType] ,
            [Code],
            [StartDate] ,
            [EndDate] ,
            [RecordTypeId],
            [RuleId], 
            [ProductionDateId] ,
            [IsFinal],
            [Column1], 
            [Column2], 
            [Column3], 
            [Column4], 
            [Column5], 
            [Column6], 
            [Column7], 
            [Column8], 
            [Column9], 
            [Column10], 
            [Column11], 
            [Column12], 
            [Column13], 
            [Column14], 
            [Column15], 
            [Column16], 
            [Column17], 
            [Column18],
            [Column19],
            [Column20],
            [Column21], 
            [Column22], 
            [Column23], 
            [Column24], 
            [Column25], 
            [Column26], 
            [Column27], 
            [Column28],
            [Column29],
            [Column30],
            [Column31],
            [Column32],
            [Column33])
	   SELECT 
			[CodeTableId],
			[CodeType] ,
			[Code],
			[StartDate] ,
			[EndDate] ,
			[RecordTypeId],
			ruleId, 
			[ProductionDateId] ,
			[IsFinal],
			LTRIM(RTRIM([Column1])) AS [Column1], 
			LTRIM(RTRIM([Column2])) AS [Column2], 
			LTRIM(RTRIM([Column3])) AS [Column3], 
			LTRIM(RTRIM([Column4])) AS [Column4], 
			LTRIM(RTRIM([Column5])) AS [Column5], 
			LTRIM(RTRIM([Column6])) AS [Column6], 
			LTRIM(RTRIM([Column7])) AS [Column7], 
			LTRIM(RTRIM([Column8])) AS [Column8], 
			LTRIM(RTRIM([Column9])) AS [Column9], 
			LTRIM(RTRIM([Column10])) AS [Column10], 
			LTRIM(RTRIM([Column11])) AS [Column11], 
			LTRIM(RTRIM([Column12])) AS [Column12], 
			LTRIM(RTRIM([Column13])) AS [Column13], 
			LTRIM(RTRIM([Column14])) AS [Column14], 
			LTRIM(RTRIM([Column15])) AS [Column15], 
			LTRIM(RTRIM([Column16])) AS [Column16], 
			LTRIM(RTRIM([Column17])) AS [Column17], 
			LTRIM(RTRIM([Column18])) AS [Column18],
			LTRIM(RTRIM([Column19])) AS [Column19],
			LTRIM(RTRIM([Column20])) AS [Column20],
			LTRIM(RTRIM([Column21])) AS [Column21], 
			LTRIM(RTRIM([Column22])) AS [Column22], 
			LTRIM(RTRIM([Column23])) AS [Column23], 
			LTRIM(RTRIM([Column24])) AS [Column24], 
			LTRIM(RTRIM([Column25])) AS [Column25], 
			LTRIM(RTRIM([Column26])) AS [Column26], 
			LTRIM(RTRIM([Column27])) AS [Column27], 
			LTRIM(RTRIM([Column28])) AS [Column28],
			LTRIM(RTRIM([Column29])) AS [Column29],
			LTRIM(RTRIM([Column30])) AS [Column30],
			LTRIM(RTRIM([Column31])) AS [Column31],
			LTRIM(RTRIM([Column32])) AS [Column32],
			LTRIM(RTRIM([Column33])) AS [Column33]
	FROM TMP_IM_codetablexxx WITH (NOLOCK) where CodeTableId = @CodeTableId and ProductionDateId = @DTAPDID
	
  SET @currentStep = 'End - Insert into table [EDR_CodeTableData].' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID, '[SP_Import_codetablexxx]','', @currentStep,@@ROWCOUNT,@DTAELID  
  
  COMMIT TRAN  
  
  SET @currentStep = 'Import codetable completed.' + @DTAPDIDLabel  
  EXEC [sp_DTA_EventLog_Insert_IM] @LoginSessionGUID, '[SP_Import_codetablexxx]','', @currentStep,null,@DTAELID  
  
    END TRY    
    BEGIN CATCH    
    SELECT @errSeverity = ERROR_SEVERITY(), @errMsg = ERROR_MESSAGE() + @DTAPDIDLabel  
 EXEC dbo.[SP_DTA_EventLog_Insert_SP] @LoginSessionGUID, '[SP_Import_codetablexxx]', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, @currentStep  
  
    END CATCH       
END

GO
PRINT N'Altering Procedure [dbo].[SP_Export_medext]...';


GO
-- ============================================================================
-- Author:        Amy Zhao
-- Modified by: 
-- Create date: 01/20/2012
-- Description:	This sp to query paysource and pps esrd and contract apc tables
-- to get the medext data for both C and Cobol export 
-- DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source
-- DE225786.20220217.Mani we need to filter out the records before generating sequece number, if we are exporting ExportQueue or Filtered records
-- DE232155.20220516.Mani we need to exclude records which don't support cobol export before generating sequece number
-- US910936.20220606.Mani - ext file names are updated
-- US1174750. 20240307.Divya - Removing date restrictions for medext export
-- =============================================================================

/*******************************************************************************
exec [SP_Export_medext] null,'medext','','','','',36,0,0
********************************************************************************/
ALTER PROCEDURE [dbo].[SP_Export_medext] @LoginSessionGUID uniqueidentifier, @ImportedFileWithoutExt varchar(20), 
@FacilityID varchar(16), @NPI varchar(10), @Taxonomy varchar(10), @PayerID varchar(13), @PayerName varchar(50), @PricerTypeID int, 
@FromDate DateTime = NULL, @ToDate DateTime = NULL, @InExportQueue bit, @isCobolExport BIT, @DTAPDID INT = 0
AS
BEGIN

	--@pricer_type varchar(2)='A'
	-- variables for try-catch  
	DECLARE	@errSeverity int,
			@errMsg varchar(max),
			@currentStep varchar(50),
			@hasFilters bit = 0

	BEGIN TRY


		IF OBJECT_ID('tempdb..#temp') IS NOT NULL
		BEGIN
			DROP TABLE #temp
		END

		DECLARE @pattype char(2);
		SET @pattype = dbo.udf_GetPatType(@ImportedFileWithoutExt)


		SELECT
			ROW_NUMBER() OVER (ORDER BY MedExtExportOrder) rowNum,
			LUTPTID,
			PricerTableName,
			PricerTypeName,
			MedExtExportOrder INTO #temp
		FROM (SELECT DISTINCT
			pt.LUTPTID,
			pt.PricerTableName,
			pt.TMP_PricerTableName,
			pt.PricerTypeName,
			pt.MedExtExportOrder
		FROM LUT_PricerType pt
		INNER JOIN LUT_PricerTypeVariable ptv
			ON pt.LUTPTID = ptv.LUTPTID
		WHERE ptv.IsMedext = 1 AND pattype = @pattype
		AND (@isCobolExport = 0 OR pt.PricerTypeNameInCobol <> '99')
		AND pt.MedExtExportOrder IS NOT null) AS test

		IF OBJECT_ID(N'tempdb..#tempExportSearch', N'U') IS NOT NULL
		BEGIN
			DROP TABLE #tempExportSearch;
		END

		CREATE TABLE #tempExportSearch (
			DTAPSPID bigint,
			pattype varchar(2),
			PricerTypeName varchar(2),
			paysource varchar(64),
			effdate datetime,
			npi_flag varchar(1),
			DoNotExport bit
		);

		IF (@FacilityID <> ''
			OR @NPI <> ''
			OR @Taxonomy <> ''
			OR @PayerID <> ''
			OR @PayerName <> ''
			OR @FromDate IS NOT NULL
			OR @ToDate IS NOT NULL
			OR @PricerTypeID > 0
			OR ISNULL(@InExportQueue, 0) = 1)
		BEGIN
			SET @hasFilters = 1
			SELECT @FromDate = COALESCE(@FromDate, '1/1/1753'), 
			@ToDate = COALESCE(@ToDate, '12/31/9999')

			INSERT INTO #tempExportSearch (DTAPSPID, pattype, PricerTypeName, paysource, effdate, npi_flag, DoNotExport)
				SELECT
					es.DTAPSPID,
					es.pattype,
					es.PricerTypeName,
					es.paysource,
					es.effdate,
					es.npi_flag,
					es.DoNotExport
				FROM [dbo].udf_Export_Search(@FacilityID, @NPI, @Taxonomy, @PayerID, @PayerName, @PricerTypeID, @InExportQueue, @FromDate, @ToDate) as es
				INNER JOIN #temp as t on es.LUTPTID = t.LUTPTID

			-- in case of large data this index should help with performance as we inner join by DTAPSPID
			CREATE CLUSTERED INDEX #tempExportSearch_DTAPSPID ON #tempExportSearch (DTAPSPID) 
		END


		-- BEGIN.DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source
		IF OBJECT_ID('tempdb..#tmpSEQ') IS NOT NULL
		BEGIN
			DROP TABLE #tmpSEQ
		END

		CREATE TABLE #tmpSEQ(
			DTAPDID bigint,
			DTAPSPID int,
			eseq varchar(4)
		);

		IF (@hasFilters = 0)
		BEGIN
			INSERT INTO #tmpSEQ
			SELECT
				DTAPDID,
				DTAPSPID,
				RIGHT('0000' + CAST(DENSE_RANK() OVER (PARTITION BY config.DTAPSID ORDER BY config.effdate DESC) AS varchar(4)), 4) AS eseq 
			FROM DTA_PaySourceAll_VW config WITH (NOLOCK)
			INNER JOIN LUT_PricerType pt
				ON config.LUTPTID = pt.LUTPTID
			WHERE pt.MedExtExportOrder IS NOT NULL
			AND DTAPDID = @DTAPDID AND pt.pattype = @pattype
			AND (@isCobolExport = 0 OR pt.PricerTypeNameInCobol <> '99')
		END
		ELSE --If filter or export queue is used for export, then we need to filter the records by applying join condition with #tempExportSearch table
		BEGIN
			INSERT INTO #tmpSEQ
			SELECT
				config.DTAPDID,
				config.DTAPSPID,
				RIGHT('0000' + CAST(DENSE_RANK() OVER (PARTITION BY config.DTAPSID ORDER BY config.effdate DESC) AS varchar(4)), 4) AS eseq 
			FROM DTA_PaySourceAll_VW config WITH (NOLOCK)
			INNER JOIN #tempExportSearch es ON es.DTAPSPID = config.DTAPSPID 
			INNER JOIN LUT_PricerType pt
				ON config.LUTPTID = pt.LUTPTID
			WHERE pt.MedExtExportOrder IS NOT NULL
			AND DTAPDID = @DTAPDID
		END


		-- in case of large data this index should help with performance as we inner join by these two fields
		CREATE CLUSTERED INDEX #tmpSEQ_PDID_PSPID ON #tmpSEQ (DTAPDID, DTAPSPID)   
		-- END.DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source


		DECLARE	@maxRow bigint,
				@offset bigint,
				@ppsTableName nvarchar(100),
				@pricerTypeName nvarchar(10)

		SELECT
			@offset = 1,
			@maxRow = MAX(rowNum)
		FROM #temp

		DECLARE	@QueryString nvarchar(max),
				@ParameterList nvarchar(max)

		WHILE (@offset <= @maxRow)
		BEGIN
			SELECT
				@ppsTableName = PricerTableName,
				@pricerTypeName = RTRIM(LTRIM(PricerTypeName))
			FROM #temp
			WHERE rowNum = @offset


			SET @ParameterList = N'@DTAPDID int'
			-- export esrd		
			SET @currentStep = 'Build dynamic query string for pricer type esrd'
			SET @QueryString = ''
			SET @QueryString = @QueryString + N'	SELECT ' + CHAR(13) + CHAR(10)
			SET @QueryString = @QueryString + N'		config.DTAPSPID' + CHAR(13) + CHAR(10)
			SET @QueryString = @QueryString + N'		, config.PricerTypeName' + CHAR(13) + CHAR(10) --508-509/ cobol 798-799
			SET @QueryString = @QueryString + N'		, config.paysource' + CHAR(13) + CHAR(10) -- 1 - 29
			SET @QueryString = @QueryString + N'		, ''0'' as effseqe' + CHAR(13) + CHAR(10) -- cobol 31
			-- BEGIN.DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source
			--SET @QueryString = @QueryString + N'		, RIGHT(''0000''+CAST(DENSE_RANK() OVER (PARTITION BY DTAPSID,pattype ORDER BY pattype, effdate desc)as VARCHAR(4)),4) as effseq' + CHAR(13) + CHAR(10) -- eseq cobol 32-35
			SET @QueryString = @QueryString + N'		, tmpseq.eseq as effseq' + CHAR(13) + CHAR(10)  -- eseq cobol 32-35  
			-- END.DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source
			SET @QueryString = @QueryString + N'		, CONVERT(CHAR(8),config.effdate,112) as effdate' + CHAR(13) + CHAR(10) -- effdate 30-37
			SET @QueryString = @QueryString + N'		, RIGHT(config.pattype,1) as pattype' + CHAR(13) + CHAR(10) -- pattype 38		
			SET @QueryString = @QueryString + N'		, config.npi_flag' + CHAR(13) + CHAR(10) -- key type 510/ cobol 800	
			SET @QueryString = @QueryString + N'		, ''0'' as seqnum' + CHAR(13) + CHAR(10) -- pattype 39					
			SET @QueryString = @QueryString + N'		, pps.*' + CHAR(13) + CHAR(10)    -- 39-466 
			--SET @QueryString = @QueryString + N'		,( SPACE(44)' + CHAR(13) + CHAR(10) -- filler 467=510
			--SET @QueryString = @QueryString + N'			) as other' + CHAR(13) + CHAR(10)
			SET @QueryString = @QueryString + N'	FROM __TABLENAME__ pps WITH (NOLOCK) ' + CHAR(13) + CHAR(10)

			IF (@hasFilters = 1)
			BEGIN
				SET @QueryString = @QueryString + N'	INNER JOIN #tempExportSearch config ON pps.DTAPSPID = config.DTAPSPID' + CHAR(13) + CHAR(10)
			END
			ELSE
			BEGIN 
				SET @QueryString = @QueryString + N'	INNER JOIN VW_Config_Export config WITH (NOLOCK) ON pps.DTAPDID = config.DTAPDID AND pps.DTAPSPID = config.DTAPSPID' + CHAR(13) + CHAR(10)
			END

			-- DE225391.20220111.Vadim	seq number should distiquish by patient type for the same pay source
			IF (@DTAPDID > 0) 
			BEGIN
				SET @QueryString = @QueryString + N'	INNER JOIN #tmpSEQ tmpseq WITH (NOLOCK) on tmpseq.DTAPDID = config.DTAPDID AND tmpseq.DTAPSPID = config.DTAPSPID' + CHAR(13) + CHAR(10)
			END
			ELSE
			BEGIN
				SET @QueryString = @QueryString + N'	INNER JOIN #tmpSEQ tmpseq WITH (NOLOCK) on tmpseq.DTAPSPID = config.DTAPSPID' + CHAR(13) + CHAR(10)
			END

				--SET @QueryString = @QueryString + N'	INNER JOIN [dbo].VW_PaySourcePricer_Export psp on pps.DTAPSPID = psp.DTAPSPID ' + CHAR(13) + CHAR(10)
				--SET @QueryString = @QueryString + N'	LEFT OUTER JOIN [dbo].[LUT_RateGrouper] lrp ON psp.grpr_type = lrp.GrouperValue' + CHAR(13) + CHAR(10)
				--SET @QueryString = @QueryString + N'	LEFT OUTER JOIN [dbo].[VW_Config_Export] sconfig on psp.SharedWeightDTAPSPID = sconfig.DTAPSPID' + CHAR(13) + CHAR(10)

			SET @QueryString = @QueryString + N'	WHERE   (@DTAPDID > 0 OR ISNULL(DoNotExport,0)=0)	 ' + CHAR(13) + CHAR(10)

			IF (@DTAPDID > 0)
			BEGIN
				SET @QueryString = @QueryString + N'AND config.DTAPDID = @DTAPDID AND pps.DTAPDID = @DTAPDID' + CHAR(13) + CHAR(10)
			END

			SET @QueryString = @QueryString + N'	ORDER BY config.paysource, config.npi_flag, config.effdate desc' + CHAR(13) + CHAR(10)

			-- config.effdate >= ''01/01/2011''  60
			-- config.effdate >= ''01/01/2011''  i 
			-- config.effdate >= ''10/01/2012''  A 

			-- replace actual table in query string
			SELECT
				@QueryString = REPLACE(@QueryString, '__TABLENAME__', @ppsTableName)
			PRINT @QueryString

			-- exec the dynamic sql to return pps table
			SET @currentStep = 'Exec the dynamical sql to return pps table.'
			EXEC SP_EXECUTESQL	@QueryString,
								@ParameterList,
								@DTAPDID = @DTAPDID


			SET @offset += 1
		END

		-- DE225391.20220111.Vadim	clean up
		IF OBJECT_ID('tempdb..#tmpSEQ') IS NOT NULL
		BEGIN
			DROP TABLE #tmpSEQ
		END

		IF OBJECT_ID(N'tempdb..#tempExportSearch', N'U') IS NOT NULL
		BEGIN
			DROP TABLE #tempExportSearch;
		END

		IF OBJECT_ID('tempdb..#temp') IS NOT NULL
		BEGIN
			DROP TABLE #temp
		END

	END TRY
	BEGIN CATCH
		SELECT
			@errSeverity = ERROR_SEVERITY(),
			@errMsg = ERROR_MESSAGE()
		EXEC dbo.[SP_DTA_EventLog_Insert_SP]	@LoginSessionGUID,
												'[SP_Export_medext]',
												@@ERROR,
												@errSeverity,
												@errMsg,
												@@TRANCOUNT,
												@currentStep
	END CATCH
END
GO
PRINT N'Refreshing Procedure [dbo].[SP_DTA_AuditTrailEditor_GetFieldNames]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_DTA_AuditTrailEditor_GetFieldNames]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_EDR_CodeTable_Editor_Search]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_EDR_CodeTable_Editor_Search]';


GO
PRINT N'Refreshing Procedure [dbo].[SP_EDR_CodeTableData_Search]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[SP_EDR_CodeTableData_Search]';
GO
PRINT N'Update complete.';
GO



BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2402.01', N'2403.00', NULL, GETDATE())

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

--Insert statements for adding support for codeapc and codedrg Lut_CodeTableFile
INSERT INTO [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (37, N'codeapc.dat', '20240307 00:00:00.000', NULL, NULL, NULL)
INSERT INTO [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (38, N'codedrg.dat', '20240307 00:00:00.000', NULL, NULL, NULL)

--Insert statements for adding support for codeapc and codedrg LUT_CodeTablePricerType
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (37, 13)
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (37, 14)
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (38, 36)
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (38, 41)

--Insert statements for adding support for codeapc and codedrg LUT_CodeTableField
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (592, 37, N'CodeType', N'Code Type', 1, 1, N'codetype', N'C = Procedure code
D = ICD-9-CM diagnosis code K = ICD-10-CM diagnosis code M = Modifier
P = Device-Intensive Procedure Code Pair
Z = Zip code', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (593, 37, N'Code', N'Code', 1, 2, N'code', N'Code value will be 5-digit zip code, 5 character procedure code, 7 character diagnosis code, or 2 character modifier.', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (594, 37, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'Sequence number for this code record.', NULL, 2, N'Text', 2, NULL, N'X(2)', 13, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (595, 37, N'StartDate', N'Start Date', 1, 3, N'startdate', N'Date record is effective.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (596, 37, N'EndDate', N'End Date', 1, 4, N'enddate', N'00000000 = Code is still in effect
YYYYMMDD = End date for record', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (597, 37, N'Column1', N'Ambulance Carrier/Locality', 1, 5, N'carrier', N'Identifies the Medicare Part B carrier number and pricing locality.', N'TextBox', 12, N'Text', 12, NULL, N'X(12)', 31, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (598, 37, N'Column2', N'Ambulance Rural Indicator', 1, 6, N'amb_rural', N'This flag indicates that the zip code is rural.
B = Qualified rural area zip code for air and ground ambulance services
R = Rural zip code for air and ground ambulance services
U = Rural zip code for ground ambulance services and qualified rural area zip code for air ambulance services
V = Qualified rural area zip code for ground ambulance services and rural zip code for air ambulance services
W = Rural zip code for ground ambulance services only
X = Rural zip code for air ambulance services only
Y = Qualified rural area zip code for ground ambulance services only (currently, not in use)
Z = Qualified rural area zip code for air ambulance services only
Blank = Not rural', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 43, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (599, 37, N'Column3', N'Device Offset', 1, 7, N'dev_offset', N'Procedure Code: Payment offset for device- intensive procedures.', N'TextBox', 10, N'Decimal', 8, 2, N'9(8)v9(2)', 44, 0, 99999999.99, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (600, 37, NULL, N'Filler', 0, NULL, N'filler1', NULL, NULL, 2, N'Filler', 2, NULL, N'X(2)', 54, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (601, 37, N'Column4', N'Therapy Flag', 1, 8, N'therapyflag', N'0 = All other
1 = Evaluative therapy code, functional therapy code required
2 = Therapy code, no functional therapy code required
3 = Functional therapy code
4 = Therapy code without MPFS Rate, no functional therapy code required', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 56, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (602, 37, N'Column5', N'Michigan Short Stay Flag', 1, 9, N'mssflag', N'Contract APC:
0 = All other diagnosis codes
1 = Diagnosis codes subject to the Michigan short stay policy', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 57, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (603, 37, N'Column6', N'Emergent Diagnosis Flag', 1, 10, N'erflag', N'Contract APC:
0 = All other diagnosis codes
1 = Diagnosis codes not subject to the Iowa Medicaid “non- emergent” ER reduction', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 58, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (604, 37, N'Column7', N'Provider Based Department (PBD) Flag', 1, 11, N'pbd_flag', N'APC-HOPD:
0 = Not applicable
1 = Not eligible for the PN reduction
2 = Eligible for the PO reduction', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 59, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (605, 37, N'Column8', N'Deductible Waived Flag', 1, 12, N'deduct_waived', N'APC-HOPD:
0 = Do not waive deductible
1 = Waive deductible
2 = Deductible waived with Modifier CS', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 60, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (606, 37, N'Column9', N'Coinsurance Waived Flag', 1, 13, N'coins_waived', N'APC-HOPD:
0 = Do not waive coinsurance
1 = Waive coinsurance
2 = Coinsurance waived with Modifier CS', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 61, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (607, 37, N'Column10', N'Ambulance Flag', 1, 14, N'amb_flag', N'Contract APC & APC-HOPD:
0 = Code is not in the Ambulance Fee Schedule
1 = Code is in the Ambulance Fee Schedule', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 62, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (608, 37, N'Column11', N'Offset Eligibility Flag', 1, 15, N'offset_elg', N'APC-HOPD:
C = Procedure code is eligible for contrast agent/skin product offsets
R = Procedure code is eligible for Radiopharmaceutical offsets', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 63, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (609, 37, N'Column12', N'Edit Modifiers', 1, 16, N'edit_mod', N'Contract APC & APC-HOPD: Blank = Codes not applicable GO = Occupational speech
therapy service GN = Speech language
pathology service
GP = Physical therapy service', N'TextBox', 10, N'Text', 10, NULL, N'X(10)', 64, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (610, 37, N'Column13', N'Mammography Procedure Flag', 1, 17, N'mamm_flag', N'APC-HOPD:
0 = All other procedure codes
1 = Mammography codes', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 74, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (611, 37, N'Column14', N'Payment Adjustment Modifiers', 1, 18, N'pay_adj_mod', N'Contract APC & APC-HOPD: This field holds modifiers that can be used for a payment adjustment with the corresponding procedure code on the line:
CT = Services eligible for a reduction when billed with Modifier CT
FX= Services eligible for a reduction when billed with Modifier FX
FY = Services eligible for a reduction when billed with Modifier FY', N'TextBox', 10, N'Text', 10, NULL, N'X(10)', 75, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (612, 37, N'Column15', N'Modifier Flag', 1, 19, N'mod_flag', N'APC-HOPD:
0 = All others
1 = Modifier indicates COVID- 19 testing-related service
2 = Modifier indicates Occupational Therapy Assistant (OTA) service
3 = Modifier indicates Physical Therapist Assistant (PTA) service
Contract APC:
2 = Modifier indicates Occupational Therapy Assistant (OTA) service
3 = Modifier indicates Physical Therapist Assistant (PTA) service', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 85, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (613, 37, N'Column16', N'Opioid Use Disorder Treatment', 1, 20, N'oud_flag', N'APC-HOPD:
0 = All others
1 = Opioid use disorder treatment service', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 86, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (614, 37, N'Column17', N'Device-Intensive Procedure', 1, 21, N'codepair_hcpcs', N'APC-HOPD:
Device-intensive procedure code associated with the device code located in the Code field (code; CTR-CODE).', N'TextBox', 7, N'Text', 7, NULL, N'X(7)', 87, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (615, 37, N'Column18', N'Allowed Flag', 1, 22, N'allowed_flag', N'APC-HOPD:
0 = All others
1 = Allowed procedure on UB- 04 Bill Type 012X (without condition code W2) claims', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 94, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (616, 37, NULL, N'Filler', 0, NULL, N'filler2', NULL, NULL, 155, N'Filler', 155, NULL, N'X(155)', 96, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (617, 38, N'CodeType', N'Code Type', 1, 1, N'codetype', N'C = HCPCS/CPT® procedure code
F = New technology family
K = ICD-10 diagnosis code
L = ICD-10 procedure code
N = National Drug Code (NDC)', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (618, 38, N'Code', N'Code', 1, 2, N'code', N'Code value will be a 5-digit HCPCS/CPT® procedure code, 7-digit ICD-10 diagnosis code, 7-digit ICD-10 procedure code, 4-digit New Technology Family ID, or an 11-digit NDC value.', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (619, 38, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'Sequence number for this code record.', NULL, 2, N'Decimal', 2, NULL, N'9(2)', 13, 0, 99, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (620, 38, N'StartDate', N'Start Date', 1, 3, N'startdate', N'Date record is effective.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (621, 38, N'EndDate', N'End Date', 1, 4, N'enddate', N'00000000 = Code is still in effect
YYYYMMDD = End date for record', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (622, 38, N'Column1', N'Rate', 1, 5, N'rate', N'Payment rate', N'TextBox', 11, N'Decimal', 8, 3, N'9(8)v9(3)', 31, 0, 99999999.999, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (623, 38, N'Column2', N'Blood Clotting Factor Flag', 1, 6, N'hemo_flag', N'0 = All others
1 = Blood clotting factor', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 42, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (624, 38, N'Column3', N'COVID-19 Code Flag', 1, 7, N'covid19_flag', N'Medicare Inpatient and TRICARE/CHAMPUS:
0 = All others
1 = COVID-19 code', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 43, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (625, 38, N'Column4', N'New Technology Family ID', 1, 8, N'newtech_family_id', N'Medicare Inpatient and TRICARE/CHAMPUS:
Unique 4-digit number assigned to each new technology.', N'TextBox', 4, N'Decimal', 4, NULL, N'9(4)', 44, 0, 9999, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (626, 38, N'Column5', N'Number of New Technology Lists for Family', 1, 9, N'newtech_num_lists', N'Medicare Inpatient and TRICARE/CHAMPUS:
Number of lists for new technology.', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 48, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (627, 38, N'Column6', N'New Technology List Number for Code', 1, 10, N'newtech_list', N'Medicare Inpatient and TRICARE/CHAMPUS:
New technology list number for code.', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 49, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (628, 38, N'Column7', N'New Technology Code Requirements', 1, 11, N'newtech_req', N'Medicare Inpatient and TRICARE/CHAMPUS:
1 = At least one code from list is required to meet new technology criteria
2 = Codes on this list cause an exclusion from new technology', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 50, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (629, 38, N'Column8', N'New Technology Type', 1, 12, N'newtech_type', N'Medicare Inpatient and TRICARE/CHAMPUS:
1 = New technology add-on payment with 65% cost factor
2 = New technology add-on payment with 75% cost factor
3 = New COVID-19 Treatments Add-On Payment (NCTAP)
4 = NCTAP and new technology add-on payment with 65% cost factor', N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 51, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (630, 38, N'Column9', N'New Technology Group ID', 1, 13, N'newtech_grp_id', N'Medicare Inpatient and TRICARE/CHAMPUS:
Unique 2-digit number assigned to each new technology.
00 = All others
01 = Fetroja® (cefiderocol) 02 = RECARBRIO™
(imipenem, cilastatin, and relebactam)', N'TextBox', 2, N'Decimal', 2, NULL, N'9(2)', 52, 0, 99, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (631, 38, NULL, N'Filler', 0, NULL, N'filler1', NULL, NULL, 197, N'Filler', 197, NULL, N'X(197)', 54, NULL, NULL, NULL, NULL, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate]) VALUES (737, 37, N'Column19', N'AWV Flag', 1, 23, N'awv_flag', NULL, N'TextBox', 1, N'Decimal', 1, NULL, N'9(1)', 95, 0, 9, NULL, NULL, '20240307 00:00:00.000', NULL)
--Update statements to add CodeSeqOrder and CodeSortOrder
UPDATE LUT_CodeTableField SET CodeSeqOrder=1, CodeSortOrder='DESC' ,ModifiedDate = '20240307 00:00:00.000' WHERE ColumnName='StartDate' AND FileId NOT IN (37,38)
UPDATE LUT_CodeTableField SET CodeSeqOrder=2, CodeSortOrder='DESC' ,ModifiedDate = '20240307 00:00:00.000' WHERE ColumnName='EndDate' AND FileId NOT IN (37,38)

--codeapc Update statements to add CodeSeqOrder and CodeSortOrder
UPDATE LUT_CodeTableField SET CodeSeqOrder=1, CodeSortOrder='ASC' ,ModifiedDate = '20240307 00:00:00.000' WHERE FieldId=614 AND FileId=37
UPDATE LUT_CodeTableField SET CodeSeqOrder=2, CodeSortOrder='DESC' ,ModifiedDate = '20240307 00:00:00.000' WHERE ColumnName='StartDate' AND FileId=37
UPDATE LUT_CodeTableField SET CodeSeqOrder=3, CodeSortOrder='DESC' ,ModifiedDate = '20240307 00:00:00.000' WHERE ColumnName='EndDate' AND FileId=37

--codedrg Update statements to add CodeSeqOrder and CodeSortOrder
UPDATE LUT_CodeTableField SET CodeSeqOrder=1, CodeSortOrder='DESC' ,ModifiedDate = '20240307 00:00:00.000' WHERE ColumnName='StartDate' AND FileId=38
UPDATE LUT_CodeTableField SET CodeSeqOrder=2, CodeSortOrder='ASC' ,ModifiedDate = '20240307 00:00:00.000' WHERE FieldId=625 AND FileId=38

--Updating RangeMax codenc2
UPDATE LUT_CodeTableField set RangeMax = 99999 ,ModifiedDate = '20240307 00:00:00.000' where fieldid = 71

--US1180192 - Updating edit descriptions
UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription]=N'Invalid age (RTP)' WHERE [AceErrorNumber]=N'025'
UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription]=N'Invalid sex (RTP)' WHERE [AceErrorNumber]=N'026'
UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription]=N'Only incidental services reported (Claim Rejection)' WHERE [AceErrorNumber]=N'027'
UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription]=N'PHP/IOP for applicable diagnosis (RTP)' WHERE [AceErrorNumber]=N'029'

--US1181292 - Proc updates for Medicaid APG Pro (Illinois)
INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (67, 86, N'IL', N'Illinois', CAST(N'2023-01-01T00:00:00.000' AS DateTime), 5, 1)
INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (206, N'0154', N'Daily Hospital Addon - Illinois Medicaid', 1, 86)
INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (206, 3486)
INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (206, 3488)

INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 20, 1, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 51, 2, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 37, 3, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 175, 4, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 125, 5, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 123, 6, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 21, 7, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 22, 8, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 68, 9, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 25, 10, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 26, 11, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 27, 12, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 28, 13, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 29, 14, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 30, 15, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 31, 16, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 32, 17, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 33, 18, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 34, 19, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 127, 20, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 128, 21, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 70, 22, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 129, 23, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 73, 24, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 34, 25, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 176, 26, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 206, 27, CAST(N'2024-03-07T00:00:00.000' AS DateTime))
INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (67, 53, 28, CAST(N'2024-02-22T00:00:00.000' AS DateTime))

-- US1175054 - Kentucky Medicaid
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20151001' WHERE [LUTPTVID]=2352
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.5', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2353
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.6', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=3176
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.7', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2354
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'D.8', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=4235
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20151001' WHERE [LUTPTVID]=2355
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20151001' WHERE [LUTPTVID]=2356
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.1', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2357
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.2', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2358
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.3', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2359
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.4', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=3177
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.5', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2360
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.1', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2361
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.2', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2362
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.3', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2363
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.4', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=2364
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'', [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20151001' WHERE [LUTPTVID]=2365
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.5', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=4236
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.6', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=4237
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.7', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=4238
UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'F.8', [ModifiedTS]='20240307 00:00:00.000' WHERE [LUTPTVID]=4239

-- US1175052 - Contract APC Updates
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4403
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4404
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4405
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4406
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4407
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4408
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4409
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4410
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4411
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4412
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4413
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4414
DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4415

UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'E.17', [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20171231' WHERE [LUTPTVID]=1510
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20161231' WHERE [LUTPTVID]=1551
UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]='If this option is selected, the new fee schedule layout will be utilized. Do not check this box if you wish to utilize the legacy fee schedule layout.', [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20161231' WHERE [LUTPTVID]=3398
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20141231' WHERE [LUTPTVID]=1570
UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20141231' WHERE [LUTPTVID]=1571

INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4420, 14, N'E.46', N'drug_coins_flag', N'If this option is selected, the adjusted rebatable drug coinsurance factor will be applied when available. When this option is not selected, claims will not be subjected to the reduced rebatable drug coinsurance amount.', N'DECIMAL', 1, 0, N'9(1)', NULL, N'Adjusted Rebatable Drug Coinsurance Flag:', N'1', NULL, 1, 177, 1, 189, 1, NULL, NULL, 0, NULL, NULL, 3, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6958, 14, 2918, N'TextBlock', N'Text', NULL, NULL, NULL, 91, 1, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (6959, 14, 2918, N'CheckBox', N'IsChecked', NULL, NULL, NULL, 92, 1, '20240307 00:00:00.000', NULL)
INSERT INTO [dbo].[TML_PricerPageTLMap] ([TMLPPTID], [LUTPTVID]) VALUES (6958, 4420)
INSERT INTO [dbo].[TML_PricerPageTLMap] ([TMLPPTID], [LUTPTVID]) VALUES (6959, 4420)

INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4421, 14, N'', N'filler1', N'', N'FILLER', 11, 0, N'X(11)', NULL, N'FILLER:', N'', NULL, 11, 84, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4422, 14, N'', N'filler2', N'', N'FILLER', 5, 0, N'X(5)', NULL, N'FILLER:', N'', NULL, 5, 121, 5, 337, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4423, 14, N'', N'filler3', N'', N'FILLER', 6, 0, N'9(6)', NULL, N'FILLER:', N'', NULL, 6, 133, 6, 349, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4424, 14, N'', N'filler4', N'', N'FILLER', 1, 0, N'9(1)', NULL, N'FILLER:', N'', NULL, 1, 296, 1, 523, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4425, 14, N'', N'filler5', N'', N'FILLER', 1, 0, N'9(1)', NULL, N'FILLER:', N'', NULL, NULL, NULL, 1, 534, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4426, 14, N'', N'filler6', N'', N'FILLER', 5, 0, N'9(5)', NULL, N'FILLER:', N'', NULL, 5, 435, 5, 306, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4427, 14, N'', N'filler7', N'', N'FILLER', 330, 0, N'X(330)', NULL, N'FILLER:', N'', NULL, 330, 178, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4428, 14, N'', N'filler8', N'', N'FILLER', 159, 0, N'X(159)', NULL, N'FILLER:', N'', NULL, NULL, NULL, 159, 635, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4429, 14, N'', N'filler9', N'', N'FILLER', 10, 0, N'9(10)', NULL, N'FILLER:', N'', NULL, NULL, NULL, 10, 296, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4430, 14, N'', N'filler10', N'', N'FILLER', 8, 0, N'X(8)', NULL, N'FILLER:', N'', NULL, NULL, NULL, 8, 44, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4431, 14, N'', N'filler11', N'', N'FILLER', 608, 0, N'X(608)', NULL, N'FILLER:', N'', NULL, NULL, NULL, 608, 190, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4432, 14, N'', N'filler12', N'', N'FILLER', 1, 0, N'9(1)', NULL, N'FILLER:', N'', NULL, 1, 308, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)
INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [VariableSizeInCobol], [StartPositionInCobol], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4433, 14, N'', N'filler13', N'', N'FILLER', 1, 0, N'9(1)', NULL, N'FILLER:', N'', NULL, 1, 319, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20240307 00:00:00.000', NULL, '00010101', '99991231', NULL)

-- US1181820 - Medicare DRG Field Updates
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20041231' WHERE [LUTPTVID]=29
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20041231' WHERE [LUTPTVID]=73
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20011231' WHERE [LUTPTVID]=32
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20191231' WHERE [LUTPTVID]=88
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=56
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=57
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=58
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=59
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=60
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=61
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20081231' WHERE [LUTPTVID]=75
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20111031' WHERE [LUTPTVID]=62
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20111031' WHERE [LUTPTVID]=63
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20111031' WHERE [LUTPTVID]=64
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20111031' WHERE [LUTPTVID]=77
UPDATE [dbo].[LUT_PricerTypeVariable] SET  [ModifiedTS]='20240307 00:00:00.000', [DisplayEndDate]='20111031' WHERE [LUTPTVID]=78

-- Update EDR_CodeTableData Trim data if importred
Update EDR_CodeTableData SET 
[Column1]=LTRIM(RTRIM([Column1])),
[Column2]=LTRIM(RTRIM([Column2])),
[Column3]=LTRIM(RTRIM([Column3])),
[Column4]=LTRIM(RTRIM([Column4])),
[Column5]=LTRIM(RTRIM([Column5])),
[Column6]=LTRIM(RTRIM([Column6])),
[Column7]=LTRIM(RTRIM([Column7])),
[Column8]=LTRIM(RTRIM([Column8])),
[Column9]=LTRIM(RTRIM([Column9])),
[Column10]=LTRIM(RTRIM([Column10])),
[Column11]=LTRIM(RTRIM([Column11])),
[Column12]=LTRIM(RTRIM([Column12])),
[Column13]=LTRIM(RTRIM([Column13])),
[Column14]=LTRIM(RTRIM([Column14])),
[Column15]=LTRIM(RTRIM([Column15])),
[Column16]=LTRIM(RTRIM([Column16])),
[Column17]=LTRIM(RTRIM([Column17])),
[Column18]=LTRIM(RTRIM([Column18])),
[Column19]=LTRIM(RTRIM([Column19])),
[Column20]=LTRIM(RTRIM([Column20])),
[Column21]=LTRIM(RTRIM([Column21])),
[Column22]=LTRIM(RTRIM([Column22])),
[Column23]=LTRIM(RTRIM([Column23])),
[Column24]=LTRIM(RTRIM([Column24])),
[Column25]=LTRIM(RTRIM([Column25])),
[Column26]=LTRIM(RTRIM([Column26])),
[Column27]=LTRIM(RTRIM([Column27])),
[Column28]=LTRIM(RTRIM([Column28])),
[Column29]=LTRIM(RTRIM([Column29])),
[Column30]=LTRIM(RTRIM([Column30])),
[Column31]=LTRIM(RTRIM([Column31])),
[Column32]=LTRIM(RTRIM([Column32])),
[Column33]=LTRIM(RTRIM([Column33]))
WHERE CodeTableId in (Select CodeTableId from EDR_CodeTable WITH (NOLOCK) where IsImported =1)

--DE267942: Fix RateFileVariable

DELETE FROM LUT_RateFileVariable WHERE LUTRFVID = 1406 OR (LUTRFVID >= 10192 AND LUTRFVID <= 10272)

INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (1406,   2609, 12, 96, 2, NULL, NULL, CAST(N'2022-12-23T11:26:09.877' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10192, 10633, 2, 257, 2, NULL, NULL, CAST(N'2022-12-23T11:24:25.657' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10193, 10634, 2, 261, 2, NULL, NULL, CAST(N'2022-12-23T11:24:25.673' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10194, 10635, 2, 267, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.687' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10195, 10636, 2, 268, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.703' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10196, 10637, 2, 269, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.720' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10197, 10638, 2, 270, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.733' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10198, 10639, 2, 271, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.733' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10199, 10640, 2, 272, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.753' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10200, 10641, 2, 273, 1, NULL, NULL, CAST(N'2022-12-23T11:24:25.753' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10201, 10600, 2, 1, 16, NULL, NULL, CAST(N'2022-12-23T11:26:08.880' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10202, 10600, 8, 1, 16, NULL, NULL, CAST(N'2022-12-23T11:26:08.927' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10203, 10600, 14, 1, 16, NULL, NULL, CAST(N'2022-12-23T11:26:08.970' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10204, 10601, 2, 1, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.030' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10205, 10601, 8, 1, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.080' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10206, 10601, 14, 1, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.160' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10207, 10602, 2, 11, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.250' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10208, 10602, 8, 11, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.313' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10209, 10602, 14, 11, 10, NULL, NULL, CAST(N'2022-12-23T11:26:09.377' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10210, 10603, 2, 17, 13, NULL, NULL, CAST(N'2022-12-23T11:26:09.440' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10211, 10603, 8, 17, 13, NULL, NULL, CAST(N'2022-12-23T11:26:09.503' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10212, 10603, 14, 17, 13, NULL, NULL, CAST(N'2022-12-23T11:26:09.550' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10213, 10604, 8, 32, 25, NULL, NULL, CAST(N'2022-12-23T11:26:09.620' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10214, 10605, 8, 57, 5, NULL, NULL, CAST(N'2022-12-23T11:26:09.657' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10215, 10606, 2, 36, 8, NULL, NULL, CAST(N'2022-12-23T11:26:09.703' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10216, 10606, 14, 30, 8, NULL, NULL, CAST(N'2022-12-23T11:26:09.737' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10217, 10607, 2, 52, 2, NULL, NULL, CAST(N'2022-12-23T11:26:09.800' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10218, 10607, 14, 504, 2, NULL, NULL, CAST(N'2022-12-23T11:26:09.830' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10219, 10608, 8, 96, 2, NULL, NULL, CAST(N'2022-12-23T11:26:09.877' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10220, 10609, 2, 160, 1, NULL, NULL, CAST(N'2022-12-23T11:26:09.923' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10221, 10609, 8, 95, 1, NULL, NULL, CAST(N'2022-12-23T11:26:09.967' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10222, 10610, 2, 21, 9, NULL, NULL, CAST(N'2022-12-23T11:26:10.017' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10223, 10610, 8, 21, 9, NULL, NULL, CAST(N'2022-12-23T11:26:10.063' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10224, 10610, 14, 21, 9, NULL, NULL, CAST(N'2022-12-23T11:26:10.110' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10225, 10617, 2, 56, 2, NULL, NULL, CAST(N'2022-12-23T11:26:33.520' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10226, 10617, 14, 56, 2, NULL, NULL, CAST(N'2022-12-23T11:26:33.813' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10227, 10618, 2, 60, 3, NULL, NULL, CAST(N'2022-12-23T11:26:34.090' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10228, 10619, 2, 304, 1, NULL, NULL, CAST(N'2022-12-23T11:26:34.373' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10229, 10625, 2, 231, 3, NULL, NULL, CAST(N'2022-12-23T11:26:35.647' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10230, 10626, 2, 234, 1, NULL, NULL, CAST(N'2022-12-23T11:26:35.740' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10231, 10627, 2, 274, 2, NULL, NULL, CAST(N'2022-12-23T11:26:35.833' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10232, 10665, 2, 229, 2, NULL, NULL, CAST(N'2022-12-26T23:00:09.030' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10233, 10666, 2, 89, 1, NULL, NULL, CAST(N'2022-12-26T23:00:09.030' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10234, 10667, 2, 283, 20, NULL, NULL, CAST(N'2022-12-26T23:00:09.030' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10235, 10607, 8, 62, 2, NULL, NULL, CAST(N'2022-12-29T21:22:22.857' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10236, 10611, 2, 222, 1, NULL, NULL, CAST(N'2023-01-20T03:27:59.217' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10237, 10612, 2, 159, 1, NULL, NULL, CAST(N'2023-01-20T03:55:59.893' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10238, 10669, 2, 32, 4, NULL, NULL, CAST(N'2023-01-24T02:11:33.693' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10239, 10670, 2, 44, 8, NULL, NULL, CAST(N'2023-01-24T04:18:30.117' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10240, 10671, 2, 54, 2, NULL, NULL, CAST(N'2023-01-24T04:50:26.703' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10241, 10672, 2, 58, 2, NULL, NULL, CAST(N'2023-01-24T05:10:38.707' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10242, 10673, 2, 63, 3, NULL, NULL, CAST(N'2023-01-24T05:53:07.420' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10243, 10674, 2, 66, 2, NULL, NULL, CAST(N'2023-01-24T07:05:21.497' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10244, 10675, 2, 68, 2, NULL, NULL, CAST(N'2023-01-24T07:25:26.653' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10245, 10676, 2, 70, 2, NULL, NULL, CAST(N'2023-01-24T07:43:42.697' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10246, 10677, 2, 72, 1, NULL, NULL, CAST(N'2023-01-24T08:14:14.710' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10247, 10678, 2, 73, 3, NULL, NULL, CAST(N'2023-01-24T08:40:34.420' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10248, 10679, 2, 96, 10, NULL, NULL, CAST(N'2023-01-27T02:21:22.440' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10249, 10680, 2, 106, 10, NULL, NULL, CAST(N'2023-01-27T02:36:52.160' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10250, 10681, 2, 117, 1, NULL, NULL, CAST(N'2023-01-27T04:05:11.453' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10251, 10682, 2, 118, 1, NULL, NULL, CAST(N'2023-01-27T04:23:33.380' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10252, 10683, 2, 149, 1, NULL, NULL, CAST(N'2023-01-27T04:44:25.620' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10253, 10684, 2, 150, 1, NULL, NULL, CAST(N'2023-01-27T05:05:17.380' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10254, 10685, 2, 151, 8, NULL, NULL, CAST(N'2023-01-27T05:28:40.960' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10255, 10686, 2, 228, 1, NULL, NULL, CAST(N'2023-01-27T06:01:31.047' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10256, 10687, 2, 259, 2, NULL, NULL, CAST(N'2023-01-27T06:29:04.343' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10257, 10688, 2, 263, 4, NULL, NULL, CAST(N'2023-01-27T07:32:41.187' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10258, 10689, 2, 307, 494, NULL, NULL, CAST(N'2023-01-30T00:55:32.030' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10259, 10693, 2, 303, 1, NULL, NULL, CAST(N'2023-01-30T07:36:57.193' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10260, 10694, 2, 162, 2, NULL, NULL, CAST(N'2023-01-30T07:54:15.943' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10261, 10695, 2, 164, 14, NULL, NULL, CAST(N'2023-01-30T08:55:13.543' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10262, 10650, 2, 76, 1, NULL, NULL, CAST(N'2023-01-31T02:04:29.707' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10263, 10642, 2, 77, 1, NULL, NULL, CAST(N'2023-01-31T02:35:52.220' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10264, 10657, 2, 78, 1, NULL, NULL, CAST(N'2023-01-31T04:48:58.803' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10265, 10654, 2, 79, 1, NULL, NULL, CAST(N'2023-01-31T05:13:25.200' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10266, 10655, 2, 80, 1, NULL, NULL, CAST(N'2023-01-31T05:43:11.377' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10267, 10643, 2, 81, 1, NULL, NULL, CAST(N'2023-01-31T06:18:37.193' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10268, 10656, 2, 82, 1, NULL, NULL, CAST(N'2023-01-31T07:07:03.740' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10269, 10651, 2, 83, 1, NULL, NULL, CAST(N'2023-01-31T07:34:13.990' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10270, 10652, 2, 84, 1, NULL, NULL, CAST(N'2023-01-31T07:59:07.320' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10271, 10661, 2, 85, 1, NULL, NULL, CAST(N'2023-01-31T22:38:30.247' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10272, 10659, 2, 86, 1, NULL, NULL, CAST(N'2023-01-31T23:01:54.820' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10273, 10668, 2, 87, 1, NULL, NULL, CAST(N'2023-01-31T23:25:59.217' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10274, 10660, 2, 88, 1, NULL, NULL, CAST(N'2023-02-01T00:10:40.690' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10275, 10649, 2, 90, 1, NULL, NULL, CAST(N'2023-02-01T01:45:33.730' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10276, 10644, 2, 91, 1, NULL, NULL, CAST(N'2023-02-01T02:23:41.433' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10277, 10645, 2, 92, 1, NULL, NULL, CAST(N'2023-02-01T02:41:07.793' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10278, 10646, 2, 93, 1, NULL, NULL, CAST(N'2023-02-01T03:04:20.940' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10279, 10647, 2, 94, 1, NULL, NULL, CAST(N'2023-02-01T03:23:58.783' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10280, 10648, 2, 95, 1, NULL, NULL, CAST(N'2023-02-01T03:41:49.723' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10281, 10690, 8, 64, 31, NULL, NULL, CAST(N'2023-02-02T22:38:01.213' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10282, 10691, 8, 101, 91, NULL, NULL, CAST(N'2023-02-02T22:38:01.247' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10283, 10692, 8, 30, 2, NULL, NULL, CAST(N'2023-02-02T22:38:01.277' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10284, 10613, 8, 99, 2, NULL, NULL, CAST(N'2023-02-02T22:38:01.310' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10285, 10612, 8, 98, 1, NULL, NULL, CAST(N'2023-02-02T22:41:21.230' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10286, 10613, 2, 30, 2, NULL, NULL, CAST(N'2023-02-24T13:40:12.733' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10287, 10614, 2, 276, 7, NULL, NULL, CAST(N'2023-02-27T13:56:45.880' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10288, 10653, 2, 139, 10, NULL, NULL, CAST(N'2023-02-27T16:23:25.773' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10289, 10658, 2, 161, 1, NULL, NULL, CAST(N'2023-02-27T16:52:24.670' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10290, 10662, 2, 119, 20, NULL, NULL, CAST(N'2023-02-27T18:31:31.227' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10291, 10663, 2, 236, 20, NULL, NULL, CAST(N'2023-02-28T13:07:57.980' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10292, 10664, 2, 178, 20, NULL, NULL, CAST(N'2023-02-28T13:26:14.250' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10293, 10628, 2, 223, 1, NULL, NULL, CAST(N'2023-02-28T16:29:46.140' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10294, 10629, 2, 224, 1, NULL, NULL, CAST(N'2023-02-28T16:39:18.853' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10295, 10630, 2, 225, 3, NULL, NULL, CAST(N'2023-02-28T16:48:52.377' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10296, 10631, 2, 256, 1, NULL, NULL, CAST(N'2023-02-28T16:56:50.327' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10297, 10620, 2, 116, 1, NULL, NULL, CAST(N'2023-03-01T16:35:12.363' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10298, 10621, 2, 220, 2, NULL, NULL, CAST(N'2023-03-01T16:48:12.590' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10299, 10622, 2, 218, 2, NULL, NULL, CAST(N'2023-03-01T17:14:08.577' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10300, 10623, 2, 198, 20, NULL, NULL, CAST(N'2023-03-01T17:25:17.387' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10301, 10624, 2, 235, 1, NULL, NULL, CAST(N'2023-03-01T17:32:53.580' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10302, 10620, 14, 506, 1, NULL, NULL, CAST(N'2023-03-03T13:54:53.370' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10303, 10632, 2, 305, 2, NULL, NULL, CAST(N'2023-03-18T11:00:06.967' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10304, 10600, 25, 1, 16, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10305, 10601, 25, 1, 10, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10306, 10602, 25, 11, 10, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10307, 10603, 25, 17, 13, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10308, 10606, 25, 30, 8, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)
INSERT [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [StartPositionInCobol], [VariableSizeInCobol], [InsertedTS], [ModifiedTS]) VALUES (10309, 10610, 25, 21, 9, NULL, NULL, CAST(N'2024-03-07T00:00:00.000' AS DateTime), NULL)



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