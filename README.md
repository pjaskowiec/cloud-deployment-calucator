# cloud-deployment-calucator

Na podstawie badań w grupie 10 użytkowników wewnątrz wrocławskiej korporacji, średni rozkład operacji typu CRUD wykonywanych podczas obsługi aplikacji prezentował się tak:
- Create: 5%
- Search: 15%
- Read: 70%
- Update: 5% 
- Delete: 5%

Dla serverless należy ocenić konieczną ilość pamięci dla funkcji Lamdowych, żeby były one efektywne, a następnie zmierzyć czas na podstawie wywołań, który potrzebują na  
Średnia wielkość fetcha - data transfer out
https://github.com/epsagon/lambda-memory-performance-benchmark

<!-- Original memory size: 128
Setting memory size: 128MB
Warming Lambda
Result: 7.396000000000001
--------------------
Setting memory size: 256MB
Warming Lambda
Result: 7.702000000000001
--------------------
Setting memory size: 512MB
Warming Lambda
Result: 7.612
--------------------
Setting memory size: 1024MB
Warming Lambda
Result: 7.641999999999999
--------------------
Setting memory size: 1536MB
Warming Lambda
Result: 7.619999999999999
--------------------
Setting memory size: 2048MB
Warming Lambda
Result: 7.409999999999999
--------------------
Setting memory size: 2560MB
Warming Lambda
Result: 7.747999999999999
--------------------
Setting memory size: 3008MB
Warming Lambda
Result: 7.337999999999999 -->

**CloudWatch Logs Insights**
type: add
region: eu-north-1    
log-group-names: /aws/lambda/pj-mgr-student    
start-time: 2024-04-06T12:03:51.357Z    
end-time: 2024-04-06T12:03:57.973Z    
query-string:
  ```
  filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(30m)
  ```
---
| bin(30m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 12:00:00.000 | 125.2236 | 141.77 | 115.44 |
---

**CloudWatch Logs Insights**    
region: eu-north-1
type: get_all_students    
log-group-names: /aws/lambda/pj-mgr-student    
start-time: -3600s    
end-time: 0s    
query-string:
  ```
    filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(30m)
  ```
---
| bin(30m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 12:00:00.000 | 344.2032 | 700.12 | 307.8 |
---
**CloudWatch Logs Insights**    
region: eu-north-1    
log-group-names: /aws/lambda/pj-mgr-student    
type: get_all_students - limit 10 (pagination)    
start-time: -3600s    
end-time: 0s    
query-string:
  ```
  filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(25m)
  ```
---
| bin(25m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 12:25:00.000 | 7.1847 | 95.41 | 5.84 |
---

**CloudWatch Logs Insights**
type: update
region: eu-north-1    
log-group-names: /aws/lambda/pj-mgr-student    
start-time: -3600s    
end-time: 0s    
query-string:
  ```
    filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(25m)
  ```
---
| bin(25m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 13:00:00.000 | 13.5427 | 66.78 | 11.62 |
| 2024-04-06 12:50:00.000 | 13.622 | 25.41 | 11.77 |
---
**CloudWatch Logs Insights**
type: search
region: eu-north-1    
log-group-names: /aws/lambda/pj-mgr-student    
start-time: -3600s    
end-time: 0s    
query-string:
  ```
  
    filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(25m)

  ```
---
| bin(25m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 13:00:00.000 | 395.7469 | 696.88 | 351.8 |
---
**CloudWatch Logs Insights**
type: delete 
region: eu-north-1    
log-group-names: /aws/lambda/pj-mgr-student    
start-time: -3600s    
end-time: 0s    
query-string:
  ```
      filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(25m)
  ```
---
| bin(25m) | avg(@duration) | max(@duration) | min(@duration) |
| --- | --- | --- | --- |
| 2024-04-06 13:25:00.000 | 9.6585 | 84.63 | 7.5 |
---