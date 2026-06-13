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

    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (240, 4457)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (243, 4452)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (244, 4478)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (245, 4477)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (245, 4476)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (246, 4361)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (248, 4479)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (250, 4365)
    INSERT [dbo].[LUT_PricerTypeAPRPro_ProcedureVariable] ([LUTPID], [LUTPTVID]) VALUES (253, 4480)

