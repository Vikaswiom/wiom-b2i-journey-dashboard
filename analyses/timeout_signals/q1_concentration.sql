-- Q1 Concentration of timeouts by technician and CSP; self-assigned vs separate technician.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, per AS (
  SELECT mon, 'technician' dim, executor_id::STRING id, COUNT(*) n, COUNT_IF(grp='timeout') nt FROM b GROUP BY 1,2,3
  UNION ALL SELECT mon, 'csp', csp_id::STRING, COUNT(*), COUNT_IF(grp='timeout') FROM b GROUP BY 1,2,3
), r AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY mon, dim ORDER BY nt DESC, n DESC) rk, SUM(nt) OVER (PARTITION BY mon, dim) tot_t, SUM(n) OVER (PARTITION BY mon, dim) tot_n FROM per)
SELECT mon, dim, 'A share of timeouts' sec, 'units with any timeout' k, COUNT_IF(nt>0) a, COUNT(*) b, NULL c FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'A share of timeouts', 'top 10 units: timeouts / all timeouts / their tasks', SUM(IFF(rk<=10,nt,0)), MAX(tot_t), SUM(IFF(rk<=10,n,0)) FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'A share of timeouts', 'top 20 units', SUM(IFF(rk<=20,nt,0)), MAX(tot_t), SUM(IFF(rk<=20,n,0)) FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'A share of timeouts', 'top 50 units', SUM(IFF(rk<=50,nt,0)), MAX(tot_t), SUM(IFF(rk<=50,n,0)) FROM r GROUP BY 1,2
UNION ALL SELECT mon, dim, 'B units by timeout rate (units with 10+ tasks): units / tasks / timeouts',
   CASE WHEN nt=0 THEN '1: 0%' WHEN nt/n<0.10 THEN '2: under 10%' WHEN nt/n<0.25 THEN '3: 10-25%' WHEN nt/n<0.50 THEN '4: 25-50%' ELSE '5: 50%+' END, COUNT(*), SUM(n), SUM(nt) FROM r WHERE n>=10 GROUP BY 1,2,4
UNION ALL SELECT mon, dim, 'C units by volume: units / tasks / timeouts',
   CASE WHEN n<3 THEN '1: 1-2 tasks' WHEN n<10 THEN '2: 3-9 tasks' WHEN n<30 THEN '3: 10-29 tasks' ELSE '4: 30+ tasks' END, COUNT(*), SUM(n), SUM(nt) FROM r GROUP BY 1,2,4
UNION ALL SELECT mon, 'self-assigned', 'D CSP assigned itself vs a technician: tasks / timeouts / on time', IFF(is_self_assigned,'CSP itself','separate technician'), COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time') FROM b GROUP BY 1,4
UNION ALL SELECT mon, 'tech changed', 'E technician assigned more than once: tasks / timeouts / on time', IFF(n_asg>1,'assigned 2+ times','assigned once'), COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time') FROM b GROUP BY 1,4
ORDER BY 1,2,3,4
