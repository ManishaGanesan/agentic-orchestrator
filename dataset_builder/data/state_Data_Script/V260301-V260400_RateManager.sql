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

-- US1566826: V2604.00 - Add a New Physician Pro Payment System
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
                psp.[ppc_vers]
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
            , [lvl_change_option], [edc_action], [facility_type], [rf_vers], [LUTWTID], [PhysEdit_MaxDME], [moe_flag], [mcd_override_id], [cah_oce_flag],[othermedicare_flag], [ppc_vers] -- new column Din      
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
                psp.ppc_vers
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
            , [lvl_change_option], [edc_action], [facility_type], [rf_vers], [LUTWTID], [PhysEdit_MaxDME], [moe_flag], [mcd_override_id], [cah_oce_flag],[othermedicare_flag], [ppc_vers] -- new column Din      
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

PRINT N'Altering Procedure [dbo].[SP_EditAll_Save]...';
GO
-- ==================================================================================                
-- Author:  Amy Zhao                
-- Create date: 06/14/2012                
--                 
-- ===================================================================================     
-- Isa Paine Modified On 5/10/16 for US241618: New PPS Medicaid APG Pro - CopyDelete/Edit All
-- Isa Paine Modified On 8/12/16 for US266201: ER - DB - Edit All support for Facility specific changes.
-- 20190220.US510049.Vadim		Validate calculated values for Medicare CMS before attempting to save
-- Pratibha Rana Modified on 8/4/21 for DE217385: Edit All - weights Restriction validation not happening if weight file selected both in apply facility and apply npi/taxonomy for Medicare SNF and Medicare HHA
-- 20230510.US1049346.Mani	Updated field values with default value if pricer effective date is not with in range of display start and end date
-- Modified: 12/07/2023
-- US1127486: V2312.00 - Add new Pro pricer: Medicaid MS-DRG Pro - Rate and Metadata
-- Added condition for Pro Pricer
-- Modified: 04/07/2026  
-- US1566826: V2604.00 - Add a New Physician Pro Payment System
-- Added condition for Pro Pricer
/*************************************************************************************                
--Testing PricerType Medicare (CMS)
exec [dbo].[SP_EditAll_Save] 
	@LoginSessionGUID='A1E2D8C1-4374-4372-83FA-D04FDC8D38F8',
	@LUTPTID=36,
	@ConfigurationXml = '<Configurations>
							<Configuration>payer_id=''PayerID2'' and facility_id=''000001'' and EffdateFrom>=''7/23/2016'' and EffdateTo<=''7/24/2016''</Configuration>
							<Configuration>payer_id=''QE'' and facility_id=''000001'' and EffdateFrom>=''7/1/2016'' and EffdateTo<=''7/2/2016''</Configuration>
							<Configuration>NPI=''NPIGRP'' and Taxonomy=''TESTQA''</Configuration>
							<Configuration>NPI=''tony'' and Taxonomy=''test'' AND EffdateFrom>=''4/1/2015'' and EffdateTo<=''7/8/2015''</Configuration>
							<Configuration>facility_id=''123'' AND payer_id=''amy1'' AND grpr_vers =''32'' AND grpr_type=''01'' AND EffdateFrom>=''4/1/2015'' and EffdateTo<=''12/2/2016''</Configuration>
							<Configuration>grpr_vers =''33'' AND grpr_type=''11''</Configuration>
						</Configurations>',
	@VariableNameValuesForEditUpdate='dsc_flag=1,poa_flag=1,hac_flag=1,hac_override_id=''99'',icd9_routing=''1'', user_key='''',line_bypass=''0'',map_category=''99'',map_override_id=''99'',map_type=''02'',icd9_map=''1'', bwgt_option='''',disch_drg_option='''',hac_version=''''',
	@VariableNameValuesForPPSUpdate='rl=''099'', rnl=''099'', nl=''099'', nnl=''099'', rp=''099'', bmcfl=''099'', bmcfc=''099'', mcfl=''099'', mcfcl=''099'', cot=''099'', cof=''099'', fp=''099'', dshreduc=''00099'', uncomp_dsh=''099'', ptype=''22'''

--Testing PricerType TRICARE/CHAMPUS
exec [dbo].[SP_EditAll_Save] 
	@LoginSessionGUID='A1E2D8C1-4374-4372-83FA-D04FDC8D38F8',
	@LUTPTID=41,
	@ConfigurationXml = '<Configurations>
							<Configuration>facility_id=''300114761150001''</Configuration>
							<Configuration>NPI=''CHAMPUS1'' AND payer_id=''QETEST'' AND grpr_type=''03'' AND grpr_vers=''23''</Configuration>
						</Configurations>',
	@VariableNameValuesForEditUpdate='',
	@VariableNameValuesForPPSUpdate='lrasa=''001'', nlrasa=''002'', lrchd=''003'', nlrchd=''004'', labor=''00005'', wi=''00006'', imea=''0000007'', rcc=''00008'', cot=''009'', cotcn=''010'', cof=''011'', sof=''012'', ntf=''013'', opcotper=''00014'', ccoladj=''00015'', mcfl=''016'', mcfc=''017'', mcfbl=''018'', mcfbc=''019'', mcfn=''020'', psycunit=''1'', waiver=''N'', markup=''000021'', pd_psych=''022'', waiver_factor=''00023'''

--Testing PricerType Contract APC
exec [dbo].[SP_EditAll_Save] 
	@LoginSessionGUID='A1E2D8C1-4374-4372-83FA-D04FDC8D38F8',
	@LUTPTID=14,
	@ConfigurationXml = '<Configurations>
							<Configuration>facility_id=''amy'' AND EffdateFrom>=''1/1/2015'' AND EffdateTo<=''4/1/2016''</Configuration>
							<Configuration>NPI=''1023001146'' AND payer_id=''40'' AND grpr_vers=''08'' AND grpr_type=''55''</Configuration>
							<Configuration>NPI=''1023001146'' AND EffdateFrom>=''4/1/2015''</Configuration>
						</Configurations>',
	@VariableNameValuesForEditUpdate='',
	@VariableNameValuesForPPSUpdate='labor=''000009'', wi=''000009'', rural_fact=''00009'', discount1=''00009'', discount2=''00009'', discount3=''00009'', discount4=''00009'', dmopct=''00009'''

--Testing PricerType Medicaid APR-DRG Pro
exec [dbo].[SP_EditAll_Save] 
	@LoginSessionGUID='A1E2D8C1-4374-4372-83FA-D04FDC8D38F8',
	@LUTPTID=84,
	@ConfigurationXml = '<Configurations>
							<Configuration>facility_id=''000001'' AND EffdateTo<=''7/22/2016''</Configuration>
							<Configuration>NPI=''NPI001'' AND taxonomy=''TAX001'' AND EffdateFrom>=''10/1/2016'' AND EffdateTo<=''10/2/2016''</Configuration>
						</Configurations>',
	@VariableNameValuesForEditUpdate='dsc_flag=''1'',poa_flag=''1'',hac_flag=''1'',hac_override_id=''99'', map_category='''',map_override_id='''',map_type=''00'',icd9_map=''0''',
	@VariableNameValuesForPPSUpdate='proc_array=''00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'', state_id=''MA'', base=''001'', markup=''00002'', ppr=''00003'', capital=''004'', malprac=''005'', orgpay=''006'', mededpay=''007'', type=''01'', pol_adj1=''00009'', pol_adj2=''00010'''

--Testing PricerType Medicaid APG Pro
exec [dbo].[SP_EditAll_Save] 
	@LoginSessionGUID='A1E2D8C1-4374-4372-83FA-D04FDC8D38F8',
	@LUTPTID=86,
	@ConfigurationXml = '<Configurations>
							<Configuration>facility_id=''LuhaiTest01'' AND payer_id=''Luhai''</Configuration>
							<Configuration>facility_id=''LuhaiTest01C'' AND EffdateFrom>=''4/1/2016'' AND EffdateTo<=''4/1/2016''</Configuration>
						</Configurations>',
	@VariableNameValuesForEditUpdate='',
	@VariableNameValuesForPPSUpdate='proc_array=''00010002005000510103000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'', state_id=''OT'', base_rate=''099'', markup=''00099'', facility_type=''1'', disc1=''00099'', disc2=''00099'', disc3=''00099'', ancdisc1=''00099'', ancdisc2=''00099'', ancdisc3=''00099'', termdisc=''00099'', bilatdisc=''00099'', rcc=''00099'', factor1=''00099'', rate1=''099'', rate2=''099'', fstable=''FS099'', fsexttable=''EXFS002'''
 
**************************************************************************************/
ALTER PROCEDURE [dbo].[SP_EditAll_Save] @LoginSessionGUID uniqueidentifier
, @LUTPTID int
, @ConfigurationXML varchar(max)
, @VariableNameValuesForEditUpdate varchar(max)
, @VariableNamesForPPSUpdate varchar(max)
, @VariableValuesForPPSUpdate varchar(max)
, @SharedWeightDTAPSPIDForFacility bigint
, @SharedWeightDTAPSPIDForNPI bigint
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from                
	-- interfering with SELECT statements.                
	SET NOCOUNT ON;
	
	--These variables are used in the conversion of @ConfigurationXML into a WHERE clause.
	DECLARE @whereClause NVARCHAR(max)
	DECLARE @iDoc INT
	DECLARE @startIndex INT = 0
	DECLARE @dateBeginIndex INT = 0
	DECLARE @dateEndIndex INT = 0
	DECLARE @dateLength INT = 0
	DECLARE @recordCount INT = 0
	DECLARE @recordIndex INT = 1
	DECLARE @numberOfConfigurationRows INT = 0
	DECLARE @dateValue VARCHAR(20)
	DECLARE @newDateValue VARCHAR(40)
	DECLARE @EFFFDATEFROM VARCHAR(13) = 'EffdateFrom>='
	DECLARE @EFFFDATETO VARCHAR(13) = 'EffdateTo%3c='
	DECLARE @rowWhereClause NVARCHAR(max)
	DECLARE @XMLROWPATTERN VARCHAR(29) = '/Configurations/Configuration'
	DECLARE @XMLROWNAME VARCHAR(13) = 'Configuration'


	-- variables for try-catch                  
	DECLARE	@errSeverity int,
			@errMsg varchar(max),
			@currentStep varchar(50)

	-- variables for sp                
	DECLARE	@PricerTypeDescr varchar(500),
			@PricerTableName varchar(30),
			@QueryStr varchar(max),
			@retCount int,
			@sharedCount int,
			@linkedSharedCount int

	BEGIN TRY
	
		BEGIN TRAN
		
			IF (ISNULL(@LUTPTID,0) = 0
				OR @LUTPTID < 1)
			BEGIN
				RAISERROR ('Pricer Type is required', 16, 1)
			END

			-- other variables                    
			DECLARE @LoginUser varchar(500)

			SET @retCount = 0
			SET @currentStep = 'Get login user name.'
			EXEC sp_GetLoguser	@LoginSessionGUID,
								@LoginUser OUT

			SET @currentStep = 'Get PricerTableName from LUT_PricerType.'
			SELECT
				@PricerTypeDescr = PricerTypeDescr,
				@PricerTableName = PricerTableName
			FROM LUT_PricerType
			WHERE LUTPTID = @LUTPTID
			AND Enabled = 1

			DECLARE @QueryString nvarchar(max)
			DECLARE @QueryStringEdit nvarchar(max) 

			SET @currentStep = 'Build query string to update '
			SET @QueryStringEdit =N''

			CREATE TABLE #PPSIDs (
				PPSID bigint,
				DTAPSPID bigint,
				npi_flag int,
				havewt varchar(10),
				UpdatedSharedWeightDTAPSPID bigint,
				HasRestrictions bit,
				patientType varchar(2),
				effectiveDate date
			)
			CREATE INDEX #IDX_PPS ON #PPSIDs (PPSID)
			CREATE INDEX #IDX_PSPID ON #PPSIDs (DTAPSPID)

			--Convert @ConfigurationXml to XML Doc
			SET @ConfigurationXml = REPLACE(@ConfigurationXml, '<=','%3c=')
			EXEC sp_xml_preparedocument	@iDoc OUTPUT, @ConfigurationXml;
			--Convert XML Doc to temp table
			SELECT ROW_NUMBER() OVER (ORDER BY Id) AS Row, * 
			INTO #tmpConfiguration
			FROM OPENXML (@idoc, '/Configurations/Configuration',2) WHERE text IS NOT NULL 

			SELECT TOP 1 @recordCount = ROW FROM #tmpConfiguration ORDER BY Row DESC
			
			SELECT @numberOfConfigurationRows = COUNT(localname)
			FROM OPENXML (@idoc, @XMLROWPATTERN,1) 
			WHERE localname = @XMLROWNAME 
			
			IF (@recordCount <> @numberOfConfigurationRows)
			BEGIN
				RAISERROR ('A configuration detail is required for each configuration row.', 16, 1)
			END
			
			--Cycle through each row the table and reformat the To and From date fields.
			WHILE @recordIndex <= @recordCount
			BEGIN
				--Get Where Clause Row 
				SELECT @rowWhereClause = text FROM #tmpConfiguration WHERE Row = @recordIndex
				
				--Reformat EffDateFrom
				SET @startIndex = CHARINDEX(@EFFFDATEFROM,@rowWhereClause,0)
				IF (@startIndex > 0)
				BEGIN
					SET @dateBeginIndex = @startIndex + LEN(@EFFFDATEFROM) + 1
					SET @dateEndIndex = CHARINDEX('''',@rowWhereClause,@startIndex + LEN(@EFFFDATEFROM + ''''))
					SET @dateLength = @dateEndIndex - @dateBeginIndex
					SET @dateValue = '''' + SUBSTRING(@rowWhereClause,@dateBeginIndex,@dateLength) + '''';
					SET @newDateValue = 'CAST(''' + SUBSTRING(@rowWhereClause,@dateBeginIndex,@dateLength) + ''' AS datetime)'
					SET @rowWhereClause = REPLACE(@rowWhereClause, @dateValue,@newDateValue)
					UPDATE #tmpConfiguration 
					SET text = @rowWhereClause
					WHERE Row = @recordIndex
				END
				
				--Reformat EffDateTo
				SELECT @rowWhereClause = text FROM #tmpConfiguration WHERE Row = @recordIndex
				SET @startIndex = CHARINDEX(@EFFFDATETO,@rowWhereClause,0)
				IF (@startIndex > 0)
				BEGIN
					SET @dateBeginIndex = @startIndex + LEN(@EFFFDATETO) + 1
					SET @dateEndIndex = CHARINDEX('''',@rowWhereClause,@startIndex + LEN(@EFFFDATETO + ''''))--@EFFFDATETO
					SET @dateLength = @dateEndIndex -  @dateBeginIndex
					SET @dateValue = '''' + SUBSTRING(@rowWhereClause,@dateBeginIndex,@dateLength) + '''';
					SET @newDateValue = 'CAST(''' + SUBSTRING(@rowWhereClause,@dateBeginIndex,@dateLength) + ' 23:59:59' + ''' AS datetime)'
					SET @rowWhereClause = REPLACE(@rowWhereClause, @dateValue,@newDateValue)
					UPDATE #tmpConfiguration 
					SET text = @rowWhereClause
					WHERE Row = @recordIndex
				END 
				
				SET @startIndex = 0;
				SET @dateBeginIndex = 0;
				SET @dateEndIndex = 0; 
				SET @dateLength = 0;
				SET @recordIndex = @recordIndex + 1
			END
			
			--Add parentheses around each clause of the where statement.
			SELECT @whereClause = COALESCE(@whereClause + ' OR (' , '(') + CAST(text AS NVARCHAR(max)) + ')' FROM #tmpConfiguration
			--Add replace XML friendly %3c= with T-SQL friently <=
			SET @whereClause = REPLACE(@whereClause, '%3c=','<=')
			--Replace both EffdateFrom and EffdateTo with effdate
			SET @whereClause = REPLACE(@whereClause, 'EffdateFrom','effdate')
			SET @whereClause = REPLACE(@whereClause, 'EffdateTo','effdate')
			--Add parentheses around entire where clause to ensure proper functionality
			SET @whereClause = '(' + @whereClause + ')'
			--SELECT @whereClause

			DECLARE @borderdate datetime
			IF (@LUTPTID = 30)
			SELECT @borderdate = effdate FROM LUT_WeightTypeExt WHERE OldLUTWTID=4
			ELSE
			IF (@LUTPTID = 34)
			SELECT @borderdate = effdate FROM LUT_WeightTypeExt WHERE OldLUTWTID=6
			ELSE
			SET @borderdate = ''

			DECLARE @SharedWeightDTAPSPIDForFacilitystr nvarchar(max) = CAST(@SharedWeightDTAPSPIDForFacility AS nvarchar(max))
			DECLARE @SharedWeightDTAPSPIDForNPIstr nvarchar(max) = CAST(@SharedWeightDTAPSPIDForNPI AS nvarchar(max))

			SET @QueryString = 'INSERT INTO #PPSIDs ' +
			'SELECT pps.PPSID, psp.DTAPSPID, psp.npi_flag, psp.havewt,CASE psp.npi_flag WHEN 0 THEN
			COALESCE(NULLIF( ' + @SharedWeightDTAPSPIDForFacilitystr + ' , 0),psp.SharedWeightDTAPSPID) ELSE 
			COALESCE(NULLIF( ' + @SharedWeightDTAPSPIDForNPIstr + ' , 0),psp.SharedWeightDTAPSPID) END AS UpdatedSharedWeightDTAPSPID, CASE psp.npi_flag WHEN 0 THEN
			dbo.udf_SharedWeightRestriction(psp.effdate, ' + '''' + @SharedWeightDTAPSPIDForFacilitystr + '''' + ',' + '''' + CAST(CONVERT(datetime, @borderdate, 101) AS nvarchar) + '''' + ') ELSE
			dbo.udf_SharedWeightRestriction(psp.effdate, ' + '''' + @SharedWeightDTAPSPIDForNPIstr + '''' + ',' + '''' + CAST(CONVERT(datetime, @borderdate, 101) AS nvarchar) + '''' + ') END AS HasRestrictions,    
		    psp.pattype, psp.effdate FROM ' + @PricerTableName + ' pps WITH (NOLOCK)  ' +
			' INNER JOIN DTA_PaySourceAll_VW psp WITH (NOLOCK) ON pps.DTAPSPID = psp.DTAPSPID ' +
			' WHERE ' + @whereClause		 
	
			--END
			SET @currentStep = 'Get PPSIDs '
			EXECUTE (@QueryString)
			--SELECT * FROM #PPSIDs
			-- TO Reset the @@rowcount
			declare @t table (i int)
			update @t set i=5 where i=4
			SET @currentStep = 'Updating...'

			--update weight section    
			  DECLARE @hasWeights bit = 0
			  IF (@SharedWeightDTAPSPIDForFacility != 0
				OR @SharedWeightDTAPSPIDForNPI != 0)
			  BEGIN
				SET @hasWeights = 1
			  END

			-- update the ModifiedTS, LoginUSER and variables in editing section                 
			IF ( @VariableNameValuesForEditUpdate <> '')      
			BEGIN
				SET @QueryStringEdit = 'UPDATE PSP SET ModifiedTS = GETDATE(), LoginUser = '''+ @LoginUser +''' ' +', '+@VariableNameValuesForEditUpdate + ' FROM DTA_PaySourcePricer PSP'
				SET @QueryStringEdit += ' INNER JOIN #PPSIDs pps ON PSP.DTAPSPID = pps.DTAPSPID'  
				SET @QueryStringEdit += ' LEFT OUTER JOIN LUT_RateGrouper rg ON rg.GrouperValue = PSP.grpr_type AND rg.pattype = pps.PatientType '  
			END
			ELSE IF (@VariableValuesForPPSUpdate <> '' AND @VariableNamesForPPSUpdate <> '')
			BEGIN
				SET @QueryStringEdit = 'UPDATE DTA_PaySourcePricer SET ModifiedTS = GETDATE(), LoginUser = '''+ @LoginUser +''' FROM DTA_PaySourcePricer INNER JOIN #PPSIDs pps ON DTA_PaySourcePricer.DTAPSPID = pps.DTAPSPID'
			END

			IF(LEN(@QueryStringEdit) >0)
			BEGIN
				EXECUTE (@QueryStringEdit)
				SET @retCount = @@ROWCOUNT 
			END			   

			


			IF (@hasWeights = 1)
			  BEGIN
				UPDATE psp
				SET psp.ModifiedTS = GETDATE(),
				    psp.LoginUser = @LoginUser,
					psp.tab_filename = NULL,
					psp.LUTWTID = NULL,
				    psp.SharedWeightDTAPSPID = pps.UpdatedSharedWeightDTAPSPID,
					psp.havewt = 'L'
				FROM DTA_PaySourcePricer psp
				INNER JOIN #PPSIDs pps
				  ON psp.DTAPSPID = pps.DTAPSPID
				WHERE psp.DTAPSPID != pps.UpdatedSharedWeightDTAPSPID
				AND pps.HasRestrictions = 0 AND ISNULL(psp.SharedWeightDTAPSPID, 0 ) <> pps.UpdatedSharedWeightDTAPSPID
			  
			  SET @sharedCount=@@ROWCOUNT

			  --get the WeightTableName    
			  DECLARE @WeightTableName varchar(max)

				--create a temp table    
				CREATE TABLE #WeightTables (
				  Rownum int,
				  WeightTableName varchar(max)
				)

				INSERT INTO #WeightTables
				  SELECT
					ROW_NUMBER() OVER (ORDER BY WeightTableName) AS Rownum,
					WeightTableName
				  FROM (SELECT
					ISNULL(ext.OldLUTWTID, wt.LUTWTID) AS LUTWTID,
					wt.WeightTableName
				  FROM LUT_WeightType wt
				  LEFT OUTER JOIN LUT_WeightTypeExt ext
					ON wt.LUTWTID = ext.LUTWTID) lut
				  INNER JOIN LUT_PricerType
					ON LUT_PricerType.LUTWTID = lut.LUTWTID
				  WHERE LUT_PricerType.lutptid = @LUTPTID

				DECLARE @rows int,
						@id int = 1
				SELECT
				  @rows = COUNT(*)
				FROM #WeightTables

				WHILE (@id <= @rows)
				BEGIN
				  SELECT
					@WeightTableName = WeightTableName
				  FROM #WeightTables
				  WHERE #WeightTables.Rownum = @id

				  --delete the data from weight data table    
				  SET @QueryString = 'DELETE w FROM ' + @WeightTableName + ' w INNER JOIN #PPSIDs p    
					ON w.DTAPSPID=p.DTAPSPID WHERE p.havewt=''Y'' AND w.DTAPSPID != p.UpdatedSharedWeightDTAPSPID AND p.UpdatedSharedWeightDTAPSPID IN ('+@SharedWeightDTAPSPIDForFacilitystr+', '+@SharedWeightDTAPSPIDForNPIstr+') AND p.HasRestrictions=0'
				  EXECUTE (@QueryString)
				  SET @id = @id + 1
				END

				 --update the SharedWeightDTAPSPID value of the paysources which has shared weight on the current DTAPSPID (Remove link)  
				 
				 SELECT
				@linkedSharedCount = COUNT(*)
				FROM DTA_PaySourcePricer psp
				INNER JOIN #PPSIDs pps
				  ON psp.SharedWeightDTAPSPID = pps.DTAPSPID
				WHERE dbo.udf_SharedWeightRestriction(effdate, UpdatedSharedWeightDTAPSPID, @borderdate) = 0
				AND psp.DTAPSPID NOT IN (SELECT DTAPSPID FROM #PPSIDs)

				UPDATE psp
				SET psp.ModifiedTS = GETDATE(),
				psp.LoginUser = @LoginUser,
			    psp.SharedWeightDTAPSPID =
				pps.UpdatedSharedWeightDTAPSPID
				FROM DTA_PaySourcePricer psp WITH (NOLOCK)
				INNER JOIN #PPSIDs pps
				  ON psp.SharedWeightDTAPSPID = pps.DTAPSPID
				WHERE pps.havewt = 'Y'
				AND psp.DTAPSPID !=
				pps.UpdatedSharedWeightDTAPSPID AND pps.HasRestrictions = 0

				--	US867896: RM exports rates that are marked "Do not export" with shared weights
				DECLARE @RemoveDoNotExportFlag BIT = 0
				IF @SharedWeightDTAPSPIDForFacility != 0
				BEGIN
					SET @RemoveDoNotExportFlag = [dbo].[udf_DTA_PaySourcePricer_Remove_Do_Not_Export_Flag](@SharedWeightDTAPSPIDForFacility)
					IF @RemoveDoNotExportFlag = 1
						UPDATE DTA_PaySourcePricer SET DoNotExport = 0 WHERE DTAPSPID = @SharedWeightDTAPSPIDForFacility
				END
			
				IF @SharedWeightDTAPSPIDForNPI != 0
				BEGIN
					SET @RemoveDoNotExportFlag = [dbo].[udf_DTA_PaySourcePricer_Remove_Do_Not_Export_Flag](@SharedWeightDTAPSPIDForNPI)
					IF @RemoveDoNotExportFlag = 1
						UPDATE DTA_PaySourcePricer SET DoNotExport = 0 WHERE DTAPSPID = @SharedWeightDTAPSPIDForNPI
				END
			  END
			
		   -- Get columns with default value or user entered value based on Effective Date lies between DisplayStartDate and DisplayEndDate
			DECLARE @Columns VARCHAR(MAX) = N''
			DECLARE @VariableNameValuesForPPSUpdate VARCHAR(MAX)
			DECLARE @ColumnNamesTbl TABLE(
				ID INT NOT NULL IDENTITY(1, 1),
				ColumnName VARCHAR(128)
			)

			DECLARE @ColumnValuesTbl TABLE(
				ID INT NOT NULL IDENTITY(1, 1),
				ColumnValue VARCHAR(MAX)
			)

			DECLARE @ColumnNameValuesTbl TABLE(
				ColumnName VARCHAR(128),
				ColumnValue VARCHAR(MAX)
			)

			INSERT INTO @ColumnNamesTbl
			SELECT RTRIM(LTRIM(splitdata)) FROM [dbo].[udf_SplitStringBySeperator](@VariableNamesForPPSUpdate, ',')

			INSERT INTO @ColumnValuesTbl
			SELECT RTRIM(LTRIM(splitdata)) FROM [dbo].[udf_SplitStringBySeperator](@VariableValuesForPPSUpdate, ',') 

			--Create table with column name & column values
			INSERT INTO @ColumnNameValuesTbl
			SELECT ColumnName, ColumnValue FROM @ColumnNamesTbl n INNER JOIN @ColumnValuesTbl v on n.ID = v.ID

			IF(@LUTPTID = 84 OR @LUTPTID = 86 OR @LUTPTID = 96 OR @LUTPTID = 98)
			BEGIN
				SELECT @Columns = COALESCE(@Columns + ',' + tmp.ColumnName + '=' + tmp.ColumnValue,@Columns)
				FROM @ColumnNameValuesTbl tmp
				SET @VariableNameValuesForPPSUpdate = STUFF(@Columns,1,1,'')
			END
			ELSE
			BEGIN
				SELECT @Columns = COALESCE(@Columns + ' , '+ tmp.ColumnName + ' =' + REPLACE(REPLACE(REPLACE(ColumnQuery,' EffDate ',' pps.effectiveDate'),'##ColumnName##',tmp.ColumnValue),' AS ' + col.ColumnName,''), ColumnQuery) 
				FROM udf_GetPpsTableColumns(@LUTPTID, NULL) col
				INNER JOIN @ColumnNameValuesTbl tmp
				ON col.ColumnName = tmp.ColumnName
				SET @VariableNameValuesForPPSUpdate = STUFF(@Columns,1,3,'')
			END

			--update variables in pricer section      
			IF (@VariableNameValuesForPPSUpdate <> '')
			BEGIN
				--SET @QueryString ='UPDATE PPS_medprc_A SET ' + @VariableNameValuesForPPSUpdate + ' FROM PPS_medprc_A WITH (NOLOCK) INNER JOIN #PPSIDs pps WITH (NOLOCK) ON PPS_medprc_A.PPSID = pps.PPSID' -- for example @VariableNameValuesForPPSUpate looks like: rl='124',nl='1111'      

				SET @QueryString = 'UPDATE ' + @PricerTableName + ' SET ' + @VariableNameValuesForPPSUpdate + ' FROM ' + @PricerTableName + ' WITH (NOLOCK) INNER JOIN #PPSIDs pps WITH (NOLOCK) ON ' + @PricerTableName + '.PPSID = pps.PPSID'
				EXECUTE (@QueryString)
				SET @retCount = @@ROWCOUNT
				--SELECT @retCount AS 'PPSFieldUpdates'
			END

			

			IF (@LUTPTID = 84 OR @LUTPTID = 86 OR @LUTPTID = 96 OR @LUTPTID = 98)
			BEGIN

				-- get state_id
				DECLARE	@state_id varchar(2)

				SELECT @state_id = SUBSTRING(ColumnValue, 2, LEN(ColumnValue) - 2) FROM @ColumnNameValuesTbl WHERE ColumnName = N'state_id'

				IF (@state_id <> '')
				BEGIN
					
					IF (@state_id <> 'OT')
					BEGIN
						DECLARE @ParameterList nvarchar(max);
						SET @ParameterList = N'
							@state_id varchar(2),
							@LUTPTID int'
											
						SET @QueryString = 'UPDATE ' + @PricerTableName + '' + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + N'SET proc_array = (SELECT LEFT(RTRIM(ISNULL(procs,''''))+REPLICATE(0,CASE WHEN @LUTPTID=98 THEN 390 ELSE 200 END),CASE WHEN @LUTPTID=98 THEN 390 ELSE 200 END) FROM [dbo].[udf_LUT_PricerTypeAPRPro_StateProcedure_Get](@state_id, psp.effdate,@LUTPTID))' + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + N', state_id=CASE WHEN @state_id=''NN'' THEN '''' ELSE @state_id END ' + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + N'FROM ' + @PricerTableName + ' pps INNER JOIN DTA_PaySourceAll_VW psp WITH (NOLOCK) ON pps.DTAPSPID= psp.DTAPSPID' + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + N'	INNER JOIN #PPSIDs tmppps ON psp.DTAPSPID=tmppps.DTAPSPID ' + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + N'	LEFT OUTER JOIN LUT_PricerTypeAPRPro_State lut ON psp.effdate=lut.effdate and lut.state_id=@state_id and lut.LUTPTID=@LUTPTID' + CHAR(13) + CHAR(10)
						PRINT @QueryString
						EXEC SP_EXECUTESQL	@QueryString,
											@ParameterList,
											@state_id = @state_id,
											@LUTPTID = @LUTPTID

					END

					-- update medex_sw if proc_array contains medex variable then medex_sw=1
					IF (@LUTPTID = 84 OR @LUTPTID = 86 OR @LUTPTID = 96 OR @LUTPTID = 98) -- Amy: hardcode now until the pricer type Medicaid APG Pro implement medext_sw
					BEGIN
						SET @QueryString = 'UPDATE ' + @PricerTableName + ' SET '  + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + 'medext_sw=' + '[dbo].[udf_IsProcArrContainsMedext](proc_array, ' + CAST(@LUTPTID AS VARCHAR(50)) + ')' + + CHAR(13) + CHAR(10)
						SET @QueryString = @QueryString + ' FROM ' + @PricerTableName + ' WITH (NOLOCK) INNER JOIN #PPSIDs pps WITH (NOLOCK) ON ' + @PricerTableName + '.PPSID = pps.PPSID'
						PRINT @QueryString
						EXECUTE (@QueryString)
					END
				END		
			END

			-- this block will update medext_sw flag in PPS table only for saved records which have data with medext flag = 1 in LUT table
			IF @LUTPTID = 53	-- Multipricer and Medicaid APG Pro only for now
			BEGIN
				EXEC [dbo].[SP_PPS_UpdateMedextFlag] @LoginSessionGUID, @LUTPTID
			END

			-- This block will recalculate the calculated field values
			IF @LUTPTID = 36 OR @LUTPTID = 41 -- Medicare DRG and Tricare/Champus
			BEGIN
				DECLARE @DTAPSPIDs dbo.DTAPSPIDTableType
				INSERT INTO @DTAPSPIDs (DTAPSPID) 
				SELECT DTAPSPID FROM #PPSIDs

				EXEC [SP_DTA_Pricer_Calculate_CalculatedFieldsValues] @LUTPTID, @DTAPSPIDs
			END

		COMMIT TRAN

		-- return     
		DECLARE @updatefacilityrestcount int,@updatenpirestcount int
		
		SELECT @updatefacilityrestcount= COUNT(*) FROM #PPSIDs WHERE npi_flag=0 AND HasRestrictions=1
		SELECT @updatenpirestcount= COUNT(*) FROM #PPSIDs WHERE npi_flag=1 AND HasRestrictions=1

		IF (@hasWeights = 1)
		BEGIN
		  IF (@LUTPTID IN (30, 34))
		  BEGIN
			IF (@retCount <> 0)
			BEGIN
			  SELECT
				@retCount + @linkedSharedCount AS [NONRESTRICTEDCOUNT],
				@updatefacilityrestcount + @updatenpirestcount AS [RESTRICTEDCOUNT]
			  FOR xml RAW ('RESULTS')
			END
			ELSE
			BEGIN
			  SELECT
				@sharedCount + @linkedSharedCount AS [NONRESTRICTEDCOUNT],
				CASE @SharedWeightDTAPSPIDForFacility
				  WHEN 0 THEN 0
				  ELSE @updatefacilityrestcount
				END + CASE @SharedWeightDTAPSPIDForNPI
				  WHEN 0 THEN 0
				  ELSE @updatenpirestcount
				END AS [RESTRICTEDCOUNT]
			  FOR xml RAW ('RESULTS')
			END
		  END
		  ELSE
		  BEGIN
			SELECT
			  CASE @retCount
				WHEN 0 THEN @sharedCount + @linkedSharedCount
				ELSE @retCount + @linkedSharedCount
			  END AS [COUNT]
			FOR xml RAW ('RESULTS')
		  END
		END
		ELSE
		BEGIN
		  SELECT
			@retCount AS [COUNT]
		  FOR xml RAW ('RESULTS')
		END


		IF OBJECT_ID('tempdb..#PPSIDs') IS NOT NULL
		BEGIN
			DROP TABLE #PPSIDs
		END 
		
		IF OBJECT_ID('tempdb..#tmpConfiguration') IS NOT NULL
		BEGIN
			DROP TABLE #tmpConfiguration
		END 

	END TRY
	BEGIN CATCH
		ROLLBACK
		SELECT
			@errSeverity = ERROR_SEVERITY(),
			@errMsg = ERROR_MESSAGE()
		EXEC dbo.[SP_DTA_EventLog_Insert_SP]	@LoginSessionGUID,
												'[SP_EditAll_Save]',
												@@ERROR,
												@errSeverity,
												@errMsg,
												@@TRANCOUNT,
												@currentStep
	END CATCH
END

GO

PRINT N'Altering Procedure [dbo].[sp_DTA_PaySourcePricer_Copy]...';
GO
-- ============================================================================    
-- Author:  Nagaraju Chatragudi    
-- Create date: 09/09/2020    
-- Description:     
-- This stored procedure is used in SP_DTA_PaySourcePricer_SaveAs, which will create a new Paysource pricer, Weights and Pricing information  
-- Modified By: Vadim on 9/22/2020: US691044: Copy old fields values to new across given eff date
-- 20230510.US1049340.Mani	Updated field values with default value if pricer effective date is not with in range of display start and end date
-- Modified: 12/07/2023
-- US1127486: V2312.00 - Add new Pro pricer: Medicaid MS-DRG Pro - Rate and Metadata
-- Added condition for Pro Pricer
-- ============================================================================    
ALTER PROCEDURE [dbo].[sp_DTA_PaySourcePricer_Copy] @LoginSessionGUID uniqueidentifier, @DTAPSPID bigint, @share bit,
@TargetDTAPSID bigint,
@TargetEffdate datetime,
@LoginUser varchar(500),
@LUTWTID int,
@LUTPTID int,
@TargetDTAPSPID bigint OUT
AS
BEGIN

	-- variables for try-catch      
	DECLARE	@errSeverity AS int,
			@errMsg AS varchar(max),
			@currentStep varchar(500)

	DECLARE @locator_code_flag varchar(1)
	--DECLARE	




	-- APC New Layout change;
	DECLARE @dtaidsToBeMove dbo.DTAPSPIDTableType
	-- variables for dynamic sql
	DECLARE	@queryString nvarchar(max),
			@ppsTable Nvarchar(30),
			@weightTable Nvarchar(30)

	DECLARE @new_locator_code varchar(2) = NULL

	BEGIN TRY
		-- get location code flag


		-- insert DTA_PaySourcePricer data into a tmp table
		SELECT
			* INTO #psptmp
		FROM DTA_PaySourcePricer psp WITH (NOLOCK)
		WHERE psp.DTAPSPID = @DTAPSPID

		-- remove IDENTITY column
		ALTER TABLE #psptmp DROP COLUMN DTAPSPID

		-- update the data from passed xml

		IF @share = 0
		BEGIN
			UPDATE #psptmp
			SET	InsertedTS = GETDATE(),
				ModifiedTS = NULL,
				LoginSessionGUID = @LoginSessionGUID,
				LoginUser = @LoginUser,
				DTAPSID = @TargetDTAPSID,
				effdate = @TargetEffdate,
				CopiedFromDTAPSPID = @DTAPSPID,
				havewt =
						CASE havewt
							WHEN 'L' THEN 'N'
							ELSE havewt
						END,
				SharedWeightDTAPSPID = NULL
		END
		ELSE
		BEGIN
			UPDATE #psptmp
			SET	InsertedTS = GETDATE(),
				ModifiedTS = NULL,
				LoginSessionGUID = @LoginSessionGUID,
				LoginUser = @LoginUser,
				DTAPSID = @TargetDTAPSID,
				effdate = @TargetEffdate,
				CopiedFromDTAPSPID = @DTAPSPID
		END

		SET @currentStep = 'Inserting a new DTA_PaySourcePricer.'
		INSERT INTO DTA_PaySourcePricer
			SELECT
				*
			FROM #psptmp

		SET @TargetDTAPSPID = @@IDENTITY
		DROP TABLE #psptmp

		INSERT INTO @dtaidsToBeMove (DTAPSPID) VALUES(@TargetDTAPSPID)

		SELECT
				@ppsTable = pt.PricerTableName
			FROM LUT_PricerType pt WITH (NOLOCK)
			WHERE LUTPTID = @LUTPTID

		--PRINT @TargetDTAPSPID
		--Check if paysource pricer is using New Layout
		IF @LUTWTID IS NOT NULL
			AND @LUTWTID > 0
		BEGIN
			-- get the pricer table name
			-- Get the new layout table name
			SELECT
				@weightTable = wt.WeightTableName
			FROM LUT_WeightType wt WITH (NOLOCK)
			WHERE LUTWTID = @LUTWTID
		END
		ELSE
		BEGIN
			-- get the pps table and weight table name
			SELECT
				@weightTable = wt.WeightTableName
			FROM LUT_PricerType pt WITH (NOLOCK)
			INNER JOIN LUT_WeightType wt WITH (NOLOCK)
				ON pt.LUTWTID = wt.LUTWTID
			WHERE LUTPTID = @LUTPTID
		END
		--PRINT @weightTable
		--PRINT @ppsTable
		--PRINT @LUTWTID
		-- copy into PPS table

		DECLARE @Columns NVARCHAR(MAX) = ''
		DECLARE @ParameterList NVARCHAR(50) = N'  @EffDate DATE ' 

		--Get columns with default value or user entered value based on Effective Date lies between DisplayStartDate and DisplayEndDate
		IF @LUTPTID = 84 OR @LUTPTID = 86 OR @LUTPTID = 96 OR @LUTPTID = 98 -- We should exclude columns logic for Medicaid APR-DRG and Pro and DRG Pro
			SET @Columns = ', pps.* '
		ELSE 
		BEGIN
			SELECT @Columns = COALESCE(@Columns + ' , '+ REPLACE(ColumnQuery, '##ColumnName##','pps.' + ColumnName), ColumnQuery) FROM udf_GetPpsTableColumns(@LUTPTID, @TargetEffdate) ORDER BY ColumnOrder
		END

		SET @queryString = ''
		SET @QueryString = @QueryString + N'SELECT ' + CAST(@TargetDTAPSPID AS varchar(50)) + ' as NewDTAPSPID ' + @Columns + ' INTO #PPS FROM ' + @ppsTable + ' pps WITH (NOLOCK) WHERE pps.DTAPSPID = ' + CAST(@DTAPSPID AS varchar(50)) + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'ALTER TABLE #PPS DROP COLUMN PPSID, DTAPSPID' + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'INSERT INTO ' + @ppsTable + ' SELECT * FROM #PPS' + CHAR(13) + CHAR(10)
		
		EXEC SP_EXECUTESQL	@QueryString, @ParameterList, @EffDate = @TargetEffdate

		-- This block will recalculate the calculated field values
		IF @LUTPTID = 36 OR @LUTPTID = 41 -- Medicare DRG and Tricare/Champus
		BEGIN
			EXEC [SP_DTA_Pricer_Calculate_CalculatedFieldsValues] @LUTPTID, @dtaidsToBeMove
		END

		-- US691044: Copy old fields values to new across given eff date
		IF OBJECT_ID('tempdb..#copyfrom') IS NOT NULL
		BEGIN
			DROP TABLE #copyfrom
		END

		CREATE TABLE #copyfrom (CopiedFromDTAPSPID bigint, DTAPSPID bigint)
		INSERT INTO #copyfrom VALUES (@DTAPSPID, @TargetDTAPSPID)
		EXEC [dbo].[sp_DTA_CopyPPSFieldsFromOldToNew]

		IF OBJECT_ID('tempdb..#copyfrom') IS NOT NULL
		BEGIN
			DROP TABLE #copyfrom
		END

		-- copy into weight table
		SET @queryString = ''
		SET @QueryString = @QueryString + N'SELECT ' + CAST(@TargetDTAPSPID AS varchar(50)) + ' as NewDTAPSPID, weight.* INTO #Weight FROM ' + @weightTable + ' weight WITH (NOLOCK) WHERE weight.DTAPSPID = ' + CAST(@DTAPSPID AS varchar(50)) + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'ALTER TABLE #Weight DROP COLUMN DTAWDID, DTAPSPID' + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'INSERT INTO ' + @weightTable + ' SELECT * FROM #Weight' + CHAR(13) + CHAR(10)
		--PRINT @QueryString
		EXECUTE (@QueryString)

		IF @LUTWTID IS NULL
			OR @LUTWTID = 0
		BEGIN
			--PRINT @LUTWTID
			-- audit trail the DTA_PaySourcePricer
			EXEC [sp_DTA_WeightData_MoveToNew]	@LoginSessionGUID,
												@dtaidsToBeMove

		END
		SET @currentStep = 'Insert into  DTA_AuditTrail.'
		SELECT
			@TargetDTAPSPID AS DTAPSPID,
			'User Copied' AS field_name,
			'Copied' AS new_value INTO #DTA_PaySourcePricer
		EXEC sp_DTA_AuditTrail_Insert	@LoginSessionGuid,
										'UI'
	END TRY
	BEGIN CATCH
		SELECT
			@errSeverity = ERROR_SEVERITY(),
			@errMsg = ERROR_MESSAGE()
		EXEC dbo.[SP_DTA_EventLog_Insert_SP]	@LoginSessionGUID,
												'[SP_DTA_PaySourcePricer_Copy]',
												@@ERROR,
												@errSeverity,
												@errMsg,
												@@TRANCOUNT,
												@currentStep
	END CATCH
END
GO

PRINT N'Altering Procedure [dbo].[SP_LUT_PricerTypeAPRPro_Procedure_GetXml]...';
GO
-- =================================================================================  
-- Author:  Amy Zhao
-- Create date: 2/27/2015 
-- Description: This SP is to get the xml of all the procedure and associtaed pricing 
-- variables from tables LUT_PricerTypeAPRPro_Procedure, 
--						 LUT_PricerTypeAPRPro_ProcedureVariable
-- =================================================================================   
/***********************************************************************************  
EXEC [SP_LUT_PricerTypeAPRPro_Procedure_GetXml] 84
***********************************************************************************/  
ALTER PROCEDURE [dbo].[SP_LUT_PricerTypeAPRPro_Procedure_GetXml] 
@LUTPTID int
AS  
BEGIN  
 
	SET NOCOUNT ON;  

	SELECT   
		[Procedure].LUTPID
		, RTRIM([Procedure].PCode) AS PCode
		, [Procedure].PDescription
		, (SELECT 
				Variable.LUTPTVID, Variable.VariableName, Replace(Variable.LabelOnUI,':','') as VariableDescr 
		   FROM
				LUT_PricerTypeAPRPro_ProcedureVariable ProcedureVariable 
				INNER JOIN LUT_PricerTypeVariable Variable ON ProcedureVariable.LUTPTVID = Variable.LUTPTVID
				INNER JOIN (select *, row_number() over (partition by LUTPTVID order by LUTPTVID) as seqnum from TML_PricerPageTLMap) PricerMap 
				ON ProcedureVariable.LUTPTVID = PricerMap.LUTPTVID  and seqnum = 1
				INNER JOIN TML_PricerPageTL PricerTL ON PricerMap.TMLPPTID = PricerTL.TMLPPTID 
		   WHERE 
				ProcedureVariable.LUTPID = [Procedure].LUTPID ORDER BY PricerTL.DisplayOrder
		   FOR XML AUTO, TYPE)
	FROM   
		LUT_PricerTypeAPRPro_Procedure  [Procedure] 
	WHERE 
		[Enabled] = 1 
		AND LUTPTID=@LUTPTID
	ORDER BY  
		[Procedure].PCode
	FOR XML AUTO, ROOT('Procedures') 	 
END

GO

PRINT N'Altering Procedure [dbo].[SP_PPS_tables_Save]...';
GO
-- ==================================================================================
-- Author:		Amy Zhao
-- Create date: 1/3/2012
-- Description:	This sp is to dynamically save PPS data into corresponding PPS tables
-- 2020-06-18.US659335.Vadim	Set medext_sw flag based on saved data.
-- 2022-04-12.DE230399.Mani Add condition to check pricing fileds exist or not
-- 20230510.US1052320.Mani	Updated field values with default value if pricer effective date is not with in range of display start and end date
-- Modified: 12/07/2023
-- US1127486: V2312.00 - Add new Pro pricer: Medicaid MS-DRG Pro - Rate and Metadata
-- Added condition for Pro Pricer
-- Modified: 04/07/2026  
-- US1566826: V2604.00 - Add a New Physician Pro Payment System
-- Added condition for Pro Pricer
-- ===================================================================================
/*************************************************************************************

Declare @variableNames varchar(max), @variableValues varchar(max), @variableNameValue varchar(max)
--set @variableNames='rl, rnl, nl, nnl, rp, bmcfl, bmcfc, mcfl, mcfcl, cot, cof, fp, dshreduc, flp, techopfac, techcostfac, risk, fwa, sch_addon, sch_addon_new, sch_cost_disc, wi, iea, dshare, cola, rcc, markup, passthru, dmepassthru, prwi, prlp, lowvoladj, lowvoladj_new, waiver, waiver_factor, swingperdiem, ptype, baser, tcapaddon, totbase, capstfrate, capgeofac, caplgurbfac, capdshare, capimea, caprcc, capbyrcost, captradjdis, captradjcmi, capuf, capexcredfac, capbnfac, capcyrdis, capoldcosts, capoldper, capxcptn, cappattot, prcapstfrate, prgaf, prcapportion, capadjfrate, capfedportion, caphrate, caphblend'
set @variableNames='rl, rnl, nl, nnl, rp, bmcfl, bmcfc, mcfl, mcfcl, cot, cof, fp, dshreduc, flp, techopfac, techcostfac, risk, fwa, sch_addon, sch_addon_new, sch_cost_disc, wi, iea, dshare, cola, rcc, markup, passthru, dmepassthru, prwi, prlp, lowvoladj, lowvoladj_new, waiver, waiver_factor, swingperdiem, ptype, baser, tcapaddon, totbase, capstfrate, capgeofac, caplgurbfac, capdshare, capimea, caprcc, capbyrcost, captradjdis, captradjcmi, capuf, capexcredfac, capbnfac, capcyrdis, capoldcosts, capoldper, capxcptn, cappattot, prcapstfrate, prgaf, prcapportion, capadjfrate, capfedportion, caphrate, caphblend'

--Set @VariableValues = '''111111'', ''222222'', ''333333'', ''444444'', ''111'', ''666'', ''777'', ''022'', ''033'', ''8888888'', ''999'', ''110'', ''33333'', ''88000'', ''666'', ''777'', ''True'', ''600060'', ''4444444'', ''1234567812345'', ''8765432154321'', ''44000'', ''8888888888'', ''44444'', ''22222'', ''55556'', ''111111'', ''2222222'', ''555555'', ''99999'', ''44444'', ''99999'', ''1123456'', ''Y'', ''88888'', ''1234567811'', ''02'', ''2222222'', ''5555555'', ''011'', ''555555'', ''66666'', ''77777'', ''88888'', ''9999999999'', ''11111'', ''222222'', ''33333'', ''44444'', ''666666'', ''77777'', ''88888'', ''999999'', ''111111111'', ''222'', ''666666'', ''777777'', ''333333'', ''99999'', ''333'', ''8888888'', ''66666'', ''4444444'', ''777'''
Set @VariableValues = '''1'', ''2'', ''000'', ''000'', ''000'', ''000'', ''000'', ''000'', ''000'', ''000'', ''000'', ''000'', ''10000'', ''00000'', ''000'', ''000'', ''0'', '''', ''000'', ''000'', ''000'', ''00000'', ''0000000000'', ''00000'', ''00000'', ''00000'', ''00000'', ''000'', ''000'', ''00000'', ''00000'', ''00000'', ''0000000'', ''N'', ''00000'', ''000'', '''', ''000'', ''000'', ''000'', ''000'', ''00000'', ''10000'', ''00000'', ''0000000000'', ''00000'', ''000'', ''00000'', ''00000'', ''00000'', ''00000'', ''00000'', ''0'', ''000000000'', ''000'', ''000'', ''000'', ''000'', ''00000'', ''000'', ''000'', ''00000'', ''000'', ''000'''

set @variableNameValue = 'rl=''1111'',rnl=''2222'' '
EXEC dbo.SP_PPS_tables_Save '283C31AE-5417-42B7-9D5D-B33C10078519', 63, 36,  @variableNames, @variableValues

EXEC [dbo].[SP_PPS_tables_Save] @LoginSessionGUID='FC29200E-3ADB-482E-A452-AC6AB06F7CA0',@DTAPSPID=377892,@LUTPTID=30,@VariableNames='wi, labor, aids_factor, rural, markup, markupB, rcc, rcc_copay, vrcf, fsind, fstable, fsexttable, ambcarrier, ambcov, ambcoins, dmecarrier, dmecov, dmecoins, labcarrier, labcov, labcoins, mamcarrier, mamcov, mamcoins, rehcarrier, rehcov, rehcoins, othcarrier, othcov, othcoins, ambrural, ambnonrural',@VariableValues='''0897700'', ''0686930'', ''22800'', ''1'', ''10000'', ''10000'', ''10000'', ''00000'', ''10000'', ''1'', ''FSSNF12'', ''EXSNF12'', '''', ''08000'', ''02000'', ''WI'', ''08000'', ''02000'', ''0095100'', ''10000'', ''00000'', ''NATIONAL'', ''08000'', ''02000'', ''0095100'', ''08000'', ''02000'', '''', ''00000'', ''00000'', ''10098'', ''10000''',@VariableNameValues='wi=''0897700, '', labor=''0686930, '', aids_factor=''22800, '', rural=''1, '', markup=''10000, '', markupB=''10000, '', rcc=''10000, '', rcc_copay=''00000, '', vrcf=''10000, '', fsind=''1, '', fstable=''FSSNF12, '', fsexttable=''EXSNF12, '', ambcarrier='', '', ambcov=''08000, '', ambcoins=''02000, '', dmecarrier=''WI, '', dmecov=''08000, '', dmecoins=''02000, '', labcarrier=''0095100, '', labcov=''10000, '', labcoins=''00000, '', mamcarrier=''NATIONAL, '', mamcov=''08000, '', mamcoins=''02000, '', rehcarrier=''0095100, '', rehcov=''08000, '', rehcoins=''02000, '', othcarrier='', '', othcov=''00000, '', othcoins=''00000, '', ambrural=''10098, '', ambnonrural=''10000, '''
**************************************************************************************/
ALTER PROCEDURE [dbo].[SP_PPS_tables_Save] 
	@LoginSessionGUID uniqueidentifier, @DTAPSPID bigint, @LUTPTID int, @VariableNames nvarchar(max), @VariableValues nvarchar(max), @VariableNameValues nvarchar(max)
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- variables for try-catch  
	DECLARE @errSeverity int, @errMsg varchar(max), @currentStep varchar(50)
   
    -- variables for sp
	DECLARE @PricerTableName varchar(30), @QueryStr nvarchar(max), @PricerTypeDescr varchar(50)
	
	BEGIN TRY
	 
	SET @currentStep = 'Get PricerTableName from LUT_PricerType.'
	SELECT @PricerTableName = PricerTableName, @PricerTypeDescr = PricerTypeDescr FROM LUT_PricerType WHERE LUTPTID = @LUTPTID AND Enabled = 1
	
	--IF(@PricerTableName IS NULL or @PricerTableName = '')
	 -- raise error -- Invalid Pricer table name

	 Declare @count As int --Raise error if parent is deleted by another user
	 EXEC [dbo].[SP_IsRecordExists] 'dbo.DTA_PaySourcePricer','DTAPSPID',@DTAPSPID,@output = @count OUTPUT
	 IF( @count = 0)
	 BEGIN
		RAISERROR ('INGX:Your changes could not be saved. This item may have been modified or deleted by another user.', 16, 1)
	 END

	-- check exists
	DECLARE @existsCount int, @query nvarchar(1000), @QueryString nvarchar(max) 
	SET @query =  N'SELECT @existsCount = COUNT(1) FROM ' + @PricerTableName + ' WHERE DTAPSPID = @DTAPSPID'
	--PRINT @query
	EXEC sp_executesql @query, N'@PricerTableName varchar(30), @DTAPSPID bigint, @existsCount AS int output', @PricerTableName=@PricerTableName, @DTAPSPID=@DTAPSPID, @existsCount=@existsCount output

	-- handle pricer type xxxPRO to set medext_sw to 1 if the proc_array contains medex variables
	DECLARE @medext_sw varchar(1)
	IF (@LUTPTID = 84 OR @LUTPTID = 86 OR @LUTPTID = 96 OR @LUTPTID = 98) -- Amy: hardcode now until the pricer type Medicaid APG Pro implement medext_sw
	BEGIN
		DECLARE @filteredVariableNameValues varchar(max) = REPLACE(REPLACE(REPLACE(@VariableNameValues, '=', ''), ' ', ''), '''', '') -- remove all = ' and spaces
		DECLARE @proc_array_len int = CASE WHEN @LUTPTID = 98 THEN 390 ELSE 200 END
		DECLARE @proc_array varchar(390) = SUBSTRING(@filteredVariableNameValues, CHARINDEX('proc_array', @filteredVariableNameValues) + 10, @proc_array_len)

		SET @medext_sw = [dbo].[udf_IsProcArrContainsMedext](@proc_array, @LUTPTID)
		SELECT
			@VariableNames = @VariableNames + ', medext_sw',
			@VariableValues = @VariableValues + ',''' + @medext_sw + '''',
			@VariableNameValues = @VariableNameValues + ', medext_sw=''' + @medext_sw + ''''
	END	

	DECLARE @PpsColumnQuery TABLE(
		ColumnName NVARCHAR(128),
		ColumnQuery NVARCHAR(MAX)
	)
	DECLARE @ColumnNamesTbl TABLE(
		ID INT NOT NULL IDENTITY(1, 1),
		ColumnName VARCHAR(128)
	)

	DECLARE @ColumnValuesTbl TABLE(
		ID INT NOT NULL IDENTITY(1, 1),
		ColumnValue VARCHAR(MAX)
	)

	DECLARE @ColumnNameValuesTbl TABLE(
		ColumnName VARCHAR(128),
		ColumnValue VARCHAR(MAX)
	)

	DECLARE @EffDate DATE
	DECLARE @ParameterList NVARCHAR(50) = N'  @EffDate DATE ' 
	SELECT @EffDate = EffDate FROM DTA_PaySourcePricer WHERE DTAPSPID = @DTAPSPID

	INSERT INTO @ColumnNamesTbl
	SELECT RTRIM(LTRIM(splitdata)) FROM [dbo].[udf_SplitStringBySeperator](@VariableNames, ',')

	INSERT INTO @ColumnValuesTbl
	SELECT RTRIM(LTRIM(splitdata)) FROM [dbo].[udf_SplitStringBySeperator](@VariableValues, ',') 

	--Create table with column name & column values
	INSERT INTO @ColumnNameValuesTbl
	SELECT ColumnName, ColumnValue FROM @ColumnNamesTbl n INNER JOIN @ColumnValuesTbl v on n.ID = v.ID

	INSERT INTO @PpsColumnQuery
	SELECT 
			ColumnName,
			ColumnQuery
	FROM udf_GetPpsTableColumns(@LUTPTID, @EffDate)
	WHERE ColumnName NOT IN ('PPSID', 'DTAPSPID', 'InsertedTS' )

	IF(@existsCount = 0) -- insert
	BEGIN
	
		SET @currentStep = 'Build query string for inserting PPS data.'
		SET @QueryString =''
		SET @QueryString = @QueryString + N'DECLARE @errMsg AS varchar(max), @errSeverity AS int, @currentStep varchar(50)' + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'BEGIN TRY' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'BEGIN TRAN' + CHAR(13)+ CHAR(10)
		--SET @QueryString = @QueryString + N'SET @currentStep = ''Store existing data.''' + CHAR(13)+ CHAR(10) 	  
		--SET @QueryString = @QueryString + N'SELECT * INTO #PPS_Table_Original FROM ' + @PricerTableName + ' WHERE DTAPSPID = ' + CAST(@DTAPSPID AS VARCHAR(10)) + '' + CHAR(13)+ CHAR(10) 
		--SET @QueryString = @QueryString + N'SET @currentStep = ''Delete existing data.''' + CHAR(13)+ CHAR(10) 	  
		--SET @QueryString = @QueryString + N'DELETE FROM ' + @PricerTableName + ' WHERE DTAPSPID = ' + CAST(@DTAPSPID AS VARCHAR(10)) + '' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'SET @currentStep = ''Insert new data.''' + CHAR(13)+ CHAR(10) 
		IF(LEN(@VariableNames) > 0 AND LEN(@VariableValues) > 0)
		BEGIN
			--Get columns with default value or user entered value based on Effective Date lies between DisplayStartDate and DisplayEndDate
			IF @LUTPTID <> 84 AND @LUTPTID <> 86 AND @LUTPTID <> 96 AND @LUTPTID <> 98 -- Not for Medicaid APR-DRG Pro and Medicaid APR-DRG and Medicaid MS-DRG PRO
			BEGIN
				SET @VariableNames = '';
				SET @VariableValues = '';

				SELECT @VariableNames = COALESCE(@VariableNames + ' , '+ cq.ColumnName, cq.ColumnName), 
					   @VariableValues = COALESCE(@VariableValues + ' , '+ REPLACE( REPLACE(ColumnQuery, '##ColumnName##', ISNULL(cv.ColumnValue, '''''') ),' AS ' + cq.ColumnName,''), ColumnQuery) 
				FROM @PpsColumnQuery cq LEFT OUTER JOIN @ColumnNameValuesTbl cv on cv.ColumnName = cq.ColumnName

				SET @VariableNames = STUFF(@VariableNames,1,2,'')
				SET @VariableValues = STUFF(@VariableValues,1,2,'')
			END

			SET @QueryString = @QueryString + N'INSERT INTO ' + @PricerTableName + ' (DTAPSPID, ' + @VariableNames + ') VALUES(' + CAST(@DTAPSPID AS VARCHAR(20)) + ', '+ @VariableValues +')'
		END
		ELSE
			SET @QueryString = @QueryString + N'INSERT INTO ' + @PricerTableName + ' (DTAPSPID) VALUES(' + CAST(@DTAPSPID AS VARCHAR(20)) +')'
		SET @QueryString = @QueryString + N'COMMIT TRAN' + CHAR(13)+ CHAR(10) 
		--SET @QueryString = @QueryString + N'EXEC sp_DTA_AuditTrail_Insert_PPS ''' + CAST(@LoginSessionGUID AS VARCHAR(36)) + ''', ''' + @PricerTableName + ''''+ CHAR(13)+ CHAR(10) 	
		--SET @QueryString = @QueryString + N'IF object_id(''tempdb..#PPS_Table_Original'') IS NOT NULL' + CHAR(13)+ CHAR(10)  
		--SET @QueryString = @QueryString + N'  BEGIN  ' + CHAR(13)+ CHAR(10) 
		--SET @QueryString = @QueryString + N'     DROP TABLE #PPS_Table_Original ' + CHAR(13)+ CHAR(10) 
		--SET @QueryString = @QueryString + N'  END ' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'END TRY' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'BEGIN CATCH ' + CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'   SELECT @errSeverity = ERROR_SEVERITY(), @errMsg = ERROR_MESSAGE()' + CHAR(13)+ CHAR(10) 	
		--SET @QueryString = @QueryString + N'   EXEC SP_DTA_EventLog_Insert_SP ''[SP_PPS_' + @PricerTableName + '_Save]'', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, '''+ CAST(@LoginSessionGUID as varchar(50)) + ''', '+ CAST(@ADMUID as varchar(10)) +', @currentStep' + CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'   EXEC SP_DTA_EventLog_Insert_SP '''+ CAST(@LoginSessionGUID as varchar(36)) + ''', ''[SP_PPS_' + @PricerTableName + '_Save]'', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, @currentStep' + CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'END CATCH  ' + CHAR(13)+ CHAR(10) 
	END
	ELSE -- update
	BEGIN

		SET @currentStep = 'Build query string for updating PPS data.'
		SET @QueryString =''
		SET @QueryString = @QueryString + N'DECLARE @errMsg AS varchar(max), @errSeverity AS int, @currentStep varchar(50)' + CHAR(13) + CHAR(10)
		SET @QueryString = @QueryString + N'BEGIN TRY' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'BEGIN TRAN' + CHAR(13)+ CHAR(10)
		SET @QueryString = @QueryString + N'SET @currentStep = ''Store existing data.''' + CHAR(13)+ CHAR(10) 	  
		SET @QueryString = @QueryString + N'SELECT * INTO #PPS_Table_Original FROM ' + @PricerTableName + ' WHERE DTAPSPID = ' + CAST(@DTAPSPID AS VARCHAR(10)) + '' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'SET @currentStep = ''Update existing data.''' + CHAR(13)+ CHAR(10) 
		IF(LEN(@VariableNameValues) > 0)
		BEGIN
			--Get columns with default value or user entered value based on Effective Date lies between DisplayStartDate and DisplayEndDate
			IF @LUTPTID <> 84 AND @LUTPTID <> 86 AND @LUTPTID <> 96 AND @LUTPTID <> 98 -- Not for Medicaid APR-DRG Pro and Medicaid APR-DRG and Medicaid MS-DRG PRO
			BEGIN
				SET @VariableNameValues = '';
				SELECT @VariableNameValues = COALESCE(@VariableNameValues + ' , '+ cq.ColumnName + ' = ' + REPLACE(REPLACE(ColumnQuery, '##ColumnName##', ISNULL(cv.ColumnValue, cq.ColumnName)),' AS ' + cq.ColumnName,''), ColumnQuery)
				FROM @PpsColumnQuery cq LEFT OUTER JOIN @ColumnNameValuesTbl cv on cv.ColumnName = cq.ColumnName
				SET @VariableNameValues = STUFF(@VariableNameValues,1,2,'')
			END
			SET @QueryString = @QueryString + N'UPDATE ' + @PricerTableName + ' SET ' + @VariableNameValues + ' WHERE DTAPSPID = ' + CAST(@DTAPSPID AS VARCHAR(20))+  CHAR(13)+ CHAR(10) 
		END
		SET @QueryString = @QueryString + N'COMMIT TRAN' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'EXEC sp_DTA_AuditTrail_Insert_PPS ''' + CAST(@LoginSessionGUID AS VARCHAR(36)) + ''', ''' + @PricerTableName + ''''+ CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'IF object_id(''tempdb..#PPS_Table_Original'') IS NOT NULL' + CHAR(13)+ CHAR(10)  
		SET @QueryString = @QueryString + N'  BEGIN  ' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'     DROP TABLE #PPS_Table_Original ' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'  END ' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'END TRY' + CHAR(13)+ CHAR(10) 
		SET @QueryString = @QueryString + N'BEGIN CATCH ' + CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'   SELECT @errSeverity = ERROR_SEVERITY(), @errMsg = ERROR_MESSAGE()' + CHAR(13)+ CHAR(10) 	
		--SET @QueryString = @QueryString + N'   EXEC SP_DTA_EventLog_Insert_SP ''[SP_PPS_' + @PricerTableName + '_Save]'', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, '''+ CAST(@LoginSessionGUID as varchar(50)) + ''', '+ CAST(@ADMUID as varchar(10)) +', @currentStep' + CHAR(13)+ CHAR(10) 	
		SET @QueryString = @QueryString + N'   EXEC SP_DTA_EventLog_Insert_SP '''+ CAST(@LoginSessionGUID as varchar(36)) + ''', ''[SP_PPS_' + @PricerTableName + '_Save]'', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, @currentStep' + CHAR(13)+ CHAR(10) 	

		SET @QueryString = @QueryString + N'END CATCH  ' + CHAR(13)+ CHAR(10) 

	END
	
	
	-- exec the dynamic sql
	SET @currentStep = 'Execute the querystring to insert into PPS data.'
	EXEC SP_EXECUTESQL	@QueryString, @ParameterList, @EffDate = @EffDate
	
	-- update the ace_override_id in PPS table from DTA_PaySourcePricer (only for pricer type 'h' and 'i', also the effdate must be prior 10/1/2008)
	IF(EXISTS(SELECT LUTPTID FROM LUT_PricerType pt WITH (NOLOCK) WHERE LUTPTID = @LUTPTID AND RTRIM(PricerTypeName) IN ('h','i')))
	BEGIN
		DECLARE @ace_override_id varchar(20)
		SELECT @ace_override_id = ace_override_id FROM DTA_PaySourcePricer WHERE DTAPSPID = @DTAPSPID AND effdate < '2008-10-01'
		IF(@ace_override_id IS NOT NULL)
		BEGIN
			SET @QueryString = N'UPDATE ' + @PricerTableName + ' SET override_id = ''' + @ace_override_id + ''' WHERE DTAPSPID= ' + CAST(@DTAPSPID AS VARCHAR(10)) +  CHAR(13)+ CHAR(10) 
			EXECUTE (@QueryString)
		END
	END
	
	-- this block will update medext_sw flag in PPS table only for saved records which have data with medext flag = 1 in LUT table
	IF @LUTPTID = 53 -- Multipricer and Medicaid APG Pro only for now
	BEGIN
		IF OBJECT_ID('tempdb..#PPSIDs') IS NOT NULL	-- this temp table needs to be set prior to calling this SP
		BEGIN
			DROP TABLE #PPSIDs
		END
		CREATE TABLE #PPSIDs (PPSID bigint)
		SET @QueryString = N'INSERT INTO #PPSIDs SELECT TOP 1 PPSID FROM ' + @PricerTableName + ' WHERE DTAPSPID=' + CAST(@DTAPSPID AS VARCHAR(10))
		EXECUTE (@QueryString)
	 
		EXEC [dbo].[SP_PPS_UpdateMedextFlag] @LoginSessionGUID, @LUTPTID

		IF OBJECT_ID('tempdb..#PPSIDs') IS NOT NULL	
		BEGIN
			DROP TABLE #PPSIDs
		END
	END

	-- This block will recalculate the calculated field values
	IF @LUTPTID = 36 OR @LUTPTID = 41 -- Medicare DRG and Tricare/Champus
	BEGIN
        DECLARE @DTAPSPIDs dbo.DTAPSPIDTableType
        INSERT INTO @DTAPSPIDs (DTAPSPID) VALUES (@DTAPSPID)

		EXEC [SP_DTA_Pricer_Calculate_CalculatedFieldsValues] @LUTPTID, @DTAPSPIDs
	END

    END TRY  
    BEGIN CATCH  
    SELECT @errSeverity = ERROR_SEVERITY(), @errMsg = ERROR_MESSAGE()
	EXEC dbo.[SP_DTA_EventLog_Insert_SP] @LoginSessionGUID, '[SP_PPS_tables_Save]', @@ERROR, @errSeverity, @errMsg, @@TRANCOUNT, @currentStep

    END CATCH  
END

GO

PRINT N'Altering Function [dbo].[udf_LUT_PricerTypeAPRPro_StateProcedure_Get]...';
GO

-- ================================================================================
-- Author:		Amy Zhao
-- Create date: 5/13/2015
-- This function is to get all the procedures in the table LUT_PricerTypeAPRPro_StateProcedure
-- in string format for @state_id  and @effdate.    
-- ================================================================================
/**********************************************************************************  
SELECT * FROM [dbo].[udf_LUT_PricerTypeAPRPro_StateProcedure_Get]('MA','10/1/2014') pps 
***********************************************************************************/  
ALTER FUNCTION [dbo].[udf_LUT_PricerTypeAPRPro_StateProcedure_Get]
(	
@state_id char(2), @effdate datetime, @LUTPTID int
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT (
		SELECT 
			COALESCE(RTRIM(p.PCode), '')
		FROM
			LUT_PricerTypeAPRPro_StateProcedure sp 
			INNER JOIN LUT_PricerTypeAPRPro_State s ON sp.LUTSID=s.LUTSID
			INNER JOIN LUT_PricerTypeAPRPro_Procedure p on sp.LUTPID = p.LUTPID
		WHERE
			s.LUTSID=(SELECT TOP 1 LUTSID FROM LUT_PricerTypeAPRPro_State WHERE state_id=@state_id AND effdate<=@effdate AND LUTPTID=@LUTPTID ORDER BY effdate DESC)			
		ORDER BY
			sp.DisplayOrder
		FOR XML Path('')
	)as procs
)

GO

PRINT N'Altering Function [dbo].[udf_IsProcArrContainsMedext]...';
GO

-- ================================================================================
-- Author:		Amy Zhao
-- Create date: 2011/12/20
-- Description:	This sp is to compare two values are different
-- ================================================================================
/**********************************************************************************
DECLARE @proc_array varchar(max)
SET @proc_array=
--'00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
'05020501050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
SELECT [dbo].[udf_IsProcArrContainsMedext](@proc_array,84)

SELECT [dbo].[udf_IsProcArrContainsMedext](proc_array,84) from PPS_medaprprc_42
**********************************************************************************/
ALTER FUNCTION [dbo].[udf_IsProcArrContainsMedext] (@proc_array varchar(390), @LUTPTID int)
RETURNS varchar(1)
AS
BEGIN

	DECLARE @retVal varchar = '0'

	-- check if proc_array contains the medex variables
	IF (EXISTS (SELECT
			*
		FROM dbo.[udf_SplitStringByLength](@proc_array, CASE WHEN @LUTPTID = 98 THEN 3 ELSE 4 END) AS procs
		INNER JOIN dbo.LUT_PricerTypeAPRPro_Procedure lutp
			ON procs.Strings = lutp.PCode
		INNER JOIN dbo.LUT_PricerTypeAPRPro_ProcedureVariable lutpv
			ON lutp.LUTPID = lutpv.LUTPID
		INNER JOIN LUT_PricerTypeVariable lutptv
			ON lutpv.LUTPTVID = lutptv.LUTPTVID
		WHERE lutp.LUTPTID = @LUTPTID
		AND ISNULL(IsMedext, 0) = 1)
		)
	BEGIN
		SET @retVal = '1'
	END
	RETURN @retVal
END

GO
PRINT N'Altering Table [dbo].[LUT_PricerTypeVariable]...';
GO
IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[LUT_PricerTypeVariable]')
          AND name = 'LabelOnUI'
)
BEGIN
    ALTER TABLE [dbo].[LUT_PricerTypeVariable]
    ALTER COLUMN [LabelOnUI] VARCHAR(200) NULL;    
END
GO

PRINT N'Creating Table [dbo].[TMP_IM_medext_75]...';
GO
CREATE TABLE [dbo].[TMP_IM_medext_75] (
    [TMPIMID]          BIGINT           IDENTITY (1, 1) NOT NULL,
    [LoginSessionGUID] UNIQUEIDENTIFIER NOT NULL,
    [paysource]        VARCHAR (29)     NULL,
    [pattype]          VARCHAR (2)      NULL,
    [effdate]          DATETIME         NULL,
    [fstable]          VARCHAR (13)     NULL,
    [rcf]              VARCHAR (7)      NULL,
    [pcdisc1]          VARCHAR (5)      NULL,
    [pcdisc2]          VARCHAR (5)      NULL,
    [tcdisc1]          VARCHAR (5)      NULL,
    [tcdisc2]          VARCHAR (5)      NULL,
    [cvtcdisc1]        VARCHAR (5)      NULL,
    [cvtcdisc2]        VARCHAR (5)      NULL,
    [ophtcdisc1]       VARCHAR (5)      NULL,
    [ophtcdisc2]       VARCHAR (5)      NULL,
    [discount1]        VARCHAR (5)      NULL,
    [discount2]        VARCHAR (5)      NULL,
    [bilat1]           VARCHAR (5)      NULL,
    [bilat2]           VARCHAR (5)      NULL,
    [astsurg1]         VARCHAR (5)      NULL,
    [astsurg2]         VARCHAR (5)      NULL,
    [astsurg3]         VARCHAR (5)      NULL,
    [astsurg4]         VARCHAR (5)      NULL,
    [cosurg]           VARCHAR (5)      NULL,
    [ct_reduc]         VARCHAR (5)      NULL,
    [fy_reduc]         VARCHAR (5)      NULL,
    [fx_reduc]         VARCHAR (5)      NULL,
    [anest_reduc1]     VARCHAR (5)      NULL,
    [anest_reduc2]     VARCHAR (5)      NULL,
    [anest_reduc3]     VARCHAR (5)      NULL,
    [anest_base_units] VARCHAR (3)      NULL,
    [amb_reduc2]       VARCHAR (5)      NULL,
    [amb_reduc3]       VARCHAR (5)      NULL,
    [ambcov]           VARCHAR (5)      NULL,
    [ambcoins]         VARCHAR (5)      NULL,
    [dmecov]           VARCHAR (5)      NULL,
    [dmecoins]         VARCHAR (5)      NULL,
    [labcov]           VARCHAR (5)      NULL,
    [labcoins]         VARCHAR (5)      NULL,
    [natcov]           VARCHAR (5)      NULL,
    [natcoins]         VARCHAR (5)      NULL,
    [physcov]          VARCHAR (5)      NULL,
    [physcoins]        VARCHAR (5)      NULL,
    [othcov]           VARCHAR (5)      NULL,
    [othcoins]         VARCHAR (5)      NULL,
    [ambmarkup]        VARCHAR (5)      NULL,
    [dmemarkup]        VARCHAR (5)      NULL,
    [labmarkup]        VARCHAR (5)      NULL,
    [natmarkup]        VARCHAR (5)      NULL,
    [physmarkup]       VARCHAR (5)      NULL,
    [othmarkup]        VARCHAR (5)      NULL,
    [spec_code]        VARCHAR (2)      NULL,
    [InsertedTS]       DATETIME         CONSTRAINT [DF_TMP_IM_medext_75_InsertedTS] DEFAULT (getdate()) NULL
);
GO

CREATE NONCLUSTERED INDEX [IX_TMP_IM_medext_75_TMPIMID]
    ON [dbo].[TMP_IM_medext_75]([TMPIMID] ASC, [paysource] ASC, [pattype] ASC, [effdate] ASC);
GO


PRINT N'Creating Table [dbo].[PPS_physproprc_75]...';
GO
CREATE TABLE [dbo].[PPS_physproprc_75] (
    [PPSID]            BIGINT        IDENTITY (1, 1) NOT NULL,
    [DTAPSPID]         BIGINT        NOT NULL,
    [InsertedTS]       DATETIME      CONSTRAINT [DF_PPS_physproprc_75_InsertedTS] DEFAULT (getdate()) NULL,
    [DTAPDID]          INT           CONSTRAINT [DF_PPS_physproprc_75_DTAPDID] DEFAULT ((0)) NOT NULL,
    [proc_array]       VARCHAR (390) NULL,
    [state_id]         VARCHAR (2)   NULL,
    [use_scodes]       VARCHAR (1)   NULL,
    [fstable]          VARCHAR (13)  NULL,
    [anesthmin]        VARCHAR (4)   NULL,
    [medext_sw]        VARCHAR (1)   NULL,
    [rcf]              VARCHAR (7)   NULL,
    [pcdisc1]          VARCHAR (5)   NULL,
    [pcdisc2]          VARCHAR (5)   NULL,
    [tcdisc1]          VARCHAR (5)   NULL,
    [tcdisc2]          VARCHAR (5)   NULL,
    [cvtcdisc1]        VARCHAR (5)   NULL,
    [cvtcdisc2]        VARCHAR (5)   NULL,
    [ophtcdisc1]       VARCHAR (5)   NULL,
    [ophtcdisc2]       VARCHAR (5)   NULL,
    [discount1]        VARCHAR (5)   NULL,
    [discount2]        VARCHAR (5)   NULL,
    [bilat1]           VARCHAR (5)   NULL,
    [bilat2]           VARCHAR (5)   NULL,
    [astsurg1]         VARCHAR (5)   NULL,
    [astsurg2]         VARCHAR (5)   NULL,
    [astsurg3]         VARCHAR (5)   NULL,
    [astsurg4]         VARCHAR (5)   NULL,
    [cosurg]           VARCHAR (5)   NULL,
    [ct_reduc]         VARCHAR (5)   NULL,
    [fy_reduc]         VARCHAR (5)   NULL,
    [fx_reduc]         VARCHAR (5)   NULL,
    [anest_reduc1]     VARCHAR (5)   NULL,
    [anest_reduc2]     VARCHAR (5)   NULL,
    [anest_reduc3]     VARCHAR (5)   NULL,
    [anest_base_units] VARCHAR (3)   NULL,
    [ambcov]           VARCHAR (5)   NULL,
    [ambcoins]         VARCHAR (5)   NULL,
    [dmecov]           VARCHAR (5)   NULL,
    [dmecoins]         VARCHAR (5)   NULL,
    [labcov]           VARCHAR (5)   NULL,
    [labcoins]         VARCHAR (5)   NULL,
    [natcov]           VARCHAR (5)   NULL,
    [natcoins]         VARCHAR (5)   NULL,
    [physcov]          VARCHAR (5)   NULL,
    [physcoins]        VARCHAR (5)   NULL,
    [othcov]           VARCHAR (5)   NULL,
    [othcoins]         VARCHAR (5)   NULL,
    [ambmarkup]        VARCHAR (5)   NULL,
    [dmemarkup]        VARCHAR (5)   NULL,
    [labmarkup]        VARCHAR (5)   NULL,
    [natmarkup]        VARCHAR (5)   NULL,
    [physmarkup]       VARCHAR (5)   NULL,
    [othmarkup]        VARCHAR (5)   NULL,
    [amb_reduc2]       VARCHAR (5)   NULL,
    [amb_reduc3]       VARCHAR (5)   NULL,
    [spec_code]        VARCHAR (2)   NULL,
    CONSTRAINT [PK_PPS_physproprc_75] PRIMARY KEY CLUSTERED ([DTAPDID] ASC, [PPSID] ASC),
    CONSTRAINT [FK_PPS_physproprc_75_DTA_PaySourcePricer] FOREIGN KEY ([DTAPDID], [DTAPSPID]) REFERENCES [dbo].[DTA_PaySourcePricer] ([DTAPDID], [DTAPSPID])
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_PPS_physproprc_75_DTAPSPID]
    ON [dbo].[PPS_physproprc_75]([DTAPDID] ASC, [DTAPSPID] ASC);
GO

PRINT N'Altering Procedure [dbo].[SP_Export_GetRateFileNames]...';
GO
-- ============================================================================
-- Author:		Manikumar 
-- Create date: 06/21/2022
-- Description:	This sp to query rate file names based on export criteria
-- US909937: Export Queue Performance
-- =============================================================================

/*******************************************************************************
exec [SP_Export_GetRateFileNames] 'f','n','t','pId','pName',34,'1/1/2020','1/1/2022',0,0     
********************************************************************************/
ALTER PROCEDURE [dbo].[SP_Export_GetRateFileNames] 
@InExportQueue BIT, 
@DTAPDID INT = 0
AS
BEGIN
	DECLARE @InpatientFiles VARCHAR(250) = 'config.dat,medcalc.dat,payors.dat,rate.dat,medext.dat'
	DECLARE @OutpatientFiles VARCHAR(250) = 'cfgout.dat,medout.dat,payout.dat,rateout.dat,rateapc.dat,ratehha.dat,rateny2.dat,medext02.dat'
	DECLARE @IRFFiles VARCHAR(250) = 'cfgirf.dat,medirf.dat,payirf.dat,rateirf.dat'
	DECLARE @PhyFiles VARCHAR(250) = 'cfgphys.dat,medphys.dat,payphys.dat,medext04.dat'
	DECLARE @CAHFiles VARCHAR(250) = 'cfgcah.dat,medcah.dat,paycah.dat'
	DECLARE @SNFFiles VARCHAR(250) = 'cfgsnf.dat,medsnf.dat,paysnf.dat,ratesnf.dat,ratesnf2.dat'
	DECLARE @EditorFiles VARCHAR(MAX) = 'apcrule.dat,acerule.dat,ascrule.dat,maprule.dat,physoverride.dat,physrule.dat'

	IF @DTAPDID > 0
	BEGIN
		SELECT @OutpatientFiles = CASE 
			WHEN pd.DTAPDID > 0 THEN REPLACE(@OutpatientFiles, 'rateny2.dat', 'rateny.dat')
			ELSE @OutpatientFiles END 
		FROM DTA_ProductionDate pd
		INNER JOIN LUT_WeightTypeExt wt
		ON pd.DTAPDID = @DTAPDID AND wt.LUTWTID = 10
		AND pd.ProductionDate < wt.effdate
	END

	SELECT @EditorFiles = COALESCE(@EditorFiles + ',', '') + FileName FROM EDR_CodeTable WITH (NOLOCK) WHERE ProductionDateId = @DTAPDID
	DECLARE @AllFileName VARCHAR(MAX) = ''
	IF(@InExportQueue = 1)
	BEGIN
		SELECT DISTINCT pattype INTO #temPatTypes
		FROM DTA_PaySource PS WITH (NOLOCK)
		INNER JOIN DTA_PaySourcePricer PSP WITH (NOLOCK)
		ON PS.DTAPSID = PSP.DTAPSID
		WHERE InExportQueue = 1 AND DoNotExport = 0 AND PS.DTAPDID = @DTAPDID

		SELECT @AllFileName = COALESCE(@AllFileName + ',', '') + 
							  CASE pattype
							  WHEN '01' THEN @InpatientFiles
							  WHEN '02' THEN @OutpatientFiles
							  WHEN '03' THEN @IRFFiles
							  WHEN '04' THEN @PhyFiles
							  WHEN '05' THEN @CAHFiles
							  WHEN '06' THEN @SNFFiles
							  END
		FROM #temPatTypes

	END
	ELSE
	BEGIN
		SET @AllFileName = CONCAT(@InpatientFiles,',', @OutpatientFiles, ',', @IRFFiles, ',', @PhyFiles, ',', @CAHFiles, ',', @SNFFiles, ',', @EditorFiles)
	END

	SELECT splitdata
    FROM [dbo].[udf_SplitStringBySeperator](@AllFileName, ',')  
	WHERE LEN(ISNULL(splitdata, '')) > 0
	
END
GO

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
    UPDATE LUT_PricerTypeVariable SET [VariableLeftCount] = 306, VariableFormat = N'X(306)', VariableSizeInC = 306, StartPositionInC = 132, ModifiedTS='20260407 00:00:00.000' where LUTPTVID=4319
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

    -- US1578778: V2604.00 - Field Name Update for New York Medicaid APR-DRG
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [LabelOnUI]='Health and Hospitals Corporation Add-On', [ModifiedTS]='20260407 00:00:00.000' WHERE LUTPTVID=4437

    -- US1566826: V2604.00 - Add a New Physician Pro Payment System
    -- [LUT_PricerType]
    INSERT INTO [dbo].[LUT_PricerType] ([LUTPTID], [pattype], [PricerTypeName], [PricerTypeDescr], [PricerTableName], [VersionInCommon], [GrouperVersionDefaultType], [LUTPSCID], [LUTWTID], [Enabled], [InsertedTS], [HasWeight], [IsEditAll], [LUTEFSID], [reimbdate_dafault], [DataUsage], [default_grptype], [ShowAnalyzing], [TMP_PricerTableName], [MedExtExportOrder]) VALUES (98, N'04', '75', N'Physician Pro', N'PPS_physproprc_75', 1, 25, 2, NULL, 1, '20260407 00:00:00.000', 0, 1, NULL, N'A', NULL, N'65', 1, N'TMP_IM_medext_75', 9)
    -- [LUT_PricerTypeVariable]
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4519, 98, N'', N'proc_array', N'', N'TEXT', 390, 0, N'X(390)', NULL, N'Procedure Array:', N'0', NULL, 390, 41, 0, NULL, NULL, NULL, NULL, 390, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4520, 98, N'E.1', N'use_scodes', N'', N'DECIMAL', 1, 0, N'9(1)', NULL, N'Scode Flag:', N'1', NULL, 1, 435, 0, NULL, NULL, NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4521, 98, N'D.1', N'state_id', N'This field should be populated with the applicable two letter abbreviation for the desired pricing model', N'TEXT', 2, 0, N'X(2)', N'VariableEventHandler_MedicaidAPRPro_state', N'State:', N' ', NULL, 2, 39, 0, NULL, NULL, NULL, NULL, 2, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4522, 98, N'E.3', N'rcf', N'', N'DECIMAL', 1, 6, N'9(1)v9(6)', NULL, N'Reasonable Cost Factor:', N'0.000000', NULL, 7, 271, 1, NULL, NULL, 0, 9.999999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4523, 98, N'F.1', N'pcdisc1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Diag Img PC - Highest:', N'0.0000', NULL, 5, 40, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4524, 98, N'F.2', N'pcdisc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Diag Img PC - Not Highest:', N'0.0000', NULL, 5, 45, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4525, 98, N'F.3', N'tcdisc1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Diag Img TC - Highest:', N'0.0000', NULL, 5, 50, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4526, 98, N'F.4', N'tcdisc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Diag Img TC - Not Highest:', N'0.0000', NULL, 5, 55, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4527, 98, N'F.7', N'cvtcdisc1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'CV Diag Img TC - Highest:', N'0.0000', NULL, 5, 70, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4528, 98, N'F.8', N'cvtcdisc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'CV Diag Img TC - Not Highest:', N'0.0000', NULL, 5, 75, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4529, 98, N'F.9', N'ophtcdisc1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'OPH Diag Img TC - Highest:', N'0.0000', NULL, 5, 80, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4530, 98, N'F.10', N'ophtcdisc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'OPH Diag Img TC - Not Highest:', N'0.0000', NULL, 5, 85, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4531, 98, N'F.11', N'discount1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'MPPR - Highest Paid Service:', N'0.0000', NULL, 5, 90, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4532, 98, N'F.12', N'discount2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'MPPR - Not Highest Paid Service:', N'0.0000', NULL, 5, 95, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4533, 98, N'G.1', N'bilat1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Bilateral-Conditional:', N'0.0000', NULL, 5, 60, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4534, 98, N'G.2', N'bilat2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Bilateral-Independent:', N'0.0000', NULL, 5, 65, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4535, 98, N'H.1', N'astsurg1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Assistant at Surgery 1:', N'0.0000', NULL, 5, 110, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4536, 98, N'H.2', N'astsurg2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Assistant at Surgery 2:', N'0.0000', NULL, 5, 115, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4537, 98, N'H.3', N'astsurg3', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Assistant at Surgery 3:', N'0.0000', NULL, 5, 120, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4538, 98, N'H.4', N'astsurg4', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Assistant at Surgery 4:', N'0.0000', NULL, 5, 125, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4539, 98, N'H.5', N'cosurg', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Co-Surgery:', N'0.0000', NULL, 5, 130, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4540, 98, N'H.6', N'ct_reduc', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Computed Tomography (CT) Reduction Factor:', N'0.0000', NULL, 5, 253, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4541, 98, N'H.7', N'fy_reduc', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Computed Radiography Reduction Factor:', N'0.0000', NULL, 5, 258, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4542, 98, N'H.8', N'fx_reduc', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'X-Ray w/ Film Reduction Factor:', N'0.0000', NULL, 5, 263, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4543, 98, N'I.1', N'anest_reduc1', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Monitored Anesthesia Factor 1:', N'0.0000', NULL, 5, 208, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4544, 98, N'I.2', N'anest_reduc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Monitored Anesthesia Factor 2:', N'0.0000', NULL, 5, 213, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4545, 98, N'I.3', N'anest_reduc3', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Monitored Anesthesia Factor 3:', N'0.0000', NULL, 5, 218, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4546, 98, N'I.4', N'anest_base_units', N'', N'DECIMAL', 3, 0, N'9(3)', NULL, N'Anesthesia Base Units:', N'000', NULL, 3, 268, 1, NULL, NULL, 0, 999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4547, 98, N'I.5', N'anesthmin', N'', N'DECIMAL', 4, 0, N'9(4)', NULL, N'Minutes for Time Units Report:', N'0000', NULL, 4, 431, 0, NULL, NULL, 0, 9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4548, 98, N'J.1', N'fstable', N'The fee schedule table to be used for pricing.', N'TEXT', 13, 0, N'X(13)', NULL, N'Enter FS Name:', N'', NULL, 13, 195, 1, NULL, N'^(FS|FEE)[a-zA-Z0-9]*$|^| name must start with "FS" or "FEE". Special characters are not allowed.', NULL, NULL, 13, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4549, 98, N'K.1', N'ambcov', N'Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Ambulance - Payment Factor:', N'0.8000', NULL, 5, 145, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4550, 98, N'K.2', N'ambcoins', N'Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Ambulance - Co-payment Factor:', N'0.2000', NULL, 5, 150, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4551, 98, N'L.1', N'dmecov', N'Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'DMEPOS - Payment Factor:', N'0.8000', NULL, 5, 155, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4552, 98, N'L.2', N'dmecoins', N'Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'DMEPOS - Co-payment Factor:', N'0.2000', NULL, 5, 160, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4553, 98, N'M.1', N'labcov', N'Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Laboratory - Payment Factor:', N'1.0000', NULL, 5, 165, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4554, 98, N'M.2', N'labcoins', N'Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Laboratory - Co-payment Factor:', N'0.0000', NULL, 5, 170, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4555, 98, N'N.1', N'natcov', N'Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'National or Medicaid Rates - Payment Factor:', N'0.8000', NULL, 5, 135, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4556, 98, N'N.2', N'natcoins', N'Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'National or Medicaid Rates - Co-payment Factor:', N'0.2000', NULL, 5, 140, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4557, 98, N'O.1', N'physcov', N'Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Physician Fee - Payment Factor:', N'0.8000', NULL, 5, 175, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4558, 98, N'O.2', N'physcoins', N'Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Physician Fee - Co-payment Factor:', N'0.2000', NULL, 5, 180, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4559, 98, N'P.1', N'othcov', N'The Payment Factor used with customized fee schedule entries.
Set to 1.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'X - Other - Payment Factor:', N'0.0000', NULL, 5, 185, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4560, 98, N'P.2', N'othcoins', N'The Co-Payment Factor used with customized fee schedule entries.
Set to 0.0000 if co-payment is not desired.', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'X - Other - Co-payment Factor:', N'0.0000', NULL, 5, 190, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4561, 98, N'Q.1', N'amb_reduc2', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Ambulance Base Rate Reduction - Two Patients:', N'0.0000', NULL, 5, 100, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4562, 98, N'Q.2', N'amb_reduc3', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Ambulance Base Rate Reduction - Three or More Patients:', N'0.0000', NULL, 5, 105, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4563, 98, N'R.1', N'ambmarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Ambulance Markup Factor:', N'1.0000', NULL, 5, 223, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4564, 98, N'R.2', N'dmemarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'DME Markup Factor:', N'1.0000', NULL, 5, 228, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4565, 98, N'R.3', N'labmarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Lab Markup Factor:', N'1.0000', NULL, 5, 233, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4566, 98, N'R.4', N'natmarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'National/Medicaid Markup Factor:', N'1.0000', NULL, 5, 238, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4567, 98, N'R.5', N'physmarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Physician Markup Factor:', N'1.0000', NULL, 5, 243, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4568, 98, N'R.6', N'othmarkup', N'', N'DECIMAL', 1, 4, N'9(1)v9(4)', NULL, N'Other Markup Factor:', N'1.0000', NULL, 5, 248, 1, NULL, NULL, 0, 9.9999, NULL, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4569, 98, N'', N'filler1', N'', N'FILLER', 0, 0, N'', NULL, N'Filler:', N'', NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4570, 98, N'', N'filler2', N'', N'FILLER', 228, 0, N'X(228)', NULL, N'Filler:', N'', NULL, 228, 280, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4571, 98, N'', N'closed_fac_sw', N'', N'FILLER', 1, 0, N'9(1)', NULL, N'Closed Facility Flag:', N'', NULL, 1, 436, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4572, 98, N'', N'medext_sw', N'', N'TEXT', 1, 0, N'X(1)', NULL, N'Medext Switch:', N'1', NULL, 1, 437, 0, NULL, NULL, NULL, NULL, 1, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4573, 98, N'E.2', N'spec_code', N'', N'TEXT', 2, 0, N'X(2)', NULL, N'Specialty Code:', N'', NULL, 2, 278, 1, NULL, NULL, NULL, NULL, 2, 3, 1, '20260407 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4574, 98, NULL, N'seqnum', N'Sequence Number', N'TEXT', 1, 0, N'X(1)', NULL, NULL, N'', NULL, 1, 39, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL, CAST(N'0001-01-01' AS Date), CAST(N'9999-12-31' AS Date), NULL)

-- [TML_PricerPageTLMap]
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3937, 7060, 4519)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3938, 7061, 4519)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3939, 7062, 4521)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3940, 7063, 4521)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3941, 7064, 4521)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3942, 7067, 4522)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3943, 7068, 4522)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3944, 7081, 4523)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3945, 7082, 4523)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3946, 7098, 4524)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3947, 7099, 4524)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3948, 7100, 4525)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3949, 7101, 4525)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3950, 7083, 4526)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3951, 7084, 4526)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3952, 7102, 4527)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3953, 7103, 4527)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3954, 7069, 4528)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3955, 7070, 4528)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3956, 7072, 4529)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3957, 7073, 4529)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3958, 7104, 4530)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3959, 7105, 4530)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3960, 7085, 4520)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3961, 7086, 4520)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3965, 7090, 4531)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3966, 7091, 4531)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3967, 7106, 4532)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3968, 7107, 4532)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3969, 7075, 4533)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3970, 7076, 4533)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3971, 7077, 4534)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3972, 7078, 4534)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3973, 7092, 4539)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3974, 7093, 4539)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3975, 7079, 4535)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3976, 7080, 4535)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3977, 7094, 4540)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3978, 7095, 4540)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3979, 7096, 4541)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3980, 7097, 4541)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3981, 7110, 4536)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3982, 7111, 4536)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3983, 7112, 4537)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3984, 7113, 4537)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3985, 7114, 4538)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3986, 7115, 4538)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3987, 7116, 4542)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3988, 7117, 4542)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3989, 7118, 4543)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3990, 7119, 4543)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3991, 7120, 4544)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3992, 7121, 4544)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3993, 7122, 4545)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3994, 7123, 4545)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3995, 7124, 4546)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3996, 7125, 4546)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3997, 7126, 4547)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3998, 7127, 4547)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3999, 7129, 4548)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4000, 7130, 4548)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4001, 7132, 4561)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4002, 7133, 4561)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4003, 7134, 4562)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4004, 7135, 4562)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4005, 7137, 4563)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4006, 7138, 4563)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4007, 7139, 4564)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4008, 7140, 4564)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4009, 7141, 4565)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4010, 7142, 4565)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4011, 7143, 4566)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4012, 7144, 4566)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4013, 7145, 4567)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4014, 7146, 4567)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4015, 7147, 4568)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4016, 7148, 4568)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4017, 7150, 4549)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4018, 7150, 4551)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4019, 7150, 4553)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4020, 7150, 4555)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4021, 7150, 4557)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4022, 7150, 4559)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4023, 7151, 4550)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4024, 7151, 4552)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4025, 7151, 4554)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4026, 7151, 4556)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4027, 7151, 4558)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4028, 7151, 4560)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4029, 7152, 4549)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4030, 7152, 4550)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4031, 7153, 4549)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4032, 7154, 4550)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4033, 7155, 4551)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4034, 7155, 4552)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4035, 7156, 4551)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4036, 7157, 4552)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4037, 7158, 4553)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4038, 7158, 4554)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4039, 7159, 4553)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4040, 7160, 4554)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4041, 7161, 4555)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4042, 7161, 4556)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4043, 7162, 4555)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4044, 7163, 4556)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4045, 7164, 4557)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4046, 7164, 4558)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4047, 7165, 4557)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4048, 7166, 4558)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4049, 7167, 4559)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4050, 7167, 4560)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4051, 7168, 4559)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4052, 7169, 4560)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4053, 7170, 4573)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (4054, 7171, 4573)
    -- [LUT_RateVariable]
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10768, 98, N'A', N'analyzer_type', 1, N'Analyzer', N'The Analyzer to be used.', N'00', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10769, 98, N'A', N'analyzer_vers', 2, N'Version', NULL, N'01', N'DTA_PaySourcePricer', N'9(2)', 2, 0, N'INTEGER', 0, 1, 99, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10770, 98, N'A', N'start_lvl_option1', 3, N'Starting Visit Level Options 1', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10771, 98, N'A', N'start_lvl_option2', 4, N'Starting Visit Level Options 2', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10772, 98, N'A', N'start_lvl_option3', 5, N'Starting Visit Level Options 3', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10773, 98, N'A', N'start_lvl_option4', 6, N'Starting Visit Level Options 4', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10774, 98, N'A', N'start_lvl_option5', 7, N'Starting Visit Level Options 5', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10775, 98, N'A', N'lvl_change_option', 8, N'Visit Level Change Option', NULL, N'', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'DECIMAL', 0, 0, 9, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10776, 98, N'A', N'edc_action', 9, N'Action', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10777, 98, N'C', N'facility_id', 1, N'Facility', NULL, NULL, N'DTA_PaySource', N'X(16)', 16, 0, N'TEXT', 1, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 16, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10778, 98, N'C', N'npi', 2, N'NPI', NULL, NULL, N'DTA_PaySource', N'X(10)', 10, 0, N'TEXT', 1, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 10, 1, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10779, 98, N'C', N'taxonomy', 3, N'Taxonomy', NULL, NULL, N'DTA_PaySource', N'X(10)', 10, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 10, 1, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10780, 98, N'C', N'payer_id', 4, N'Payer ID', NULL, NULL, N'DTA_PaySource', N'X(13)', 13, 0, N'TEXT', 1, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 13, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10781, 98, N'C', N'paysource_name', 5, N'Name', NULL, NULL, N'DTA_PaySource', N'X(25)', 25, 0, N'TEXT', 0, NULL, NULL, NULL, 25, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10782, 98, N'C', N'abbrev_name', 6, N'State/Abbr', NULL, NULL, N'DTA_PaySource', N'X(5)', 5, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9'' ,/\\-_\\\\]*$|^| other special characters are not allowed.', 5, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10783, 98, N'C', N'effdate', 7, N'Effective', NULL, NULL, N'DTA_PaySourcePricer', N'9(8)', 8, 0, N'DATETIME', 1, NULL, NULL, NULL, 8, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10784, 98, N'C', N'pricer_type', 8, N'Pricer Type', NULL, NULL, N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10785, 98, N'C', N'LUTPSCID', 9, N'Class', NULL, N'1', N'DTA_PaySource', N'X(2)', 2, 0, N'TEXT', 1, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10786, 98, N'C', N'reimbdate', 10, N'Admit/Discharge Date', NULL, N'A', N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10787, 98, N'C', N'payer_id', 4, N'Payer ID', NULL, NULL, N'DTA_PaySource', N'X(9)', 9, 0, N'TEXT', 1, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 9, 1, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10788, 98, N'C', N'closed_fac_sw', 11, N'Closed Facility', NULL, N'0', N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10789, 98, N'C', N'npi_flag', 12, N'Key Type', NULL, NULL, N'DTA_PaySource', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10790, 98, N'E', N'PhysicianEdit_flag', 11, N'Physician Edits, Taxonomy Determines MUE Edits', N'Check this box to request that the Physician Editor perform the Correct Coding Initiative (CCI) edits, the Medically Unlikely Edits (MUEs), and other basic claims validation edits. When applying the MUEs, the Physician Editor will determine which set of edits (Durable Medical Equipment (DME) versus practitioner) to apply to a given claim line based on the billed taxonomy code. Any service billed with a designated DME supplier taxonomy code will be subject to the DME MUEs. All other services will be subject to the practitioner MUEs', N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10791, 98, N'E', N'PhysEdit_MaxDME', 12, N'Physician Edits with Max of MUE Values Applied', N'Check this box to request that the Physician Editor perform the Correct Coding Initiative (CCI) edits, the Medically Unlikely Edits (MUEs), and other basic claims validation edits. When applying the MUEs, the Physician Editor will determine which set of edits (DME versus practitioner) to apply to a given claim line using the following rules:', N'1', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 1, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10792, 98, N'G', N'grpr_type', 1, N'Grouper', N'No Grouper is needed to classify Physician claims at this time.', N'65', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 1, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10793, 98, N'G', N'grpr_vers', 2, N'Version', N'No Grouper is needed to classify Physician claims at this time.', NULL, N'DTA_PaySourcePricer', N'9(2)', 2, 0, N'TEXT', 0, 0, 99, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10794, 98, N'G', N'grpr_date', 3, N'Grouper Date Flag', N'This field is used to determine the Grouper Type/Grouper Version based on the From/Admission Date or the Thru/Discharge Date provided, instead of the Admit/Discharge Date (SEQ# A.11). The options in the drop-down are as follows: Blank = Not Applicable A = From or Admission Date D = Thru or Discharge Date', N'', N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10795, 98, N'G', N'icd9_map', 4, N'Mapping', N'Invokes diagnosis and procedure code mapping. This field is not applicable to the Medicare Physician Payment System. The options in the dropdown are as follows: No Mapping - Select if not applicable or you do not wish to use mapping. Standard - Select if you wish to use standard Medicare mapping rules. State-specific - Select if you wish to use ICD-9 state-specific mapping rules.', N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10796, 98, N'G', N'map_type', 5, N'Mapper Type', N'This field is not applicable to the Medicare Physician Payment System. This field only appears if Standard is selected in SEQ# D.4. You would check the box, if you wanted to use ICD-10 mapping rules.', N'00', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'00')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10797, 98, N'G', N'map_category', 6, N'Map Category', N'This field is not applicable to the Medicare Physician Payment System. This field indicates whether ICD-10 diagnosis and procedure code mapping should be used. This field only appears if Standard is selected in SEQ# D.4.', N'01', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, 1, 99, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10798, 98, N'G', N'map_override_id', 7, N'Map ID', N'This field is not applicable to the Medicare Physician Payment System. This field only appears if Standard is selected in SEQ# D.4', N'', N'DTA_PaySourcePricer', N'X(20)', 20, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 20, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10799, 98, NULL, N'eseq', NULL, N'Effective Date Sequence Code', NULL, NULL, NULL, N'9(4)', 4, 0, N'INTEGER', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10800, 98, NULL, N'filler', NULL, N'Filler for EffectiveStop Date (Future)', NULL, NULL, NULL, N'X(8)', 8, 0, N'TEXT', 0, NULL, NULL, NULL, 8, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'F', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10801, 98, NULL, N'pricer_type_rsvd', NULL, N'Payer Type Reserved', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10802, 98, NULL, N'grpr_type_rsvd', NULL, N'Grouper Type Reserved', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10803, 98, NULL, N'grpr_vers_rsvd', NULL, N'Grouper Version Reserved', NULL, NULL, NULL, N'9(3)', 3, 0, N'INTEGER', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10804, 98, NULL, N'edtr_type', NULL, N'Editor Type', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10805, 98, NULL, N'edtr_type_rsvd', NULL, N'Editor Type Reserved', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10806, 98, NULL, N'edtr_vers', NULL, N'Editor Version', NULL, NULL, NULL, N'9(2)', 2, 0, N'INTEGER', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10807, 98, NULL, N'edtr_rel', NULL, N'Editor Release', NULL, NULL, NULL, N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10808, 98, NULL, N'edtr_vers_rsvd', NULL, N'Editor Version Reserved', NULL, NULL, NULL, N'X(3)', 3, 0, N'TEXT', 0, NULL, NULL, NULL, 3, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10809, 98, NULL, N'rsvd_req3', NULL, N'Editor Requests Reserved 3', NULL, NULL, NULL, N'X(10)', 10, 0, N'TEXT', 0, NULL, NULL, NULL, 10, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10810, 98, NULL, N'rsvd_req4', NULL, N'Editor Requests Reserved 4', NULL, NULL, NULL, N'X(10)', 10, 0, N'TEXT', 0, NULL, NULL, NULL, 10, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10811, 98, NULL, N'grpr_option', NULL, N'Grouper Option', NULL, NULL, NULL, N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10812, 98, NULL, N'wgt_option', NULL, N'Weight Option', NULL, NULL, NULL, N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10813, 98, NULL, N'ace_flag', NULL, N'ACE Flag', NULL, NULL, NULL, N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10814, 98, NULL, N'dsc_flag', NULL, N'DSC Flag', NULL, NULL, NULL, N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10815, 98, NULL, N'flag_rsvd', NULL, N'Flag Reserved', NULL, NULL, NULL, N'9(8)', 8, 0, N'INTEGER', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10816, 98, NULL, N'sqr_flag', NULL, N'Sequester Flag', NULL, NULL, N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10817, 98, NULL, N'analyzer_type_rsvd', NULL, N'Analyzer Type Reserved', NULL, NULL, N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10818, 98, NULL, N'analyzer_vers_rsvd', NULL, N'Analyzer Version Reserved', NULL, NULL, N'DTA_PaySourcePricer', N'9(4)', 4, 0, N'INTEGER', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10819, 98, NULL, N'filler1', NULL, N'Filler', NULL, NULL, NULL, N'X(491)', 491, 0, N'TEXT', 0, NULL, NULL, NULL, 491, NULL, '00010101', '99991231', '20260407 00:00:00.000', '20250904 00:00:00.000', N'F', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10820, 98, N'E', N'hac_override_id', 5, N'HAC ID', NULL, N'', N'DTA_PaysourcePricer', N'X(10)', 10, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 10, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10821, 98, N'E', N'CCIBypass_flag', 10, N'CCIBypass', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10822, 98, N'E', N'ace_override_id', 14, N'ACE Override ID', NULL, N'', N'DTA_PaySourcePricer', N'X(20)', 20, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 20, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10823, 98, N'G', N'bwgt_option', 12, N'Birth Weight Option', NULL, N'', N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10824, 98, NULL, N'moe_flag', NULL, N'Medicaid Outpatient Editor Flag', NULL, NULL, NULL, N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10825, 98, NULL, N'state_key', NULL, N'State Key', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10826, 98, NULL, N'payer_key', NULL, N'Payer Key', NULL, NULL, NULL, N'X(14)', 14, 0, N'TEXT', 0, NULL, NULL, NULL, 14, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10827, 98, N'E', N'dsc_flag', 2, N'MCE', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', '20240905 00:00:00.000', N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10828, 98, N'E', N'edit_req_77', NULL, NULL, NULL, N'0', NULL, N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10829, 98, N'E', N'CCIRequest_flag', 9, N'CCIRequest', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10830, 98, N'E', N'oce_flag', 6, N'OCE', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10831, 98, N'E', N'ocewp_flag', 7, N'OCEWPairs', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10832, 98, N'E', N'lcd_flag', NULL, N'LCD', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10833, 98, N'E', N'nonoce_flag', 8, N'Non OPPS OCE', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10834, 98, N'E', N'poa_flag', 3, N'POA', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10835, 98, N'E', N'hac_flag', 4, N'HAC', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10836, 98, N'E', N'TRICAREOPPS', 13, N'TRICARE OPPS', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10837, 98, N'E', N'edit_req2', 20, N'Medicaid', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10838, 98, N'E', N'moe_flag', 18, N'Medicaid Outpatient Edits', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10839, 98, N'E', N'cah_oce_flag', 1, N'CAH Method OCE II', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10840, 98, N'E', N'othermedicare_flag', 21, N'Other Medicare', NULL, N'0', N'DTA_PaysourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', '20240919 00:00:00.000', N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10841, 98, N'E', N'edit_req2_92', NULL, NULL, NULL, N'0', NULL, N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10842, 98, N'E', N'edit_req2_93', NULL, NULL, NULL, N'0', NULL, N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10843, 98, N'E', N'edit_req2_94', NULL, NULL, NULL, N'0', NULL, N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10844, 98, N'E', N'edit_req2_95', NULL, NULL, NULL, N'0', NULL, N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10845, 98, NULL, N'filler1', NULL, N'Filler', NULL, NULL, NULL, N'X(31)', 31, 0, N'TEXT', 0, NULL, NULL, NULL, 31, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'F', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10846, 98, NULL, N'filler2', NULL, N'Filler', NULL, NULL, NULL, N'X(91)', 91, 0, N'TEXT', 0, NULL, NULL, NULL, 91, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'F', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10847, 98, NULL, N'payset', NULL, N'Care Setting', NULL, NULL, NULL, N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'R', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10848, 98, N'C', N'pattype', NULL, N'Patient Type', NULL, NULL, N'DTA_PaySource', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10849, 98, N'C', N'rf_vers', NULL, N'Rate File Version', NULL, NULL, N'DTA_PaySourcePricer', N'X(7)', 7, 0, N'TEXT', 0, NULL, NULL, N'^[0-9\d*(\.\d+)]+$|^| only numerics are allowed.', 7, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10850, 98, N'E', N'apc_override_id', 15, N'APC Override ID', NULL, N'', N'DTA_PaySourcePricer', N'X(20)', 20, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 20, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10851, 98, N'E', N'asc_override_id', 16, N'ASC Override ID', NULL, N'', N'DTA_PaySourcePricer', N'X(20)', 20, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 20, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10852, 98, N'E', N'mcd_override_id', 19, N'Medicaid APC Override ID', NULL, NULL, N'DTA_PaySourcePricer', N'X(20)', 20, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 20, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10853, 98, N'E', N'StateCCIValue', 17, N'StateCCI', NULL, NULL, N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10854, 98, N'G', N'facility_type', 11, N'Facility Type', NULL, N'00', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, NULL, 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'00')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10855, 98, N'G', N'line_bypass', 10, N'CCI/MUE Edits', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10856, 98, N'G', N'disch_drg_option', 13, N'Discharge APR DRG Option', NULL, N'', N'DTA_PaySourcePricer', N'X(1)', 1, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10857, 98, N'G', N'hac_version', 14, N'HAC Version', NULL, N'0', N'DTA_PaySourcePricer', N'9(2)v9(1)', 2, 1, N'DECIMAL', 0, 0, 99.9, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'00.0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10858, 98, N'G', N'vers_qual', 15, N'Version Qualifier', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'DECIMAL', 0, NULL, NULL, NULL, NULL, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10859, 98, N'G', N'icd9_routing', 8, N'ICD-9 Routing', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10860, 98, N'G', N'user_key', 9, N'User Key', NULL, N'', N'DTA_PaySourcePricer', N'X(3)', 3, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 3, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10861, 98, N'G', N'pay_except', 16, N'Payer Exceptions', NULL, N'', N'DTA_PaySourcePricer', N'X(2)', 2, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 2, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10862, 98, N'C', N'DoNotExport', 13, N'Do Not Export', NULL, N'0', N'DTA_PaySourcePricer', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10863, 98, N'C', N'InExportQueue', 14, N'Export Queue', NULL, N'0', N'DTA_PaySource', N'9(1)', 1, 0, N'BIT', 0, NULL, NULL, NULL, 1, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 1, N'0')
    INSERT INTO [dbo].[LUT_RateVariable] ([LutRvId], [LutPtId], [SectionCode], [VariableName], [Seq], [LabelOnUi], [VariableDescr], [DefaultValue], [TableName], [VariableFormat], [VariableLeftCount], [VariableRightCount], [VariableType], [IsRequired], [RangeMin], [RangeMax], [RegularExp], [MaxLength], [KeyType], [DisplayStartDate], [DisplayEndDate], [InsertedTS], [ModifiedTS], [VariableCategory], [UIVisible], [HiddenValue]) VALUES (10864, 98, N'G', N'ppc_vers', 17, N'PPC Version', NULL, NULL, N'DTA_PaySourcePricer', N'X(3)', 3, 0, N'TEXT', 0, NULL, NULL, N'^[a-zA-Z0-9]+$|^| special characters are not allowed.', 3, NULL, '00010101', '99991231', '20260407 00:00:00.000', NULL, N'U', 0, N'')
    -- [LUT_PricerTypeAPRPro_Procedure]
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (260, N'001 ', N'Claim Level Return Code 44: No Zip Code Provided', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (261, N'002 ', N'Claim Level Return Code 44: Service Zip Code Required for Patient Home', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (262, N'003 ', N'Claim Level Return Code 44: No Carrier Associated with Zip Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (263, N'004 ', N'Claim Level Return Code 43: Place of Service Not Applicable for Medicare', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (264, N'005 ', N'Claim Level Return Code 42: No Place of Service on Line', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (265, N'006 ', N'Claim Level Return Code 42: More than one Place of Service on Claim', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (266, N'007 ', N'Claim Level Return Code 42: Invalid Place of Service', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (267, N'050 ', N'Line Level Return Code 37: Missing or Invalid Status Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (268, N'051 ', N'Line Level Return Code 10: Line Item Denial or Rejection from Editor', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (269, N'052 ', N'Line Level Return Code 43: Editor Flagged as Not Enough Information for Pricing', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (270, N'053 ', N'Line Level Return Code 34: Service not Payable', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (271, N'054 ', N'Line Level Return Code 35: Service for Reporting Purposes Only', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (272, N'055 ', N'Line Level Return Code 45: Cannot Derive MPFS Payment Percentage', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (273, N'056 ', N'Line Level Return Code 16: Claim Contains a Never Event', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (274, N'057 ', N'Line Level Return Code 11: Invalid Units for Modifier', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (275, N'058 ', N'Line Level Return Code 32: Pricing Cannot be Provided for NDC', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (276, N'059 ', N'Line Level Return Code 33: Conditionally Bundled Service not Separately Payable', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (277, N'060 ', N'Line Level Return Code 33: Always Bundled Service not Separately Payable', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (278, N'061 ', N'Line Level Return Code 08: Invalid Bilateral Modifiers Provided for Pricing', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (279, N'062 ', N'Line Level Return Code 40: Anesthesia Time Units Divide by Zero Error', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (280, N'063 ', N'Line Level Return Code 42: Invalid or Missing Place of Service', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (281, N'064 ', N'Line Level Return Code 43: Not Enough Information for Pricing Provided', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (282, N'065 ', N'Line Level Return Code 36: Carrier Priced', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (283, N'066 ', N'Line Level Return Code 13: Zip Code Missing or Invalid', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (284, N'067 ', N'Line Level Return Code 08: Modifier Rejected for Pricing', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (285, N'068 ', N'Line Level Return Code 10: Line Item Denial or Rejection from Editor except MUE', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (286, N'100 ', N'Determine Payment Zip Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (287, N'101 ', N'Determine Status Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (288, N'102 ', N'Determine Payment Type for Status Code E or Payment Code 1', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (289, N'103 ', N'Determine if Anesthesia Service', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (290, N'104 ', N'Set Adjusted Rate to TC Rate + PC Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (291, N'105 ', N'Charge Cap', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (292, N'106 ', N'Specialty Discount Lookup Using Taxonomy', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (293, N'107 ', N'HCPCS Code Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (294, N'108 ', N'NDC Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (295, N'109 ', N'Determine Fractional Units', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (296, N'110 ', N'Determine Non-Ambulance Carriers by Zip Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (297, N'111 ', N'Determine Ambulance Carrier by Zip Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (298, N'112 ', N'Fee Schedule Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (299, N'113 ', N'Identify Lines for NDC Payment if HCPCS Rate is Unavailable', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (300, N'114 ', N'Apply Coverage and Coinsurance to Total Payment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (301, N'115 ', N'NDC Payment (NDC Rate * NDC Units)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (302, N'116 ', N'Determine OTA Reduction Eligibility', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (303, N'117 ', N'Determine PTA Reduction Eligibility', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (304, N'118 ', N'Set Non-MPFS Payment Type (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (305, N'119 ', N'Set MPFS Payment Type (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (306, N'120 ', N'Remove Fee Schedule Lookup Return Codes to Continue Processing', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (307, N'121 ', N'Determine Anesthesia Time Units with Modifier AD', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (308, N'122 ', N'Determine Coverage and Coinsurance Factors, and Carrier for All Fee Types', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (309, N'123 ', N'Determine Anesthesia Base Units with Modifier AD', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (310, N'124 ', N'Pay Reasonable Charges', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (311, N'125 ', N'Charge Cap for Endoscopy Services', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (312, N'126 ', N'Non-MPFS Fee Schedule Total Payment (Rate * Units)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (313, N'127 ', N'Waive Coinsurance', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (314, N'128 ', N'Determine Coverage and Coinsurance Factors for Anesthesia Services', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (315, N'129 ', N'Conditionally Set Anesthesia Time Units to Zero', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (316, N'130 ', N'Set Anesthesia Base Units from Fee Schedule', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (317, N'131 ', N'Zip Code Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (318, N'132 ', N'Set Anesthesia Conversion Factor from Fee Schedule', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (319, N'133 ', N'Anesthesia Total Payment ((Base Units + Time Units) * Conversion Factor)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (320, N'134 ', N'Apply Anesthesia Reduction for Modifier QK', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (321, N'135 ', N'Apply Anesthesia Reduction for Modifier QX', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (322, N'136 ', N'Apply Anesthesia Reduction for Modifier QY', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (323, N'137 ', N'Determine Ambulance Fee Schedule Rate (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (324, N'138 ', N'Fee Schedule Total Payment (Rate)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (325, N'139 ', N'Fee Schedule Total Payment for Ground Mileage (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (326, N'140 ', N'Apply Ambulance Multiple Patient Mileage Adjustment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (327, N'141 ', N'Apply Ambulance Multiple Patient Transport Adjustment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (328, N'142 ', N'Determine DME Fee Schedule Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (329, N'143 ', N'Determine Lab Fee Schedule Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (330, N'144 ', N'Determine National or Medicaid Fee Schedule Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (331, N'145 ', N'Determine Physician Fee Schedule Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (332, N'146 ', N'Determine User Defined Fee Schedule Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (333, N'147 ', N'Set Markup/Discount Factors', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (334, N'148 ', N'Determine Non-Facility MPFS Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (335, N'149 ', N'Determine Facility MPFS Rate', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (336, N'150 ', N'Determine TC/PC Rate for MPPR 4, 6 and 7', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (337, N'151 ', N'Determine TC/PC Rate for Modifiers "FX", "FY" and "CT"', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (338, N'152 ', N'Determine Number of Ambulance Patients and Corresponding Reduction Factor', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (339, N'153 ', N'Determine Rate for Endoscopy Base Code', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (340, N'154 ', N'MPPR 3 - Pre-Processing for Multiple Endoscopic Service Discounting', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (341, N'155 ', N'Determine Conditionally Bilateral Services Billed with RT and LT', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (342, N'156 ', N'Bundle Conditionally Bilateral LT Line into RT Line and Apply Adjustment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (343, N'157 ', N'Apply Conditionally Bilateral Adjustment (Modifier 50)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (344, N'158 ', N'Apply Independently Bilateral Adjustment (Modifier 50)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (345, N'159 ', N'MPPR 3 - Discounting for Multiple Endoscopic Procedures', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (346, N'160 ', N'MPPR 4 - Discounting for Multiple Diagnostic Imaging Procedures', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (347, N'161 ', N'MPPR 6 - Discounting for Multiple Cardiovascular Procedures', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (348, N'162 ', N'MPPR 7 - Discounting for Multiple Ophthalmology Procedures', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (349, N'163 ', N'MPPR 5 - Discounting for Multiple Therapy Services', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (350, N'164 ', N'MPPR 2 and 3 - Discounting for Multiple Procedures', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (351, N'165 ', N'Set Coverage and Coinsurance Factors for MPFS Paid Lines', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (352, N'166 ', N'MPFS Fee Schedule Total Payment (Rate * Units)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (353, N'167 ', N'Apply FX Reduction', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (354, N'168 ', N'Apply FY Reduction', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (355, N'169 ', N'Apply CT Reduction', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (356, N'170 ', N'Determine Co-Surgery Adjustment (Medicare Indicator & Modifier 62)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (357, N'171 ', N'Apply Co-Surgery Adjustment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (358, N'172 ', N'Determine Assistant at Surgery Adjustment (Medicare Indicator & Modifier AS)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (359, N'173 ', N'Determine Assistant at Surgery Adjustment (Medicare Indicator & Modifier 80)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (360, N'174 ', N'Determine Assistant at Surgery Adjustment (Medicare Indicator & Modifier 81)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (361, N'175 ', N'Determine Assistant at Surgery Adjustment (Medicare Indicator & Modifier 82)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (362, N'176 ', N'Apply Assistant at Surgery Adjustment', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (363, N'177 ', N'Apply Pre-Op, Intra-Op, and Post-Op Adjustments to Global Surgery (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (364, N'178 ', N'Determine Specialty Discount Eligibility (Medicare)', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (365, N'179 ', N'Apply Specialty Discount', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (366, N'180 ', N'Specialty Code Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (367, N'181 ', N'Modifier Lookup', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (368, N'182 ', N'Apply OTA/PTA Reduction', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (369, N'183 ', N'Apply Markup/Discount', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (370, N'184 ', N'Determine if Coinsurance Applies', 1, 98)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (371, N'NEED', N'Always be included', 1, 98)
    -- [LUT_PricerTypeAPRPro_ProcedureVariable]
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (267, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (270, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (271, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (276, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (277, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (279, 4547)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (281, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (282, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (287, 4520)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (301, 4555)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (301, 4556)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4549)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4550)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4551)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4552)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4553)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4554)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4555)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4556)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4557)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4558)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4559)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (308, 4560)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (309, 4546)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (310, 4522)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (314, 4557)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (314, 4558)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (320, 4543)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (321, 4544)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (322, 4545)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4563)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4564)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4565)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4566)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4567)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (333, 4568)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (338, 4561)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (338, 4562)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (342, 4533)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (343, 4533)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (344, 4534)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (346, 4523)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (346, 4524)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (346, 4525)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (346, 4526)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (346, 4534)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (347, 4527)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (347, 4528)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (348, 4529)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (348, 4530)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (350, 4531)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (350, 4532)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (351, 4557)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (351, 4558)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (353, 4542)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (354, 4541)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (355, 4540)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (356, 4539)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (358, 4535)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (359, 4536)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (360, 4537)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (361, 4538)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (371, 4519)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (371, 4521)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (298, 4548)  
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (371, 4573)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (371, 4520)

    -- [TML_PricerPageTL]
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7059, 98, 0, N'CustomGroupBox', NULL, N'State ', 8, N'Auto', 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7060, 98, 7059, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7061, 98, 7059, N'TextBox', N'Text', N'0', NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7062, 98, 7059, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7063, 98, 7059, N'ComboBox', N'SelectedValue', N'', NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7064, 98, 7059, N'Button', N'Content', N'Procedure Editor', NULL, NULL, 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7065, 98, 0, N'CustomGroupBox', NULL, N'State', 6, N'Auto', 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7066, 98, 0, N'CustomGroupBox', NULL, N'Base Reimbursement Variables', 6, N'Auto', 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7067, 98, 7066, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7068, 98, 7066, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7069, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 11, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7070, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 12, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7071, 98, 0, N'CustomGroupBox', NULL, N'Multiple Procedure Discount Factors', 6, N'Auto', 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7072, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 13, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7073, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 14, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7074, 98, 0, N'CustomGroupBox', NULL, N'Bilateral Adjustment Factors', 6, N'Auto', 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7075, 98, 7074, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7076, 98, 7074, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7077, 98, 7074, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7078, 98, 7074, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7079, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', '20241205 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7080, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', '20241205 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7081, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7082, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7083, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7084, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7085, 98, 7066, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', '20260324 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7086, 98, 7066, N'CheckBox', N'IsChecked', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', '20260324 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7090, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 17, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7091, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 18, 1, '20260407 00:00:00.000', '20250320 00:00:00.000')
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7092, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7093, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7094, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 11, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7095, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 12, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7096, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 13, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7097, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 14, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7098, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7099, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7100, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7101, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7102, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7103, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7104, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 15, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7105, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 16, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7106, 98, 7071, N'TextBlock', N'Text', NULL, NULL, NULL, 19, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7107, 98, 7071, N'TextBox', N'Text', NULL, NULL, NULL, 20, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7108, 98, 0, N'CustomGroupBox', NULL, N'Other Reduction Factors', 6, N'Auto', 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7109, 98, 0, N'CustomGroupBox', NULL, N'Anesthesia', 6, N'Auto', 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7110, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7111, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7112, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7113, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7114, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7115, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7116, 98, 7108, N'TextBlock', N'Text', NULL, NULL, NULL, 15, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7117, 98, 7108, N'TextBox', N'Text', NULL, NULL, NULL, 16, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7118, 98, 7109, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7119, 98, 7109, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7120, 98, 7109, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7121, 98, 7109, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7122, 98, 7109, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7123, 98, 7109, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7124, 98, 7109, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7125, 98, 7109, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7126, 98, 7109, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7127, 98, 7109, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7128, 98, 0, N'CustomGroupBox', NULL, N'Fee Schedule', 6, N'Manual', 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7129, 98, 7128, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7130, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7131, 98, 0, N'CustomGroupBox', NULL, N'Ambulance Adjustment Factors', 6, N'Auto', 8, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7132, 98, 7131, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7133, 98, 7131, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7134, 98, 7131, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7135, 98, 7131, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7136, 98, 0, N'CustomGroupBox', NULL, N'Markup Factors', 6, N'Auto', 9, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7137, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 1, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7138, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 2, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7139, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7140, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7141, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7142, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7143, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7144, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7145, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7146, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7147, 98, 7136, N'TextBlock', N'Text', NULL, NULL, NULL, 11, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7148, 98, 7136, N'TextBox', N'Text', NULL, NULL, NULL, 12, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7149, 98, 7128, N'TextBlock', N'Text', NULL, NULL, NULL, 100, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7150, 98, 7128, N'TextBlock', N'Text', N'Payment Factor:', NULL, NULL, 101, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7151, 98, 7128, N'TextBlock', N'Text', N'Co-payment Factor:', NULL, NULL, 102, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7152, 98, 7128, N'TextBlock', N'Text', N'Ambulance:', NULL, NULL, 200, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7153, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 201, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7154, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 202, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7155, 98, 7128, N'TextBlock', N'Text', N'DMEPOS:', NULL, NULL, 300, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7156, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 301, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7157, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 302, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7158, 98, 7128, N'TextBlock', N'Text', N'Laboratory:', NULL, NULL, 400, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7159, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 401, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7160, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 402, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7161, 98, 7128, N'TextBlock', N'Text', N'National or Medicaid Rates:', NULL, NULL, 500, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7162, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 501, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7163, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 502, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7164, 98, 7128, N'TextBlock', N'Text', N'Physician Fee:', NULL, NULL, 600, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7165, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 601, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7166, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 602, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7167, 98, 7128, N'TextBlock', N'Text', N'X - Other:', NULL, NULL, 700, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7168, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 701, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7169, 98, 7128, N'TextBox', N'Text', NULL, NULL, NULL, 702, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7170, 98, 7066, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7171, 98, 7066, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20260407 00:00:00.000', NULL)
-- [TML_PricerPageTLAttr]
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (523, 7063, N'MinWidth', N'110', 1, '20260407 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (524, 7060, N'Visibility', N'Collapsed', 1, '20260407 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (525, 7061, N'Visibility', N'Collapsed', 1, '20260407 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (526, 7064, N'IsEnabled', N'{Binding MedicaidAPRPro_IsEnableStateEditButton}', 1, '20260407 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (527, 7064, N'Command', N'{Binding Parent.MedicaidAPRPro_StateEdit}', 1, '20260407 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (528, 7064, N'Margin', N'5,0,0,0', 1, '20260407 00:00:00.000', '00010101', '99991231')
    -- [LUT_RateFileVariable]
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10382, 10768, 5, 257, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10383, 10769, 5, 261, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10384, 10770, 5, 267, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10385, 10771, 5, 268, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10386, 10772, 5, 269, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10387, 10773, 5, 270, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10388, 10774, 5, 271, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10389, 10775, 5, 272, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10390, 10776, 5, 273, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10391, 10777, 5, 1, 16, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10392, 10777, 11, 1, 16, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10393, 10777, 17, 1, 16, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10394, 10778, 5, 1, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10395, 10778, 11, 1, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10396, 10778, 17, 1, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10397, 10779, 5, 11, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10398, 10779, 11, 11, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10399, 10779, 17, 11, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10400, 10780, 5, 17, 13, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10401, 10780, 11, 17, 13, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10402, 10780, 17, 17, 13, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10403, 10781, 11, 32, 25, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10404, 10782, 11, 57, 5, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10405, 10783, 5, 36, 8, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10406, 10783, 17, 30, 8, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10407, 10784, 5, 52, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10408, 10784, 17, 504, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10409, 10785, 11, 96, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10410, 10786, 5, 160, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10411, 10786, 11, 95, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10412, 10787, 5, 21, 9, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10413, 10787, 11, 21, 9, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10414, 10787, 17, 21, 9, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10415, 10792, 5, 56, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10416, 10792, 17, 56, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10417, 10793, 5, 60, 3, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10418, 10794, 5, 304, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10419, 10795, 5, 116, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10420, 10795, 17, 506, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10421, 10796, 5, 220, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10422, 10797, 5, 218, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10423, 10798, 5, 198, 20, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10424, 10790, 5, 86, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10425, 10791, 5, 88, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10426, 10784, 11, 62, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10427, 10788, 5, 222, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10428, 10789, 5, 159, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10429, 10799, 5, 32, 4, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10430, 10800, 5, 44, 8, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10431, 10801, 5, 54, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10432, 10802, 5, 58, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10433, 10803, 5, 63, 3, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10434, 10804, 5, 66, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10435, 10805, 5, 68, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10436, 10806, 5, 70, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10437, 10807, 5, 72, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10438, 10808, 5, 73, 3, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10439, 10809, 5, 96, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10440, 10810, 5, 106, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10441, 10811, 5, 117, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10442, 10812, 5, 118, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10443, 10813, 5, 149, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10444, 10814, 5, 150, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10445, 10815, 5, 151, 8, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10446, 10816, 5, 228, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10447, 10817, 5, 259, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10448, 10818, 5, 263, 4, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10449, 10819, 5, 310, 491, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10450, 10824, 5, 303, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10451, 10825, 5, 162, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10452, 10826, 5, 164, 14, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10453, 10827, 5, 76, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10454, 10828, 5, 77, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10455, 10829, 5, 78, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10456, 10830, 5, 79, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10457, 10831, 5, 80, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10458, 10832, 5, 81, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10459, 10833, 5, 82, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10460, 10834, 5, 83, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10461, 10835, 5, 84, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10462, 10836, 5, 85, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10463, 10837, 5, 87, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10464, 10838, 5, 89, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10465, 10839, 5, 90, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10466, 10840, 5, 91, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10467, 10841, 5, 92, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10468, 10842, 5, 93, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10469, 10843, 5, 94, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10470, 10844, 5, 95, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10471, 10845, 11, 64, 31, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10472, 10846, 11, 101, 91, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10473, 10847, 11, 30, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10474, 10848, 11, 99, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10475, 10789, 11, 98, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10476, 10848, 5, 30, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10477, 10849, 5, 276, 7, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10478, 10820, 5, 139, 10, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10479, 10821, 5, 161, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10480, 10822, 5, 119, 20, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10481, 10850, 5, 236, 20, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10482, 10851, 5, 178, 20, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10483, 10852, 5, 283, 20, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10484, 10853, 5, 229, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10485, 10854, 5, 274, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10486, 10855, 5, 234, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10487, 10823, 5, 223, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10488, 10856, 5, 224, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10489, 10857, 5, 225, 3, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10490, 10858, 5, 256, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10491, 10859, 5, 235, 1, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10492, 10860, 5, 231, 3, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10493, 10861, 5, 305, 2, '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateFileVariable] ([LutRfvId], [LutRvId], [LutRfId], [StartPosition], [VariableSize], [InsertedTS], [ModifiedTS]) VALUES (10494, 10864, 5, 307, 3, '20260407 00:00:00.000', NULL)
    -- [LUT_PricerTypeAPRPro_StateProcedure]
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 260, 1, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 261, 6, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 262, 10, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 263, 5, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 264, 2, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 265, 3, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 266, 4, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 267, 32, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 268, 12, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 269, 13, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 270, 34, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 271, 35, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 272, 17, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 273, 21, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 274, 22, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 275, 29, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 276, 31, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 277, 33, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 278, 36, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 279, 38, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 280, 18, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 281, 24, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 282, 78, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 283, 50, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 284, 20, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 285, 14, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 286, 7, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 287, 23, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 288, 39, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 289, 37, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 290, 70, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 291, 109, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 292, 16, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 293, 25, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 294, 26, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 295, 47, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 296, 9, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 297, 11, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 298, 27, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 299, 28, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 300, 104, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 301, 72, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 302, 105, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 303, 106, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 304, 45, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 305, 46, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 306, 30, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 307, 40, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 308, 51, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 309, 41, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 310, 76, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 311, 108, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 312, 77, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 313, 103, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 314, 49, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 315, 42, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 316, 43, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 317, 8, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 318, 44, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 319, 71, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 320, 97, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 321, 96, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 322, 95, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 323, 52, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 324, 74, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 325, 75, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 326, 94, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 327, 93, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 328, 53, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 329, 54, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 330, 55, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 331, 56, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 332, 57, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 333, 110, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 334, 58, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 335, 59, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 336, 60, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 337, 61, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 338, 92, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 339, 62, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 340, 79, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 341, 63, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 342, 88, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 343, 87, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 344, 86, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 345, 80, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 346, 81, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 347, 82, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 348, 83, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 349, 84, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 350, 85, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 351, 48, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 352, 73, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 353, 89, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 354, 90, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 355, 91, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 356, 65, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 357, 98, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 358, 66, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 359, 67, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 360, 68, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 361, 69, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 362, 100, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 363, 99, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 364, 64, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 365, 101, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 366, 15, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 367, 19, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 368, 107, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 369, 111, '20260407 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (82, 370, 102, '20260407 00:00:00.000')
    -- [LUT_PricerTypeAPRPro_State]
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (82, 98, N'MR', N'Medicare', '20260101 00:00:00.000', 5, 1)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (83, 98, N'', N'None', '19000101 00:00:00.000', 1, 1)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (84, 98, N'OT', N'Other', '20260101 00:00:00.000', 10, 1)
    -- [LUT_RateVariableMap]
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4633, 10795, N'0', 10796, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4634, 10795, N'2', 10796, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4635, 10768, N'00', 10769, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4636, 10768, N'00', 10770, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4637, 10768, N'00', 10771, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4638, 10768, N'00', 10772, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4639, 10768, N'00', 10773, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4640, 10768, N'00', 10774, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4641, 10768, N'00', 10775, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    INSERT INTO [dbo].[LUT_RateVariableMap] ([LutRvmId], [Parent_LutRvId], [ParentValue], [LutRvId], [IsHidden], [IsDisabled], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (4642, 10768, N'00', 10776, 1, 0, '00010101', '99991231', '20260407 00:00:00.000', NULL)
    -- [LUT_RateEditingMapping]
    INSERT INTO [dbo].[LUT_RateEditingMapping] ([LUTREMID], [LUTPTID], [DSCVisible], [DSCValue], [POAVisible], [POAValue], [HACVisible], [HACValue], [HACIDValue], [OCEVisible], [OCEValue], [OCEWPairsVisible], [OCEWParsValue], [NONOCEVisible], [NONOCEValue], [LCDVisible], [LCDValue], [MappingVisible], [MappingValue], [MapCategoryVisible], [MapCategoryValue], [MapTypeVisible], [MapTypeValue], [MapIDVisible], [MapIDValue], [ace_override_idVisible], [ace_override_idValue], [CCIRequestVisible], [CCIRequestValue], [CCIBypassVisible], [CCIBypassValue], [PhysicianEditVisible], [PhysicianEditValue], [TRICAREOPPSVisible], [TRICAREOPPSValue], [asc_override_idVisible], [asc_override_idValue], [state_cci_Visible], [StateCCIValue], [user_keyValue], [line_bypassValue], [icd9_routingValue], [apc_override_idVisible], [apc_override_idValue], [vers_qualValue], [edit_req2Visible], [edit_req2Value], [facility_typeValue], [PhysEdit_MaxDMEVisible], [PhysEdit_MaxDMEValue], [moe_flagVisible], [moe_flagValue], [mcd_override_idVisible], [mcd_override_idValue], [cah_oceVisible], [cah_oceValue], [grpr_dateValue], [pay_exceptValue], [othermedicare_flagVisible], [othermedicare_flagValue]) VALUES (70, 98, 0, 0, 0, 0, 0, 0, N'', 0, 0, 0, 0, 0, 0, 0, 0, 1, N'0', 1, N'01', 1, N'00', 1, N'', 0, N'', 0, 0, 0, 0, 1, 0, NULL, NULL, NULL, NULL, 0, N'', NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0)
    -- [LUT_CareSetting]
    Update [dbo].[LUT_CareSetting] set [IOFileName] = 'cfgphys|medphys|payphys|medext04' where [LUTCSID] = 5
    -- [LUT_RateFile]
    INSERT [dbo].[LUT_RateFile] ([LutRfId], [LutCsId], [FileName], [FileCategory], [RecordLength], [StartDate], [EndDate], [InsertedTS], [ModifiedTS]) VALUES (28, N'5 ', N'medext04', N'med', 0, CAST(N'0001-01-01' AS Date), CAST(N'9999-12-31' AS Date), CAST(N'2026-03-31T00:00:00.000' AS DateTime), NULL)


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
