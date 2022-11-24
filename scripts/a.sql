col lo_r for 9999999999 head 'Logical|reads'
col phy_r for 9999999999 head 'Physical|reads'
col phy_w for 9999999999 head 'Physical|Writes'
col phy_r_d for 9999999999 head 'Physical|reads dir'
col phy_w_d for 9999999999 head 'Physical|writes dir'
col ss for 9999999999 head 'Segment|scan'
col mv head 'Total|hit' for 999999999999 justify c
col obj for a30 head 'Name'
col owner for a20 head 'Owner'
break on report on owner
set pages  66 lines 190
select owner, object_name obj, mv, lo_r,phy_r,phy_w,phy_r_d,phy_w_d,ss
   from (
select * from (
SELECT obj#, statistic_name, value,
       sum(value) OVER (partition by obj#, DATAOBJ#) mv
FROM v$segstat a
WHERE statistic_name IN
                    ( 'logical reads', 'physical reads', 'physical writes', 'physical reads direct', 'physical writes direct' ,'segment scans')
)
pivot 
  ( max(value )
  for statistic_name  in ('logical reads' as lo_r, 'physical reads' as phy_r, 'physical writes' as phy_w, 
                          'physical reads direct' as phy_r_d, 'physical writes direct' as phy_w_d, 'segment scans' as ss)
  )
order by phy_r desc
) a, all_objects b
where  a.obj# = b.object_id
 and rownum <=30
/
