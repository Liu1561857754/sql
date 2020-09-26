 

 
这个目标库  在碰4G  双卡  和沉默5天以上的



目标客户：
1.4G终端零流量
2.12季度主卡+7月本地双卡
3.沉默5天以上
以上三类客户取并集

关联temp_wl_haoma目标库，再取用户正常在用且插卡，无流量超套，
剔除黑名单，副卡，座机，互斥
承诺在网送流量



drop table temp_yymbk_0821_1;
create table temp_yymbk_0821_1
(
  user_id bigint,
  product_no varchar(11)
)
row format delimited fields terminated by ',' stored as textfile;

insert into table temp_yymbk_0821_1
select distinct a.user_id,a.product_no
from 
(/*一、二季度季拍*/
	--季度拍照新口径异网主卡
	select a.user_id,a.product_no
	from
	(
		select user_id,product_no from temp_user_gaoweinew_mm_201903 where flag = 1
		union all
		select user_id,product_no from temp_user_gaoweinew_mm_201906 where flag = 1
	)a
	union all
	--集团7月份均为异网双卡
	select b.user_id,b.product_no 
	from
	(
		select user_id 	from default.dw_bass_yiwang_double_card_mm_yyyymm where month_id = '201907'
	) a
	inner join default.DW_ZZQS_USER_CONN_QIANYUE_DT_YYYYMMDD b on a.user_id =b.user_id and b.day_id = '20190819'
	union all
	---8月本地（主卡+卡槽切换） 加上FLAG是主卡，不加是双卡
	select b.user_id,b.product_no
	from (select product_no from default.DW_ZZQS_DM_DOUBLE_CARD_INFO_DETAIL_DT_YYYYMMDD 
		where  day_id = '20190731') a
	inner join default.DW_ZZQS_USER_CONN_QIANYUE_DT_YYYYMMDD b on a.product_no =b.product_no
	where b.day_id = '20190819'
	union all
	select user_id,product_no from temp_ldp_4gzhgj_user_201907
	union all
	select user_id,product_no from HLW_DW_WTX_DAY_NUM_DT_YYYYMMDD where day_id = '20190818' and (is_wtx_05_10=1 or is_wtx_10_30=1 or is_wtx_30=1)
	
	)a
inner join temp_wl_haoma a1 on a.product_no = a1.product_no
;

select count(1) from temp_yymbk_0821_1 ;





drop table temp_yymbk_0821_2;
create table temp_yymbk_0821_2
(
user_id bigint,
product_no varchar(11)
)
row format delimited fields terminated by ',' stored as textfile;

insert into table temp_yymbk_0821_2
select distinct a.user_id,a.product_no
from temp_yymbk_0821_1 a
inner join (
			select user_id,product_no,plan_name from default.dw_zzqs_user_conn_qianyue_dt_yyyymmdd where day_id='20190819' 
				   and IS_WLK=0 and USER_STATUS='正常在用' and open_date<='2019-05-01'  and age>=16 and age<=65
				   group by user_id,product_no,plan_name
			)b on a.user_id=b.user_id    /*物联网卡、正常在用、入网三个月、年龄在18-60*/
inner join (select  product_no from HLW_DWD_TEMP_USER_TRACK_USER_YYYYMMDD where day_id ='20190819')x1 on b.product_no=x1.product_no /*插卡*/
left join (select user_id from default.DW_ZZQS_BLACKLIST_DS_yyyymmdd where day_id ='20190819' and (STYLE1='黑名单' or STYLE2='公务机'or STYLE4='党政军')) c on a.user_id = c.user_id 
left join (select a.user_id
			 from default.DW_USER_USEAGE_PRIVILEGE_DT_yyyymmdd a
			  where  a.day_id = '20190819'
			 and a.PRIVSETID in ('gl_qgbxlfk','gl_bxlfk','gl_gprs_mking_n','gl_llsxkn','gl_llsxk','gl_wnsxk','gl_wnsxkn','pip_main_rzkxck','pip_main_xckhjy','pmp_rzkxck','gl_4g_gprsllrzk',
			  'gl_tcsrzk_2017n','pip_gprzkyb_lltc','gl_tcsrzk_2017n_1','gl_4g_gprsllrzk','gl_tcsrzk_2017n_2','pip_main_rzkxck',
			  'gl_cnsbxl30_3','gl_cnsbxl30_6','gl_cnsbxl30_12k','gl_cnsbxl50_3','gl_cnsbxl50_6','gl_cnsbxl50_12',
			 'gl_cnsbxl70_3','gl_cnsbxl70_6','gl_cnsbxl70_12','gl_cnxf_sll1','gl_cnxf_sll2','gl_cnxf_sll3','gl_cntc_sll',
			 'gl_qyxf_sll1','gl_qyxf_sll2','gl_qyxf_sll3','gl_qyxf_sll4','gl_qyxf_syy1','gl_qyxf_syy2','gl_qyxf_syy3','gl_qyxf_syy4'
			) and (enddate>'2019-08-19' or enddate is null) ) d on a.user_id = d.user_id   -----剔除副卡，承诺类
left join (select a.user_id 
			 from default.DW_USER_USEAGE_PRIVILEGE_DT_yyyymmdd a,
			 (
			 select code from temp_zj_kr_code
			 union all
			 select code from temp_ldp_leiji_huchi_code2  ---存300送300
			 union all
			 select code from temp_zj_yqt_code   ---硬签约
			 union all
			 select code from temp_zj_rqy_code   ---软签约
			 ) b
			 where a.PRIVSETID=b.code
			 and a.day_id = '20190819'
			 and (enddate>'2019-08-19' or enddate is null)) x on a.user_id = x.user_id   ----互斥
left join temp_zj_fyxtc g on b.plan_name = g.plan_name    ----座机及其他不可运营套餐
where g.plan_name is null
  and c.user_id is null 
  and d.user_id is null
  and x.user_id is null
  and substr(a.product_no,1,1) = '1'/*指定第一个位置的号码是1*/
;

select count(1) from temp_yymbk_0821_2;



 

drop table temp_yymbk_0821_3;
create table temp_yymbk_0821_3
(
user_id bigint,
product_no varchar(11),
is_ct int
)
row format delimited fields terminated by ',' stored as textfile;

insert into table temp_yymbk_0821_3
select a.user_id,a.product_no,case when c.ll_ct_arpu>0 then 1 else 0 end is_ct
from temp_yymbk_0821_2 a 
left join default.dw_user_ct_arpu_mou_dt_yyyymmdd c on a.user_id = c.user_id and c.day_id = '20190731'
;

select is_ct,count(1) from temp_yymbk_0821_3 group by is_ct; 

	
	
	
	
	