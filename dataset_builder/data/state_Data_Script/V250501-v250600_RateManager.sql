USE [RateManager]
GO

/* This Script is used for HTML5 UPGRADE from v250501 to V250600.
Run this script on [RateManager] v250501 to upgrade it to [RateManager] V250600.
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
SET @FromDVersion = '2505.01'; -- the DVersion in the database
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

BEGIN TRANSACTION
  BEGIN TRY

    -- Updating database version only for Installer changes 
    INSERT INTO [dbo].[ADM_SystemVersion] ([AVersion], [DVersion], [PVersion], [InsertedTS])
      VALUES (N'2505.01', N'2506.00', NULL, GETDATE())

	UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [LUTPID] = 22 WHERE [LUTSID] = 72 AND [LUTPID] = 73 AND [DisplayOrder] = 20 
	UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [LUTPID] = 73 WHERE [LUTSID] = 72 AND [LUTPID] = 22 AND [DisplayOrder] = 21
    
    --US1407481-V2506.00 - Procedure arrays update for APR Pro (state Ohio)
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (51, 87, 6, CAST(N'2025-06-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (51, 120, 7, CAST(N'2025-06-05T00:00:00.000' AS DateTime))
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 8 WHERE [LUTSID] = 51 AND [LUTPID] = 171
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 9 WHERE [LUTSID] = 51 AND [LUTPID] = 156
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 10 WHERE [LUTSID] = 51 AND [LUTPID] = 170
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 11 WHERE [LUTSID] = 51 AND [LUTPID] = 79
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 12 WHERE [LUTSID] = 51 AND [LUTPID] = 169
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 13 WHERE [LUTSID] = 51 AND [LUTPID] = 12
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 14 WHERE [LUTSID] = 51 AND [LUTPID] = 167
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 15 WHERE [LUTSID] = 51 AND [LUTPID] = 166
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 16 WHERE [LUTSID] = 51 AND [LUTPID] = 105
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 17 WHERE [LUTSID] = 51 AND [LUTPID] = 168
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 18 WHERE [LUTSID] = 51 AND [LUTPID] = 50
    
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (66, 87, 6, CAST(N'2025-06-05T00:00:00.000' AS DateTime))
    INSERT [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (66, 120, 7, CAST(N'2025-06-05T00:00:00.000' AS DateTime))
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 8 WHERE [LUTSID] = 66 AND [LUTPID] = 171
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 9 WHERE [LUTSID] = 66 AND [LUTPID] = 156
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 10 WHERE [LUTSID] = 66 AND [LUTPID] = 170
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 11 WHERE [LUTSID] = 66 AND [LUTPID] = 79
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 12 WHERE [LUTSID] = 66 AND [LUTPID] = 169
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 13 WHERE [LUTSID] = 66 AND [LUTPID] = 12
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 14 WHERE [LUTSID] = 66 AND [LUTPID] = 167
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 15 WHERE [LUTSID] = 66 AND [LUTPID] = 166
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 16 WHERE [LUTSID] = 66 AND [LUTPID] = 105
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 17 WHERE [LUTSID] = 66 AND [LUTPID] = 168
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 18 WHERE [LUTSID] = 66 AND [LUTPID] = 205
    UPDATE [dbo].[LUT_PricerTypeAPRPro_StateProcedure] SET [DisplayOrder] = 19 WHERE [LUTSID] = 66 AND [LUTPID] = 50

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
