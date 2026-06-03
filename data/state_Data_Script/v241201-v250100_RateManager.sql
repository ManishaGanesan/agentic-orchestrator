USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v241201 to v250100.
Run this script on [RateManager] v241201 to upgrade it to [RateManager] v250100.
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
SET @FromDVersion = '2412.01'; -- the DVersion in the database
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

-- V2501.00 - RHC Pricer: Intensive Outpatient Program Field Updates
GO
PRINT N'Altering Table [dbo].[PPS_rhcprc_69]...';

GO
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[PPS_rhcprc_69]')
          AND name = 'iop_rate2'
)
BEGIN
    ALTER TABLE [dbo].[PPS_rhcprc_69] ADD [iop_rate2] VARCHAR(10) NULL
END

--V2501.00 - Medicaid APG Pro Pricer: Updating Terminated Procedure Discounting Logic
GO
    PRINT N'Altering Table [dbo].[PPS_medapgprc_44]...';
 
    GO
    IF NOT EXISTS (
      SELECT 1 
      FROM   sys.columns 
      WHERE  object_id = OBJECT_ID(N'[dbo].[PPS_medapgprc_44]') 
             AND name = 'discflag'
    )
    BEGIN
	    ALTER TABLE [dbo].[PPS_medapgprc_44] ADD discflag  VARCHAR (200) NULL;
END

GO
    PRINT N'Altering Table [dbo].[TML_PricerPageTL]...';
    ALTER TABLE [dbo].[TML_PricerPageTL] ALTER COLUMN [FieldTextValue] varchar(200) NULL;

GO
    PRINT N'Altering Table [dbo].[TMP_IM_medext_44]...';
 
    GO
    IF NOT EXISTS (
      SELECT 1 
      FROM   sys.columns 
      WHERE  object_id = OBJECT_ID(N'[dbo].[TMP_IM_medext_44]') 
             AND name = 'discflag'
    )
    BEGIN
	    ALTER TABLE [dbo].[TMP_IM_medext_44] ADD discflag  VARCHAR (200) NULL;
END

GO

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2412.00', N'2501.00', NULL, GETDATE())

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

     -- V2501.00 - ACE OCE Updates
    DELETE FROM [dbo].[LUT_AceErrorNumber] where AceErrorNumber = '003'
    DELETE FROM [dbo].[LUT_AceErrorNumber] where AceErrorNumber = '008'
    DELETE FROM [dbo].[LUT_AceErrorNumber] where AceErrorNumber = '094'
    DELETE FROM [dbo].[LUT_AceErrorNumber] where AceErrorNumber = '103'
    UPDATE [dbo].[LUT_AceErrorNumber] SET [AceErrorDescription] = N'Claim with pass through device or device with payment limitation lacks required procedure (RTP)' WHERE [AceErrorNumber] = N'098'
    INSERT [dbo].[LUT_AceErrorNumber] ([AceErrorNumber], [AceErrorDescription], [ErrorDispositionLevel], [Enabled], [InsertedTS]) VALUES (N'136', N'Service provided prior to ACIP approval date (LIR)', NULL, 1, CAST(N'2025-01-09 00:00:00.000' AS DateTime))

    -- V2501.00 - RHC Pricer: Intensive Outpatient Program Field Updates
    DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4375
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [VariableDescr]=N'The rate used to reimburse Intensive Outpatient Program (IOP) services when 3 or less IOP services are on a claim.', [LabelOnUI]=N'IOP Rate (3 services):$', [DefaultValue]=N'269.19', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4374
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4461, 93, N'C.7', N'iop_rate2', N'The rate used to reimburse Intensive Outpatient Program (IOP) services when 4 or more IOP services are on a claim.', N'DECIMAL', 8, 2, N'9(8)v9(2)', NULL, N'IOP Rate (4 or more services):$', N'408.55', NULL, 10, 136, 0, NULL, NULL, 0, 99999999.99, NULL, 3, 1, '20250109 00:00:00.000', NULL, '20250101', '99991231', NULL)
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4462, 93, N'', N'filler1', N'', N'FILLER', 292, 0, N'X(292)', NULL, N'FILLER:', N'', NULL, 292, 146, 0, NULL, NULL, NULL, NULL, NULL, 4, 1, '20250109 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3877, 7005, 4461)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3878, 7006, 4461)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7005, 93, 6791, N'TextBlock', N'Text', NULL, NULL, NULL, 13, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7006, 93, 6791, N'TextBox', N'Text', NULL, NULL, NULL, 14, 1, '20250109 00:00:00.000', NULL)

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

    --V2501.00 - Medicaid APG Pro Pricer: Updating Terminated Procedure Discounting Logic
    DELETE FROM [dbo].[LUT_PricerTypeVariable] WHERE [LUTPTVID]=4377
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [StringLength]=2, [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=3284
    INSERT INTO [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4463, 86, N'F.10', N'discflag', N'Specifies multiple discounting option:

00 = apply all applicable discounts
01 = only apply terminated discounting even if line is eligible for both terminated discount and bilateral adjustment
02 = only apply terminated discount even if line is eligible for both terminated and MSPD or repeat ancillary discounts
03 = only apply terminated discount even if line is eligible for terminated discount,  MSPD or repeat ancillary discounts and bilateral adjustment', N'TEXT', 2, 0, N'9(2)', NULL, N'Discounting Flag:', N'00', NULL, 2, 92, 1, NULL, NULL, 0, 99, NULL, 3, 1, '20250109 00:00:00.000', NULL, '00010101', '99991231', NULL)
    INSERT [dbo].[LUT_PricerTypeVariable] ([LUTPTVID], [LUTPTID], [SEQ], [VariableName], [VariableDescr], [VariableType], [VariableLeftCount], [VariableRightCount], [VariableFormat], [VariableEventHandler], [LabelOnUI], [DefaultValue], [CalculationFormula], [VariableSizeInC], [StartPositionInC], [IsMedext], [IsRequired], [RegexExpression], [RangeMin], [RangeMax], [StringLength], [VariableUsageBinary], [Enabled], [InsertedTS], [ModifiedTS], [DisplayStartDate], [DisplayEndDate], [CalculationJs]) VALUES (4464, 86, NULL, N'filler2', NULL, N'FILLER', 414, 0, N'X(414)', NULL, N'Filler:', NULL, NULL, 414, 94, 1, NULL, NULL, NULL, NULL, NULL, 4, 1, '20250109 00:00:00.000', NULL, CAST(N'0001-01-01' AS Date), CAST(N'9999-12-31' AS Date), NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7007, 86, 6006, N'TextBlock', N'Text', NULL, NULL, NULL, 19, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7008, 86, 6006, N'ComboBox', N'SelectedValue', NULL, NULL, NULL, 20, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7009, 86, 7008, N'ComboBoxItem', N'Content', N'00 = apply all applicable discounts', NULL, NULL, 1, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7010, 86, 7008, N'ComboBoxItem', N'Content', N'01 = only apply terminated discounting even if line is eligible for both terminated discount and bilateral adjustment', NULL, NULL, 2, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7011, 86, 7008, N'ComboBoxItem', N'Content', N'02 = only apply terminated discount even if line is eligible for both terminated and MSPD or repeat ancillary discounts', NULL, NULL, 3, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTL] ([TMLPPTID], [LUTPTID], [ParentTMLPPTID], [FieldType], [FieldTextName], [FieldTextValue], [SectionColumns], [DisplayType], [DisplayOrder], [Enabled], [InsertedDS], [ModifiedTS]) VALUES (7012, 86, 7008, N'ComboBoxItem', N'Content', N'03 = only apply terminated discount even if line is eligible for terminated discount,  MSPD or repeat ancillary discounts and bilateral adjustment', NULL, NULL, 4, 1, '20250109 00:00:00.000', NULL)
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (519, 7009, N'Tag', N'00', 1, '20250109 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (520, 7010, N'Tag', N'01', 1, '20250109 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (521, 7011, N'Tag', N'02', 1, '20250109 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLAttr] ([TMLPPTAID], [TMLPPTID], [AttributeName], [AttributeValue], [Enabled], [InsertedDS], [DisplayStartDate], [DisplayEndDate]) VALUES (522, 7012, N'Tag', N'03', 1, '20250109 00:00:00.000', '00010101', '99991231')
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3879, 7007, 4463)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3880, 7008, 4463)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3881, 7009, 4463)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3882, 7010, 4463)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3883, 7011, 4463)
    INSERT INTO [dbo].[TML_PricerPageTLMap] ([Id], [TMLPPTID], [LUTPTVID]) VALUES (3884, 7012, 4463)

    INSERT [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (237, N'0162', N'Determine Multiple Discounting Rules', 1, 86)

    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = [DisplayOrder] + 1 WHERE [LUTSID] = 25 AND [DisplayOrder] >= 4;
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = [DisplayOrder] + 1 WHERE [LUTSID] = 41 AND [DisplayOrder] >= 4;
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = [DisplayOrder] + 1 WHERE [LUTSID] = 53 AND [DisplayOrder] >= 4;

    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (25, 237, 4, CAST(N'2025-01-09T00:00:00.000' AS DateTime));
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (41, 237, 4, CAST(N'2025-01-09T00:00:00.000' AS DateTime));
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (53, 237, 4, CAST(N'2025-01-09T00:00:00.000' AS DateTime));

    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (237, 4463)

    -- V2501.00 - Enhanced New York Medicaid APG Pricer: End Date Update
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [RangeMax] = 1, [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4185
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [ModifiedTS]='20250109 00:00:00.000', [DisplayEndDate]='20221231' WHERE [LUTPTVID]=4027
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.12', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4028
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.13', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4029
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.14', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4030
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.15', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4031
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.16', [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4032
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.17', [RangeMax] = 1, [ModifiedTS]='20250109 00:00:00.000' WHERE [LUTPTVID]=4033
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.18', [ModifiedTS]='20250109 00:00:00.000', [DisplayEndDate]='20240331' WHERE [LUTPTVID]=4322
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.19', [ModifiedTS]='20250109 00:00:00.000', [DisplayEndDate]='20240331' WHERE [LUTPTVID]=4323
    UPDATE [dbo].[LUT_PricerTypeVariable] SET [SEQ]=N'G.20', [ModifiedTS]='20250109 00:00:00.000', [DisplayEndDate]='20240331' WHERE [LUTPTVID]=4324

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