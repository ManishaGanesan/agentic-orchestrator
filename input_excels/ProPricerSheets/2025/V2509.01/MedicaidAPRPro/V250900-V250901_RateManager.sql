    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=54 AND [LUTPID]=48 AND [DisplayOrder]=20
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=54 AND [LUTPID]=50 AND [DisplayOrder]=21
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=54 AND [LUTPID]=91 AND [DisplayOrder]=18
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=54 AND [LUTPID]=92 AND [DisplayOrder]=19
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=54 AND [LUTPID]=107 AND [DisplayOrder]=17
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=48 AND [DisplayOrder]=21
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=50 AND [DisplayOrder]=22
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=91 AND [DisplayOrder]=18
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=92 AND [DisplayOrder]=19
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=107 AND [DisplayOrder]=17
    DELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID]=79 AND [LUTPID]=217 AND [DisplayOrder]=20

    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_State] ([LUTSID], [LUTPTID], [state_id], [StateName], [effdate], [DisplayOrder], [Enabled]) VALUES (81, 84, N'IN', N'Indiana', '20210701 00:00:00.000', 5, 1)

    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (258, N'0093', N'Provider Adjustment Factor with Age Requirement, Outlier Only (1 + Adjustor)', 1, 84)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_Procedure] ([LUTPID], [PCode], [PDescription], [Enabled], [LUTPTID]) VALUES (259, N'0094', N'Provider Adjustment Factor with Age Requirement, Inlier Only (1 + Adjustor)', 1, 84)

    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (258, 3154)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (258, 3352)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (259, 3154)
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (259, 3352)

    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 48, 21, '20220804 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 50, 22, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 91, 19, '20220804 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 92, 20, '20220804 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 258, 18, '20220804 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (54, 259, 17, '20220804 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 48, 22, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 50, 23, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 91, 19, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 92, 20, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 217, 21, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 258, 18, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (79, 259, 17, '20250501 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 1, 3, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 2, 2, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 3, 1, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 4, 10, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 8, 9, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 10, 15, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 12, 16, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 14, 11, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 48, 20, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 50, 21, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 77, 6, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 78, 7, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 79, 13, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 88, 5, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 89, 8, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 90, 14, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 91, 18, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 92, 19, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 96, 12, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 102, 4, '20250918 00:00:00.000')
    INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([LUTSID], [LUTPID], [DisplayOrder], [InsertedTS]) VALUES (81, 259, 17, '20250918 00:00:00.000')
