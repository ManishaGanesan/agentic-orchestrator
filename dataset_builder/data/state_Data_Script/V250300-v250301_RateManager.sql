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
SET @FromDVersion = '2503.00'; -- the DVersion in the database
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
PRINT N'Altering Table [dbo].[PPS_meddrgprc_73]...';


GO
ALTER TABLE [dbo].[PPS_meddrgprc_73]
    ADD [meded]    VARCHAR (7)  NULL,
        [ime]      VARCHAR (7)  NULL,
        [perdiem2] VARCHAR (10) NULL,
        [cut_age1] VARCHAR (3)  NULL,
        [factor2]  VARCHAR (7)  NULL;


GO
PRINT N'Update complete.';

PRINT N'Alter View VW_EDR_CodeTables';

GO
ALTER VIEW [dbo].[VW_EDR_CodeTables]
AS
SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ID, * FROM(

SELECT 
    std.FileId					AS FileId,
	0                           AS CodeTableId,
    cust.ProductionDateId AS ProductionDateId,
	pd.ProductionDate AS ProductionDate,
    std.filename				AS FileName,
    STUFF((SELECT ', ' + pt.pricertypedescr
           FROM [dbo].[LUT_CodeTablePricerType] ctp WITH (NOLOCK)
           INNER JOIN [dbo].[lut_pricertype] pt  WITH (NOLOCK)
				ON ctp.PricerTypeId = pt.lutptid 
           WHERE ctp.FileId = std.FileId
		   FOR XML PATH('')), 1, 2, '') AS PricerType,
           ''						AS Status,
    FORMAT(COALESCE(std.ModifiedDate, std.CreatedDate), 'MM/dd/yyyy hh:mm:ss tt') AS ActionDate,
    'Optum Supplied' AS Type,
    cust.IsImported AS IsImported,
	 Max(cust.FileLastWriteDate) AS FileLastWriteDate
	FROM [dbo].[LUT_CodeTableFile] std WITH (NOLOCK)
		LEFT JOIN [dbo].[EDR_CodeTable] cust WITH (NOLOCK)
			ON std.FileId = cust.FileId
        LEFT JOIN [dbo].[DTA_ProductionDate] pd  WITH (NOLOCK)
            ON cust.ProductionDateId = pd.DTAPDID
	WHERE cust.FileId IS NULL
	AND std.FileId != 8 -- Excluding Codenc2(legacy).dat US1365165
	GROUP BY std.FileId, std.FileName, cust.ProductionDateId, pd.ProductionDate, COALESCE(std.ModifiedDate, std.CreatedDate), IsImported

UNION

SELECT 
	cust.FileId						    AS FileId,
	    cust.CodeTableId				AS CodeTableId,
        cust.ProductionDateId AS ProductionDateId,
	    pd.ProductionDate AS ProductionDate,
        cust.filename               	AS FileName,
    STUFF((SELECT ', ' + pt.pricertypedescr
           FROM [dbo].[LUT_CodeTableFile] std WITH (NOLOCK)
           INNER JOIN [dbo].[LUT_CodeTablePricerType] ctp WITH (NOLOCK)
				ON std.FileId = ctp.FileId
           INNER JOIN [dbo].[lut_pricertype] pt WITH (NOLOCK)
				ON ctp.PricerTypeId = pt.lutptid 
           WHERE std.FileId = cust.FileId
           FOR XML PATH('')), 1, 2, '') AS PricerType,
    CASE
        WHEN ld.LockFlag = 1 OR ld.LockFlag = 2 THEN 'Locked:' + MAX(ld.LoginUser) 
        ELSE ''
    END AS Status,
    FORMAT(COALESCE(cust.ModifiedDate, cust.CreatedDate), 'MM/dd/yyyy hh:mm:ss tt') AS ActionDate,
    Case WHEN cust.IsImported=1 then 'User Imported' else 'User Modified' end AS Type,
    cust.IsImported AS IsImported,
	 Max(cust.FileLastWriteDate) AS FileLastWriteDate
	FROM [dbo].[EDR_CodeTable] cust WITH (NOLOCK)
		INNER JOIN [dbo].[LUT_CodeTableFile] std  WITH (NOLOCK)
			ON std.FileId = cust.FileId
    LEFT JOIN [dbo].[DTA_LockData] ld WITH (NOLOCK)
			ON cust.CodeTableId = ld.LockValue 
                AND ld.tablename = 'EDR_CodeTable'
    LEFT JOIN [dbo].[DTA_ProductionDate] pd  WITH (NOLOCK)
            ON cust.ProductionDateId = pd.DTAPDID
	GROUP BY cust.CodeTableId, cust.FileName, cust.FileId,cust.IsImported, COALESCE(cust.ModifiedDate, cust.CreatedDate), ld.LockFlag, cust.ProductionDateId, pd.ProductionDate, IsImported
	
UNION 

SELECT 
    std.FileId					AS FileId,
	0						AS CodeTableId,
    cust.ProductionDateId AS ProductionDateId,
	pd.ProductionDate AS ProductionDate,
    std.filename				AS FileName,
    STUFF((SELECT ', ' + pt.pricertypedescr
           FROM [dbo].[LUT_CodeTablePricerType] ctp WITH (NOLOCK)
           INNER JOIN [dbo].[lut_pricertype] pt WITH (NOLOCK)
				ON ctp.PricerTypeId = pt.lutptid 
           WHERE ctp.FileId = std.FileId
		   FOR XML PATH('')), 1, 2, '') AS PricerType,
           ''						AS Status,
    FORMAT(COALESCE(std.ModifiedDate, std.CreatedDate), 'MM/dd/yyyy hh:mm:ss tt') AS ActionDate,
    'Optum Supplied' AS Type,
    CAST(0 as Bit) AS IsImported,
    Max(cust.FileLastWriteDate) AS FileLastWriteDate
    FROM [dbo].[LUT_CodeTableFile] std WITH (NOLOCK)
    LEFT JOIN [dbo].[EDR_CodeTable] cust WITH (NOLOCK)
        ON std.FileId = cust.FileId
    LEFT JOIN [dbo].[DTA_ProductionDate] pd  WITH (NOLOCK)
        ON cust.ProductionDateId = pd.DTAPDID
    WHERE cust.FileId IS not NULL and LOWER(cust.FileName) <> LOWER(std.FileName) and std.FileName not in (Select FileName from [dbo].[EDR_CodeTable]) and cust.ProductionDateId = 0
    AND std.FileId != 8 -- Excluding Codenc2(legacy).dat US1365165
    GROUP BY std.FileId, std.FileName, COALESCE(std.ModifiedDate, std.CreatedDate), cust.ProductionDateId, pd.ProductionDate  

) AS RESULT
GO

GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2503.00', N'2503.01', NULL, GETDATE())

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


    DELETE FROM [dbo].[LUT_CodeTableField] WHERE [FieldId] = 700
    DELETE FROM [dbo].[LUT_CodeTableField] WHERE [FieldId] = 785

INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (790, 42, N'Column6', N'Revenue Code Flag', 1, 10, N'revflag', N'Oklahoma Medicaid: 0 = Not applicable 1 = Rev Code for PIC Per Diem 2 = Rev Code for Neonatal Claim 3 = Rev Code for Neonatal Claim', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 36, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (791, 42, N'Column7', N'HCPCS Flag', 1, 11, N'hcpcsflag', N'Oklahoma Medicaid: 0 = Not applicable 1 = HCPC for PIC Per Diem', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 37, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (792, 42, N'Column8', N'ICD-10 Procedure Code Flag', 1, 12, N'procflag', N'Oklahoma Medicaid: 0 = Not applicable 1 = Procedure Code used for DRG assignment', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 38, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (793, 42, N'Column9', N'DRG', 1, 13, N'drg', N'DRG', N'TextBox', 5, N'Integer', 5, NULL, N'9(5)', 39, 0, 99999, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (794, 42, NULL, N'Filler', 0, NULL, N'filler', NULL, NULL, 207, N'Filler', 207, NULL, N'X(207)', 44, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL)

UPDATE [dbo].[LUT_CodeTableField] SET [LabelOnUI] = N'HCPCS Flag' where [FieldId] = 784
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (795, 48, N'Column8', N'ICD-10 Procedure Code Flag', 1, 12, N'procflag', N'Iowa Medicaid: 0 = Not applicable 1 = Procedure Code used for DRG assignment', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 38, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (796, 48, N'Column9', N'DRG', 1, 13, N'drg', N'DRG', N'TextBox', 5, N'Integer', 5, NULL, N'9(5)', 39, 0, 99999, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (797, 48, NULL, N'Filler', 0, NULL, N'filler', NULL, NULL, 207, N'Filler', 207, NULL, N'X(207)', 44, NULL, NULL, NULL, NULL, CAST(N'2024-12-05T00:00:00.000' AS DateTime), CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL)

UPDATE [dbo].[LUT_CodeTableFile] SET [FileName] = N'codenc2(legacy).dat', [ModifiedDate] = CAST(N'2025-03-20T00:00:00.000' AS DateTime) where [FileId] = 8
UPDATE [dbo].[EDR_CodeTable] SET [FileName] = N'codenc2(legacy).dat' where [FileName] = N'codenc2.dat' and [FileId] = 8

INSERT [dbo].[LUT_CodeTableFile] ([FileId], [FileName], [CreatedDate], [ModifiedDate], [CreatedBy], [ModifiedBy]) VALUES (49, N'codenc2.dat', CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTablePricerType] ([FileId], [PricerTypeId]) VALUES (49, 96)

INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (798, 49, N'CodeType', N'Code Type', 1, 1, N'codetype', N'Iowa Medicaid: B = UB-04 Bill Type C = Procedure Code Q = Discharge status R = Revenue Code', N'TextBox', 1, N'Text', 1, NULL, N'X(1)', 1, NULL, NULL, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, 1, N'ASC')
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (799, 49, N'Code', N'Code', 1, 2, N'code', N'Code value will be one of the following: 
- B: 0110  - non covered claim
- B: 018X  - add all values for “X” = 0-9 (swing bed per diem claim)
- B: 028X  - add all values for “X” = 0-9 (swing bed per diem claim)
- C: 90899 - HCPC for PIC Per Diem
- Q: 02    - transfer dstat
- Q: 05    - transfer dstat
- R: 0173  - Rev Code for Neonatal Claim
- R: 0174  - Rev Code for Neonatal Claim
- R: 0204  - Rev Code for PIC Per Diem', N'TextBox', 11, N'Text', 11, NULL, N'X(11)', 2, NULL, NULL, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, 2, N'ASC')
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (800, 49, NULL, N'Code Sequence', 0, NULL, N'codeseq', N'Sequence number for this code record.', NULL, 2, N'Decimal', 2, NULL, N'9(2)', 13, 0, 99, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (801, 49, N'StartDate', N'Start Date', 1, 3, N'startdate', N'Date record is effective.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 15, NULL, NULL, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, 1, N'DESC', NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (802, 49, N'EndDate', N'End Date', 1, 4, N'enddate', N'00000000 = Code is still in effect YYYYMMDD = End date for record.', N'TextBox', 8, N'Date', 8, NULL, N'9(8)', 23, NULL, NULL, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (803, 49, N'Column1', N'Transfer Discharge Status or Admit Source', 1, 5, N'transfer', N'North Carolina Medicaid: 0 = Not applicable 1 = transfer dstat', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 31, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (804, 49, N'Column2', N'Bill Type Flag', 1, 6, N'billtype_flag', N'North Carolina Medicaid: 0 = Not applicable 1 = non covered claim 2 = add all values for “X” = 0-9 (swing bed per diem claim)', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 32, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (805, 49, N'Column3', N'Discharge Status Flag', 1, 7, N'dstat_flag', N'North Carolina Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 33, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (806, 49, N'Column4', N'Admission Source Flag', 1, 8, N'admsrc_flag', N'North Carolina Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 34, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (807, 49, N'Column5', N'MS-DRG Flag', 1, 9, N'msdrg_flag', N'North Carolina Medicaid: 0 = Not applicable', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 35, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (808, 49, N'Column6', N'Revenue Code Flag', 1, 10, N'revflag', N'North Carolina Medicaid: 0 = Not applicable 1 = Rev Code for PIC Per Diem 2 = Rev Code for Neonatal Claim 3 = Rev Code for Neonatal Claim', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 36, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (809, 49, N'Column7', N'HCPCS Flag', 1, 11, N'hcpcsflag', N'North Carolina Medicaid: 0 = Not applicable 1 = HCPC for PIC Per Diem', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 37, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (810, 49, N'Column8', N'ICD-10 Procedure Code Flag', 1, 12, N'procflag', N'North Carolina Medicaid: 0 = Not applicable 1 = Procedure Code used for DRG assignment', N'TextBox', 1, N'Integer', 1, NULL, N'9(1)', 38, 0, 9, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (811, 49, N'Column9', N'DRG', 1, 13, N'drg', N'DRG', N'TextBox', 5, N'Integer', 5, NULL, N'9(5)', 39, 0, 99999, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)
INSERT [dbo].[LUT_CodeTableField] ([FieldId], [FileId], [ColumnName], [LabelOnUI], [DisplayOnUI], [DisplayOrder], [FieldName], [FieldDescription], [ControlType], [FieldLength], [FieldType], [FieldLeftCount], [FieldRightCount], [FieldFormat], [ExportPosition], [RangeMin], [RangeMax], [RegEx], [RegExMessage], [CreatedDate], [ModifiedDate], [CodeSeqOrder], [CodeSortOrder], [KeyOrder], [KeySort]) VALUES (812, 49, NULL, N'Filler', 0, NULL, N'filler', NULL, NULL, 207, N'Filler', 207, NULL, N'X(207)', 44, NULL, NULL, NULL, NULL, CAST(N'2025-03-20T00:00:00.000' AS DateTime), NULL, NULL, NULL, NULL, NULL)

    INSERT [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (78, 96, N'NC', N'North Carolina', CAST(N'2025-04-01T00:00:00.000' AS DateTime), 5, 1)

    Update [dbo].[LUT_PricerTypeAPRPro_Procedure] 
    Set PDescription = 'Set Long Stay Marginal Cost Factors'
    where LUTPTID = 96 and PCode = '0083'

    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (238, N'0009', N'Return Code 13: Same Day Discharge', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (239, N'0053', N'Procedure Level Code Table Lookup', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (240, N'0084', N'Set Short Stay Marginal Cost Factor', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (241, N'0085', N'Set transfer flag (NC)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (242, N'0086', N'Group Medicaid-Specific DRGs (NC)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (243, N'0087', N'DRG Per Diem 1', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (244, N'0088', N'DRG Per Diem 2', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (245, N'0089', N'Combined Direct and Indirect Medical Education', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (246, N'0090', N'Apply Medical Education to Base', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (247, N'0091', N'Long Stay Outlier Eligibility', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (248, N'0092', N'Long Stay Outlier Eligibility (Children) (NC)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (249, N'0093', N'Set Covered Days 2', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (250, N'0094', N'Calculate Cost Outlier Threshold 2 (flat rate)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (251, N'0095', N'Calculate Cost Outlier Threshold (DRG Rate)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (252, N'0098', N'Set Outlier Output 2 (NC)', 1, 96)
    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (253, N'0099', N'Apply Claim Factor 2 (1 + Factor 2)', 1, 96)


    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 187, 1, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 189, 2, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 182, 3, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 183, 4, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 184, 5, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 238, 6, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 239, 7, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 221, 8, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 242, 9, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 186, 10, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 243, 11, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 244, 12, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 241, 13, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 248, 14, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 185, 15, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 245, 16, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 246, 17, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 192, 18, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 249, 19, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 236, 20, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 229, 21, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 228, 22, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 197, 23, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 199, 24, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 250, 25, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 251, 26, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 226, 27, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 200, 28, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 224, 29, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 196, 30, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 195, 31, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 194, 32, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 252, 33, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 253, 34, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (78, 203, 35, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 233, 35, CAST(N'2025-03-20T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (76, 203, 36, CAST(N'2025-03-20T00:00:00.000' AS DateTime))

    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 247 WHERE LUTSID = 76 and DisplayOrder = 10
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 185 WHERE LUTSID = 76 and DisplayOrder = 11
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 235 WHERE LUTSID = 76 and DisplayOrder = 12
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 220 WHERE LUTSID = 76 and DisplayOrder = 13
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 192 WHERE LUTSID = 76 and DisplayOrder = 14
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 224 WHERE LUTSID = 76 and DisplayOrder = 15
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 196 WHERE LUTSID = 76 and DisplayOrder = 16
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 195 WHERE LUTSID = 76 and DisplayOrder = 17
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 194 WHERE LUTSID = 76 and DisplayOrder = 18
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 197 WHERE LUTSID = 76 and DisplayOrder = 19
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 199 WHERE LUTSID = 76 and DisplayOrder = 20
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 225 WHERE LUTSID = 76 and DisplayOrder = 21
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 198 WHERE LUTSID = 76 and DisplayOrder = 22
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 226 WHERE LUTSID = 76 and DisplayOrder = 23
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 200 WHERE LUTSID = 76 and DisplayOrder = 24
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 236 WHERE LUTSID = 76 and DisplayOrder = 25
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 240 WHERE LUTSID = 76 and DisplayOrder = 26
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 227 WHERE LUTSID = 76 and DisplayOrder = 27
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 229 WHERE LUTSID = 76 and DisplayOrder = 28
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 230 WHERE LUTSID = 76 and DisplayOrder = 29
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 228 WHERE LUTSID = 76 and DisplayOrder = 30
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 201 WHERE LUTSID = 76 and DisplayOrder = 31
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 231 WHERE LUTSID = 76 and DisplayOrder = 32
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 232 WHERE LUTSID = 76 and DisplayOrder = 33
    UPDATE dbo.LUT_PricerTypeAPRPro_StateProcedure SET LUTPID = 234 WHERE LUTSID = 76 and DisplayOrder = 34


    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4476, 96, N'E.3', N'meded', N'An adjustment for the direct costs of providing medical education.', N'DECIMAL', 1, 6, N'9(1)v9(6)', NULL, N'Direct Medical Education Factor:', N'0.000000', NULL, 7, 338, 0, NULL, NULL, 0, 9.999999, NULL, 3, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4477, 96, N'E.4', N'ime', N'An adjustment for the indirect costs of medical education.', N'DECIMAL', 1, 6, N'9(1)v9(6)', NULL, N'Indirect Medical Education Factor:', N'0.000000', NULL, 7, 345, 0, NULL, NULL, 0, 9.999999, NULL, 3, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4478, 96, N'E.6', N'perdiem2', N'Hospital-specific per diem rate 2.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'Per Diem 2:$', N'0.00', NULL, 10, 328, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4479, 96, N'F.2', N'cut_age1', N'Age limit designation.', N'DECIMAL', 3, 0, N'9(3)', NULL, N'Age Limit 1:', N'0', NULL, 3, 352, 0, NULL, NULL, 0, 999, NULL, 3, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4480, 96, N'F.5', N'factor2', N'Hospital-specific claim adjustment factor.', N'DECIMAL', 1, 6, N'9(1)v9(6)', NULL, N'Factor 2:', N'0.000000', NULL, 7, 355, 0, NULL, NULL, 0, 9.999999, NULL, 3, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4481, 96, N'', N'filler1', N'', N'FILLER', 75, 0, N'X(75)', NULL, N'Filler:', N'', NULL, 75, 362, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20250320 00:00:00.000', NULL, '00010101', '99991231', NULL)

    DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4458

    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (240, 4457)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (243, 4452)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (244, 4478)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (245, 4477)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (245, 4476)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (246, 4361)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (248, 4479)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (250, 4365)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (253, 4480)

    UPDATE [dbo].[LUT_PricerTypeVariable] set SEQ = 'E.5' where LUTPTVID = 4452 
    UPDATE [dbo].[LUT_PricerTypeVariable] set SEQ = 'E.7' where LUTPTVID = 4362
    UPDATE [dbo].[LUT_PricerTypeVariable] set SEQ = 'F.3' where LUTPTVID = 4453
    UPDATE [dbo].[LUT_PricerTypeVariable] set SEQ = 'F.4' where LUTPTVID = 4454


    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=13, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6907
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=14, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6908
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=9, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6988
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=10, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6989
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=5, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6990
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=6, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6991
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=7, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6995
    UPDATE [dbo].[TML_PricerPageTL] SET [DisplayOrder]=8, [ModifiedTS]='20250320 00:00:00.000' WHERE [TMLPPTID]=6996

    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7019, 96, 6904, N'TextBlock', N'Text', NULL, NULL, NULL, 5, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7020, 96, 6904, N'TextBox', N'Text', NULL, NULL, NULL, 6, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7021, 96, 6904, N'TextBlock', N'Text', NULL, NULL, NULL, 7, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7022, 96, 6904, N'TextBox', N'Text', NULL, NULL, NULL, 8, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7023, 96, 6904, N'TextBlock', N'Text', NULL, NULL, NULL, 11, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7024, 96, 6904, N'TextBox', N'Text', NULL, NULL, NULL, 12, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7025, 96, 6909, N'TextBlock', N'Text', NULL, NULL, NULL, 3, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7026, 96, 6909, N'TextBox', N'Text', NULL, NULL, NULL, 4, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7027, 96, 6909, N'TextBlock', N'Text', NULL, NULL, NULL, 9, 1, '20250320 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7028, 96, 6909, N'TextBox', N'Text', NULL, NULL, NULL, 10, 1, '20250320 00:00:00.000', NULL)

    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3891, 7019, 4476)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3892, 7020, 4476)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3893, 7021, 4477)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3894, 7022, 4477)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3895, 7023, 4478)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3896, 7024, 4478)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3897, 7025, 4479)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3898, 7026, 4479)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3899, 7027, 4480)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3900, 7028, 4480)


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