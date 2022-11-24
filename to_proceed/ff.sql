  1    select /*+ ordered */
  2        e.owner ||'.'|| e.segment_name  segment_name,
  3        x.dbablk - e.block_id + 1  block#,
  4        x.tch
  5      from
  6        ( select hladdr, tch , file#, dbablk  from
  7             ( select hladdr, sum(tch) tch, file#, dbablk from x$bh group by hladdr, file#, dbablk )
  8            where rownum < 30
  9       ) x,
 10       (select addr from v$latch_children  where name = 'cache buffers chains' ) l,
 11       (
 12     select u.name owner , o.name segment_name, o.subname partition_name, so.object_type segment_type
 13        , ts.name tablespace_name, s.file# file_id, so.header_block block_id,
 14         dbms_space_admin.segment_number_blocks(ts.ts#, s.file#, s.block#, s.type#, s.cachehint, NVL(s.spare1,0),
 15         o.dataobj#, s.blocks)*ts.blocksize bytes,
 16         dbms_space_admin.segment_number_blocks(ts.ts#, s.file#, s.block#, s.type#, s.cachehint, NVL(s.spare1,0),
 17         o.dataobj#, s.blocks) blocks,
 18         dbms_space_admin.segment_number_extents(ts.ts#, s.file#, s.block#, s.type#, s.cachehint, NVL(s.spare1,0),
 19         o.dataobj#, s.extents) extents,
 20         s.iniexts * ts.blocksize initial_extents,
 21         decode(bitand(ts.flags, 3), 1, to_number(NULL), s.extsize * ts.blocksize) next_extent,
 22         s.minexts, s.maxexts,
 23         decode(bitand(ts.flags, 3), 1, to_number(NULL),s.extpct) pct_increase,
 24         decode(s.cachehint, 0, 'DEFAULT', 1, 'KEEP', 2, 'RECYCLE', NULL) buffer_pool
 25     from sys.user$ u, sys.obj$ o, sys.ts$ ts,
 26          sys.sys_objects so, sys.seg$ s, sys.file$ f
 27     where s.file# = so.header_file
 28         and s.block# = so.header_block
 29         and s.ts# = so.ts_number
 30         and s.ts# = ts.ts# and o.obj# = so.object_id and o.owner# = u.user# and s.type# = so.segment_type_id
 31         and o.type# = so.object_type_id
 32         and s.ts# = f.ts#
 33         and s.file# = f.relfile#
 34    ) e
 35     where
 36       x.hladdr  = l.addr and
 37       e.file_id = x.file# and
 38       x.dbablk between e.block_id and
 39       e.block_id + e.blocks -1
 40*     order by x.tch desc

