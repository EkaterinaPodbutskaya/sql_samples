SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

ALTER procedure [marking].[p_prolong]
as
begin

--��� �������� 
drop table if exists #t;
select distinct cID, agentId, bID, tarif_name, Since, UpTo
  into #t
  from dbo.RetailPack
   and is_real     = 1;

   
--��� ���� 
drop table if exists #fas;
select distinct c.inn, isnull(c.kpp, '') kpp, b.Num, t.tarif_name, t.Since, t.UpTo, b.BDate, 
				case
					when t.tarif_name like '�������%' then '�������'
					when t.tarif_name like '������ %' then '������'
				end tar
  into #fas
  from #t              t
  join dbo.Clients c on c.cID = t.cID
  join dbo.Bill  b on b.bID = t.bID;

		

--������������ ������������������ ��������
drop table if exists #new_prolong;
with cte
  as (select *, row_number() over (partition by inn, tar order by Since) s
        from #fas)
select     c.inn,
           c.kpp,
           c.Num,
           c.tarif_name,
           c.Since,
           c.UpTo ,
           iif(t.s is not null and datediff(dd, c.UpTo, t.Since) < 180, 1, 0) prolong,
           datediff(dd, c.UpTo, t.Since)                                      defer,
           t.Num                                                              [���������� ����],
		   t.tarif_name														  [����� ���������],
           t.BDate                                                            [���� ����������� ����� �� ���������],
           t.Since                                                            [���� ������ ��������-���������],
		   c.tar
  into      #new_prolong
  from      cte c
  left join cte t on t.inn = c.inn
                 and t.s   = c.s + 1 and t.tar like c.tar


drop table if exists #new_5;
select inn,
       kpp,
       Num,
       tarif_name,
       Since ,
       UpTo	 ,
       prolong,
       defer,
       iif(prolong = 0, null, [���������� ����])                     [���������� ����],
	   iif([����� ���������] is null, '', [����� ���������])		 [����� ���������],
       iif(prolong = 0, null, [���� ����������� ����� �� ���������]) [���� ����������� ����� �� ���������],
       iif(prolong = 0, null, [���� ������ ��������-���������])      [���� ������ ��������-���������],
	   tar
  into #new_5
  from #new_prolong
 order by defer desc;


--���-�� � ������ �� ������� ������ � ����������� �������� �����
--������� ���������� �������
update product.mark.all_revenue
   set revenueT = '���������'
 where num in ( select r.num
                  from product.mark.all_revenue r
                  join #new_5              n on n.[���������� ����] = r.num
                 where r.revenueT = '�����������');


--������ �� ������ �� �����������
drop table if exists  #new_6;
select distinct n.inn, 
                first_value(Allo.RejectReason) over (partition by n.inn order by Allo.rejectdate desc)RejectReason
into #new_6
  from #new_5               n
  join CRM_DB.dbo.AllOffer Allo on Allo.Inn   = n.inn
                                and CrmProduct = '...'
                                and Allo.RejectReason is not null
 where prolong = 0;


 --��������
drop table if exists #new_8;
select distinct year(dateadd(dd, 1, UpTo)) [��� ���������], month(dateadd(dd, 1, UpTo)) [����� ���������], n.*, ifi.stts, w.RejectReason, getdate() date_load
into #new_8
  from #new_5 n
  left join #new_6 w on w.inn=n.inn
  left join dbo.fik ifi on ifi.inn=n.inn
 order by year(dateadd(dd, 1, UpTo)), month(dateadd(dd, 1, UpTo));


--������������� ���� ���������� �� ��������� � ��������
drop table if exists #inncom;
select distinct allo.inn,  case
								when left(a.Description, charindex('��� �������:',a.Description) +1) like'%��������%' then '�������������' 
								when left(a.Description, charindex('��� �������:',a.Description) +1) like'%���%'	  then '�������'
								when left(a.Description, charindex('��� �������:',a.Description) +1) like'%����%'	  then '�������'
								when left(a.Description, charindex('��� �������:',a.Description) +1) like'%������%'	  then '������'
						    end role_mkvk
 into #inncom
	from  CRM_DB.dbo.AllOffer               Allo 
	join [CRM_DB].[dbo].[Active] a on a.id=allo.ActivityId
	where (left(a.Description, charindex('��� �������:',a.Description) +1) like'%��������%' 			
		or left(a.Description, charindex('��� �������:',a.Description) +1) like'%���%'
		or left(a.Description, charindex('��� �������:',a.Description) +1) like'%����%'	   
		or left(a.Description, charindex('��� �������:',a.Description) +1) like'%������%')
		and inn in (select inn from #new_8);


drop table if exists #role_s;
select inn, string_agg(role_mkvk, '; ') role_mkvk
  into #role_s
  from #inncom
 group by inn;


 --������ �� �������
 drop table if exists #summa
 select num, cbc.TariffName, sum(Payed) Payed 
 into #summa
 from dbo.bill_contents cbc
 where cbc.bID in (select bID from #t)
 GROUP BY cbc.Num, cbc.TariffName


-- ����� ��� ������
begin transaction;
truncate table product.mark.prolong;
insert into product.mark.prolong( [��� ���������]
												,[����� ���������]
												,[���	]
												,[���	]
												,[������������� ���� ]
												,[��]
												,[����	]
												,[����� �� �����] 
												,[��	]
												,[����� ��������]
												,[������ ��������	]
												,[��������� ��������]	
												,[������� ���������	]
												,[������� ����� �������� � ���������� ��������� � ����	]
												,[����� ���������]
												,[���������� ����]
												,[���� ����������� ����� �� ���������]
												,[������� ��� ����������� � ������ ����� �� ���������]
												,[���� ������ ��������-���������]
												,[������ �� ������	]
												,[������� ������ (���� ����)	]
												,date_load)
select distinct t.[��� ���������],
                t.[����� ���������],
                t.inn			,
                t.kpp			,
				isnull(a.role_mkvk, '') [������������� ���� ��],
				iif(s.segment = '�������������' or s.segment is null, isnull(w.fr, ''), s.segment) tg,
                t.Num			,
				m.Payed,
				cbc.code		,
                t.tarif_name	,
                t.Since			,
                t.UpTo			,
                t.prolong		,
                t.defer			,
				[����� ���������],
                t.[���������� ����],
                t.[���� ����������� ����� �� ���������],
				datediff(dd, t.[���� ����������� ����� �� ���������], r.PayDate)[������� ��� ����������� � ������ ����� �� ���������],
                t.[���� ������ ��������-���������],
                t.stts          ,
                t.RejectReason  ,
                t.date_load	
	from  #new_8 t
	join dbo.bill_contents cbc on cbc.num=t.num
	left join  product.mark.all_revenue r on r.num=t.[���������� ����]
	left join product.mark.segmentations s on s.inn  = t.inn
	left join product.mark.all_categories   w on w.inn  = t.inn
	left join #role_s a on a.inn=t.inn
	left join #sums m on m.num=t.num and t.tar = m.TariffName
	ORDER BY t.inn, t.tarif_name;

	commit transaction;

end;
GO

