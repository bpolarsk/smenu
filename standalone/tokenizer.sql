Tanel@Sol01> define separator=":"
Tanel@Sol01> define mystring="A:BCD::EFG:H:IJKL"
Tanel@Sol01>
Tanel@Sol01> SELECT
  2             LEVEL,
  3             REGEXP_REPLACE(
  4                     REGEXP_SUBSTR( '&mystring'||'&separator', '(.*?)&separator', 1, LEVEL )
  5                     , '&separator$'
  6                     , ''
  7             ) TOKEN
  8  FROM
  9     DUAL
 10  CONNECT BY
 11     REGEXP_INSTR( '&mystring'||'&separator', '(.*?)&separator', 1, LEVEL ) > 0
 12  ORDER BY
 13     LEVEL ASC
 14  /

LEVEL TOKEN
----- ----------
    1 A
    2 BCD
    3
    4 EFG
    5 H
    6 IJKL


