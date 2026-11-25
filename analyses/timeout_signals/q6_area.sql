-- Q6 Area concentration by zone, pin code and city.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, per AS (
  SELECT mon, 'zone' dim, zone_id::STRING id, COUNT(*) n, COUNT_IF(grp='timeout') nt FROM b GROUP BY 1,2,3
  UNION ALL SELECT mon, 'pincode', pincode, COUNT(*), COUNT_IF(grp='timeout') FROM b WHERE pincode IS NOT NULL GROUP BY 1,2,3
  UNION ALL SELECT mon, 'city', UPPER(TRIM(city)), COUNT(*), COUNT_IF(grp='timeout') FROM b GROUP BY 1,2,3
), r AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY mon, dim ORDER BY nt DESC, n DESC) rk, SUM(nt) OVER (PARTITION BY mon, dim) tot_t FROM per)
SELECT mon, dim, 'A share' sec, 'areas with any timeout / all areas' k, COUNT_IF(nt>0)::STRING a, COUNT(*)::STRING b, NULL c FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'A share', 'top 10 areas: timeouts / all timeouts / their tasks', SUM(IFF(rk<=10,nt,0))::STRING, MAX(tot_t)::STRING, SUM(IFF(rk<=10,n,0))::STRING FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'B areas by timeout rate (areas with 30+ tasks): areas / tasks / timeouts',
   CASE WHEN nt/n<0.05 THEN '1: under 5%' WHEN nt/n<0.10 THEN '2: 5-10%' WHEN nt/n<0.20 THEN '3: 10-20%' ELSE '4: 20%+' END, COUNT(*)::STRING, SUM(n)::STRING, SUM(nt)::STRING FROM r WHERE n>=30 GROUP BY 1,2,4
UNION ALL SELECT mon, dim, 'C top 12 by timeouts: id / tasks / timeouts', LPAD(rk,2,'0'), id, n::STRING, nt::STRING FROM r WHERE rk<=12 AND dim IN ('zone','city')
ORDER BY 1,2,3,4
