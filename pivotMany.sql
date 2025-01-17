USE [ERP_HOPLONG]
GO
/****** Object:  StoredProcedure [dbo].[Proc_GetPhanHoiKHCTKM_DOANH_SO]    Script Date: 12/11/2024 10:07:57 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- exec [Proc_GetPhanHoiKHCTKM_DOANH_SO] 'SALE014_HL', 'HOPLONG', '', 0
ALTER procedure [dbo].[Proc_GetPhanHoiKHCTKM_DOANH_SO] 
	@username VARCHAR(64),
	@macongty VARCHAR(64),
	@tukhoa nvarchar(255),
	@sotrang int
as
BEGIN
	SET NOCOUNT ON;

	---------------------------- declare temp table -------------------------

	create table #doanh_so_tham_gia(
		ID_CTKM int
		, [KEY] varchar(20)
		, MA_HANG varchar(20)
		, THANH_TIEN  decimal(28, 2)
	)

	
	create table #SL_SIT_CT_PO
    (
        SO_CHUNG_TU varchar(40)
      , MA_SO_PO varchar(40)
      , ID int
      , MA_HANG nvarchar(40)
      , SL_SIT decimal
    );

	create table #OLD_SO
    (
       MA_SO_PO varchar(40)
      , MA_HANG nvarchar(40)
      , SL_XUAT_CU int
    );


	declare @isAdmin bit  = (select IS_ADMIN from HT_NGUOI_DUNG WHERE USERNAME = @username)

 DECLARE @list_user_of_leader TABLE
			(
				USERNAME varchar(30) Primary key,
				TEN_NHAN_VIEN nvarchar(30)
			)
			-- get all sale of group
			INSERT INTO @list_user_of_leader
			SELECT distinct
				USERNAME, TEN_NHAN_VIEN
			FROM View_NhomSale
			WHERE (LEADER = @username 
					OR SUB = @username 
					or USERNAME = @username
			)
	--=================================

	---- c Hương xem all nhóm PNB
	--if(@username = 'SALE001_HL')
	--begin
	--	INSERT INTO @list_user_of_leader
	--	select distinct
	--		NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN 
	--	from NHOM_KINH_DOANH
	--	left join NHOM_KINH_DOANH_PHAN_QUYEN on NHOM_KINH_DOANH.MA_NHOM = NHOM_KINH_DOANH_PHAN_QUYEN.MA_NHOM
	--	left join @list_user_of_leader t on t.USERNAME = NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN
	--	where 
	--		ten_NHOM like '%PnB%' 
	--		and NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN != @username 
	--		and t.USERNAME is null
	--end
	---- c Nhung xem all nhóm OEM, EU
	--else if(@username = 'SALE009_HL')
	--begin
	--	INSERT INTO @list_user_of_leader
	--	select distinct
	--		NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN 
	--	from NHOM_KINH_DOANH
	--	left join NHOM_KINH_DOANH_PHAN_QUYEN on NHOM_KINH_DOANH.MA_NHOM = NHOM_KINH_DOANH_PHAN_QUYEN.MA_NHOM
	--	left join @list_user_of_leader t on t.USERNAME = NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN
	--	where 
	--		(ten_NHOM like '%OEM%' or ten_NHOM like '%EU%') 
	--		and NHOM_KINH_DOANH_PHAN_QUYEN.NHAN_VIEN != @username
	--		and t.USERNAME is null
	--end


	declare @All_KH int = (select count(distinct kh.MA_KHACH_HANG)
							from kh
							left join @list_user_of_leader t on t.USERNAME = kh.SALE_HIEN_THOI
							where kh.TRUC_THUOC = @macongty AND (@isAdmin = 1 or t.USERNAME is not null))
	-----------------------------------------------------------------------------------------		
	
	





	insert into #OLD_SO
		select DOANH_SO_XK_CTKM.MA_SO_PO
                 , DOANH_SO_XK_CTKM.MA_HANG
                 , case
                       when (count(DOANH_SO_XK_CTKM.SO_CHUNG_TU) > 1) then
                           sum(DOANH_SO_XK_CTKM.SO_LUONG)
                       else
                           0
                   end as SL_XUAT_CU
            from DOANH_SO_XK_CTKM
            where DOANH_SO_XK_CTKM.SL_CO_SAN > 0
            group by DOANH_SO_XK_CTKM.ID_CT_XK
                   , DOANH_SO_XK_CTKM.MA_SO_PO
                   , DOANH_SO_XK_CTKM.MA_HANG

    create clustered index idx_MA_SO_PO_MA_HANG on #OLD_SO (MA_SO_PO, MA_HANG)
	

	insert into #SL_SIT_CT_PO
    select 
           THIS_SO.SO_CHUNG_TU
         , THIS_SO.MA_SO_PO
         , THIS_SO.ID_CT_XK
         , THIS_SO.MA_HANG
         -- nếu SL SIT  - SL đã xuất các tháng trước - SL SO đã xuất tháng này>= 0 thì lấy SL đã xuất tháng này còn nếu không thì lấy (SL SIT  - SL đã xuất các tháng trước) (số âm thì tính  = 0)
         , case
               when THIS_SO.SL_SO = THIS_SO.SL_XUAT then
                   THIS_SO.SL_CO_SAN
               else
         (case
              when (SL_CO_SAN - coalesce(SL_XUAT_CU, 0)) - SL_XUAT >= 0 then
                  SL_XUAT
              when (SL_CO_SAN - coalesce(SL_XUAT_CU, 0)) <= 0
                   and SL_CO_SAN = SL_XUAT then
                  SL_XUAT
              when (SL_CO_SAN - coalesce(SL_XUAT_CU, 0)) <= 0
                   and SL_CO_SAN != SL_XUAT then
                  0
              else
         (SL_CO_SAN - coalesce(SL_XUAT_CU, 0))
          end
         )
           end as SL_SIT
    from DOANH_SO_XK_CTKM THIS_SO
        inner join #OLD_SO OLD_SO  on OLD_SO.MA_SO_PO = THIS_SO.MA_SO_PO
    where 
		THIS_SO.SL_CO_SAN > 0 
		and OLD_SO.MA_HANG = THIS_SO.MA_HANG

	create clustered index idx_ID on #SL_SIT_CT_PO (ID)

	insert into #doanh_so_tham_gia
		SELECT 
						DISTINCT COALESCE(DOANH_SO_XK_CTKM.ID_CTKM, 0) as ID_CTKM
						,'DOANH_SO_XK' as [KEY]
						, HH_DONG_SP.MA_HANG
						, DOANH_SO_XK_CTKM.SL_SO * case
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G1'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.GIA_BAN_1_THUC_TE then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G2'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.GIA_BAN_2_THUC_TE then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_GCanhTranh'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.GIA_BAN_3_THUC_TE then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G4'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.GIA_BAN_4_THUC_TE then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_GGiamThem'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.CK_GIAM_THEM_LEADER then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G6'
								and (DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_XK_CTKM.GIA_BAN_6_THUC_TE then
							   DOANH_SO_XK_CTKM.DON_GIA_BAO_DI_NET 
						   else
							   0 
						end THANH_TIEN
					FROM DOANH_SO_XK_CTKM
					left join @list_user_of_leader t on t.USERNAME = DOANH_SO_XK_CTKM.SALE_HIEN_THOI
					left join #SL_SIT_CT_PO SL_SIT_CT_PO with (NOLOCK) on SL_SIT_CT_PO.ID = DOANH_SO_XK_CTKM.ID_CT_XK
					left join WiseEnterprise.dbo.CTKM_DETAIL   ON CTKM_DETAIL.ID_CTKM = DOANH_SO_XK_CTKM.ID_CTKM  
					left join CSTM_KH_THAM_GIA on DOANH_SO_XK_CTKM.KHACH_HANG = CSTM_KH_THAM_GIA.MA_KHACH_HANG
					LEFT JOIN WiseEnterprise.dbo.CTKM_HANG_HOA_TG ON CTKM_HANG_HOA_TG.ID_CTKM = DOANH_SO_XK_CTKM.ID_CTKM
					LEFT JOIN WiseEnterprise.dbo.HH_DONG_SP ON HH_DONG_SP.MA_HANG = DOANH_SO_XK_CTKM.MA_HANG
					WHERE 
						(@isAdmin = 1 or t.USERNAME is not null)
						and 
						(
							(
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'HANG' AND DOANH_SO_XK_CTKM.MA_NHOM_HANG = CTKM_HANG_HOA_TG.MA_CHUAN
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'NHOM_HANG' AND DOANH_SO_XK_CTKM.MA_NHOM_HANG = CTKM_HANG_HOA_TG.MA_CHUAN
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA IN ('DONG_SAN_PHAM', 'GOI_DONG_SAN_PHAM') 
								AND HH_DONG_SP.MA_HANG IS NOT NULL 
								AND DOANH_SO_XK_CTKM.MA_HANG = HH_DONG_SP.MA_HANG
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'MA_HANG' AND DOANH_SO_XK_CTKM.MA_HANG = HH_DONG_SP.MA_HANG
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'GOI_MA_HANG' AND CTKM_HANG_HOA_TG.MA_CHUAN IS NOT NULL
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'GOI_HANG'
							)
						)
						and
						(
							(CHARINDEX('KSCSTM', DOANH_SO_XK_CTKM.MA_LOAI_KHACH) > 0 and CSTM_KH_THAM_GIA.MA_KHACH_HANG is not null)
							or (CHARINDEX('Normal', DOANH_SO_XK_CTKM.MA_LOAI_KHACH) > 0 and CSTM_KH_THAM_GIA.MA_KHACH_HANG is null)
							or 1 = 1
						)
				


	insert into #doanh_so_tham_gia
			SELECT 
						DISTINCT COALESCE(DOANH_SO_SO_CTKM.ID_CTKM, 0) as ID_CTKM
						,'DOANH_SO_SO' as [KEY]
						, HH_DONG_SP.MA_HANG
						, (case 
							when CTKM.LOAI_HANG_TINH_THUONG = 'SIT' then DOANH_SO_SO_CTKM.SL_CO_SAN 
							when CTKM.LOAI_HANG_TINH_THUONG = 'SIT' then DOANH_SO_SO_CTKM.SO_LUONG end )
						* 
						case
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G1'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.GIA_BAN_1_THUC_TE then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G2'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.GIA_BAN_2_THUC_TE then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_GCanhTranh'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.GIA_BAN_3_THUC_TE then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G4'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.GIA_BAN_4_THUC_TE then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_GGiamThem'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.CK_GIAM_THEM_LEADER then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   when ctkm_detail.LOAI_DON_GIA = 'GiaG_G6'
								and (DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET + 9) >= DOANH_SO_SO_CTKM.GIA_BAN_6_THUC_TE then
							   DOANH_SO_SO_CTKM.DON_GIA_BAO_DI_NET 
						   else
							   0 
						end THANH_TIEN
					FROM DOANH_SO_SO_CTKM
					left join @list_user_of_leader t on t.USERNAME = DOANH_SO_SO_CTKM.SALE_HIEN_THOI
					left join WiseEnterprise.dbo.CTKM   ON CTKM.ID_CTKM = DOANH_SO_SO_CTKM.ID_CTKM  
					left join WiseEnterprise.dbo.CTKM_DETAIL   ON CTKM_DETAIL.ID_CTKM = DOANH_SO_SO_CTKM.ID_CTKM  
					left join CSTM_KH_THAM_GIA on DOANH_SO_SO_CTKM.KHACH_HANG = CSTM_KH_THAM_GIA.MA_KHACH_HANG
					LEFT JOIN WiseEnterprise.dbo.CTKM_HANG_HOA_TG ON CTKM_HANG_HOA_TG.ID_CTKM = DOANH_SO_SO_CTKM.ID_CTKM
					LEFT JOIN WiseEnterprise.dbo.HH_DONG_SP ON HH_DONG_SP.MA_HANG = DOANH_SO_SO_CTKM.MA_HANG
					WHERE 
						(@isAdmin = 1 or t.USERNAME is not null)
						and 
						(
							(
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'HANG' AND DOANH_SO_SO_CTKM.MA_NHOM_HANG = CTKM_HANG_HOA_TG.MA_CHUAN
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'NHOM_HANG' AND DOANH_SO_SO_CTKM.MA_NHOM_HANG = CTKM_HANG_HOA_TG.MA_CHUAN
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA IN ('DONG_SAN_PHAM', 'GOI_DONG_SAN_PHAM') 
								AND HH_DONG_SP.MA_HANG IS NOT NULL 
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'MA_HANG' AND DOANH_SO_SO_CTKM.MA_HANG = HH_DONG_SP.MA_HANG
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'GOI_MA_HANG' AND CTKM_HANG_HOA_TG.MA_CHUAN IS NOT NULL
							)
							OR (
								CTKM_HANG_HOA_TG.LOAI_HANG_HOA = 'GOI_HANG'
							)
						)
						and
								(
									(DOANH_SO_SO_CTKM.MA_LOAI_KHACH LIKE '%KSCSTM%' AND CSTM_KH_THAM_GIA.MA_KHACH_HANG IS NOT NULL)
									OR (DOANH_SO_SO_CTKM.MA_LOAI_KHACH LIKE '%Normal%' AND CSTM_KH_THAM_GIA.MA_KHACH_HANG IS NULL)
									or 1 = 1
								)
		DECLARE 
			@columns1 VARCHAR(MAX) = '', 
			@columns2 VARCHAR(MAX) = '', 
			@sql     VARCHAR(MAX) = '';
		SELECT @columns1 = COALESCE(@columns1 + ', ', '') + 'ISNULL(' + QUOTENAME(ID_CTKM) + ', 0) AS ' + QUOTENAME(ID_CTKM)
		FROM (
			SELECT DISTINCT ID_CTKM
			FROM #doanh_so_tham_gia
		) AS distinct_values;

		SELECT @columns2 = @columns2 + QUOTENAME(ID_CTKM) + ', '
		FROM (
			SELECT DISTINCT ID_CTKM
			FROM #doanh_so_tham_gia
		) AS distinct_values;

		SET @columns1 = RIGHT(@columns1, LEN(@columns1) - 1);
		SET @columns2 = LEFT(@columns2, LEN(@columns2) - 1);


		SET @sql = '
			SELECT [KEY],' + @columns1 + ' 
			FROM (
				SELECT ID_CTKM, [KEY], THANH_TIEN
				FROM #doanh_so_tham_gia
			) x
			PIVOT (
				SUM(THANH_TIEN)
				FOR ID_CTKM IN (' + @columns2 + ')
			) p
		';


       

print @sql
print '============================================================'
-- execute the dynamic SQL
 execute (@sql);
	
END;
-- exec [Proc_GetPhanHoiKHCTKM_DOANH_SO] 'VinhLQ', 'HOPLONG', '', 1

