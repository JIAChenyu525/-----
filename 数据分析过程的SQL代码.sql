# 更改列名
ALTER TABLE customers_beauty_data
  CHANGE f1 user_id int,
  CHANGE f2 item_id int,
  CHANGE f3 behavior_type varchar(5),
  CHANGE f4 item_category int,
  CHANGE f5 date varchar(255),
  CHANGE f6 hour int,
  CHANGE f7 user_geohash varchar(255);
  
# 处理空值
SELECT * 
FROM 
customers_beauty_data
WHERE user_id IS NULL 
OR item_id IS NULL
OR behavior_type IS NULL
OR item_category IS NULL 
OR date IS NULL 
OR hour IS NULL 
OR user_geohash IS NULL;

# 处理重复值，有2000多条重复值
SELECT user_id, item_id, behavior_type, item_id, behavior_type, item_category, date, hour, user_geohash
FROM customers_beauty_data
GROUP BY user_id, item_id, behavior_type, item_id, behavior_type, item_category, date, hour, user_geohash
HAVING COUNT(*) > 1; 

# 删除重复值
CREATE TABLE temp_table as SELECT DISTINCT * FROM customers_beauty_data;
TRUNCATE TABLE customers_beauty_data;
INSERT INTO customers_beauty_data SELECT * FROM temp_table;
DROP TABLE temp_table;

# 用户pv,uv和浏览深度pv/uv，pv是浏览量，uv是浏览人数
CREATE TABLE ed_pv_uv
  (
  date char(10),
  PV INT(9),
  UV INT(9),
  PVUV DECIMAL(10,3)
  );
INSERT INTO ed_pv_uv
SELECT 
  date,
  COUNT(IF(behavior_type=1,1,NULL)) PV,
  COUNT(DISTINCT user_id) UV,
  ROUND(COUNT(IF(behavior_type=1,1,NULL)) / COUNT(DISTINCT user_id), 3) PVUV
FROM
  customers_beauty_data
GROUP BY
  date 
ORDER BY 
  date;
  
# 计算每时的浏览深度
CREATE TABLE hours_pv_uv
  (
  date char(10),
  pv_hours int(9),
  uv_hours int(9),
  pvuv_hours DECIMAL(10,3)
  );

INSERT INTO hours_pv_uv    
SELECT    
    `hour`,    
    count(IF(behavior_type=1,1,NULL)) pv_hours,    
    count(DISTINCT user_id) uv_hours,    
    round(count(IF(behavior_type=1,1,NULL)) /count(DISTINCT user_id),3) pvuv_hours    
FROM    
    customers_beauty_data    
GROUP BY    
    `hour`    
order by    
    `hour`;
    
# 分析用户购买行为，用户的购买平均次数以及复购率
CREATE TABLE buy_times
  (
  user_id varchar(25),
  times INT(10)
  );

INSERT INTO buy_times
SELECT 
  user_id,
  COUNT(user_id) times
FROM 
  customers_beauty_data
WHERE 
  behavior_type = 4
GROUP BY 
  user_id,
  user_geohash
ORDER BY 
  times DESC;
  
# 复购率 44%
SELECT    
    concat(round(count(sub.user_id)/count(*),2)*100,'%') ratio    
FROM    
(    
SELECT    
    user_id    
FROM    
    customers_beauty_data    
WHERE    
    behavior_type=4    
GROUP BY    
    user_id,    
    user_geohash    
HAVING    
    count(user_id) >=2)sub    
right JOIN    
    customers_beauty_data a on a.user_id=sub.user_id    
WHERE    
    a.behavior_type = 4;
    
# 用户留存,先计算次日留存率
CREATE TABLE df_retention_1    
    (    
    date VARCHAR(25),    
    retention_1 FLOAT    
    ); 


# 五日留存率
CREATE TABLE df_retention_5    
    (    
    date VARCHAR(25),    
    retention_5 FLOAT    
    );    

# 用户行为统计及其转化率
# 以日期和时间分组，分别统计不同日期和不同时间下，进行浏览、收藏、加入购物车、购买这四种行为的人数各有多少
CREATE TABLE df_users_count_date    
    (    
        date VARCHAR(25),    
        pv_date int(10),    
        fav_date int(10),    
        cart_date int(10),    
        buy_date int(10)    
    );
INSERT INTO df_users_count_date
SELECT 
    date,
    COUNT(IF(behavior_type=1,1,NULL)) pv_date,
    COUNT(IF(behavior_type=1,1,NULL)) fav_date,
    COUNT(IF(behavior_type=1,1,NULL)) cart_date,
    COUNT(IF(behavior_type=1,1,NULL)) buy_date
FROM 
    customers_beauty_data
GROUP BY
    date 
ORDER BY 
    date;
    
# 以时间分组
CREATE TABLE df_users_count_hour    
    (    
        `hour` int(9),    
        pv_hour int(10),    
        fav_hour int(10),    
        cart_hour int(10),    
        buy_hour int(10)    
    );    

INSERT INTO df_users_count_hour
SELECT 
    `hour`,
    COUNT(IF(behavior_type=1,1,NULL)) pv_hour,
    COUNT(IF(behavior_type=1,1,NULL)) fav_hour,
    COUNT(IF(behavior_type=1,1,NULL)) cart_hour,
    COUNT(IF(behavior_type=1,1,NULL)) buy_hour 
FROM 
    customers_beauty_data
GROUP BY 
    `hour`
ORDER BY 
    `hour`;
    
# 用户的各种行为有多少
CREATE VIEW customer_behavior_total AS 
SELECT 
  user_id,
  user_geohash,
  item_id,
  COUNT(IF(behavior_type=1,1,NULL)) AS PV,
  COUNT(IF(behavior_type=2,1,NULL)) AS FAV,
  COUNT(IF(behavior_type=3,1,NULL)) AS CART,
  COUNT(IF(behavior_type=4,1,NULL)) AS BUY
FROM 
  customers_beauty_data
GROUP BY 
  user_id,
  user_geohash,
  item_id;

# 有这种行为的记为1，没有进行过为0
CREATE VIEW customer_behavior_total_standard AS 
SELECT 
  user_id,
  user_geohash,
  item_id,
  IF(PV > 0,1,0) AS ifpv,
  IF(FAV > 0,1,0) AS iffav,
  IF(CART > 0,1,0) AS ifcart,
  IF(BUY > 0,1,0) AS ifbuy
FROM 
  customer_behavior_total
GROUP BY 
  user_id,
  user_geohash,
  item_id;
  
# 接着我们将四列合并
CREATE VIEW customers_path AS 
SELECT 
  user_id,
  user_geohash,
  item_id,
  CONCAT(ifpv,iffav,ifcart,ifbuy) AS path
FROM
  customer_behavior_total_standard;

# 我们现在开始筛选
CREATE TABLE df_customers_behavior
    (
    behavior VARCHAR(25),
    num  int(10)
    );

INSERT INTO df_customers_behavior
SELECT 
  '浏览',
  COUNT(*) num
FROM 
  customers_path
WHERE 
  path!='0001' OR path!='0010' OR path!='0100' OR path!='0101' OR path!='0110' OR path!='0011' OR path!='0111';
  
INSERT INTO df_customers_behavior
SELECT 
  '浏览后收藏加购',
  COUNT(*) num 
FROM 
  customers_path
WHERE 
  path='1010' OR path='1100' OR path='1110' OR path='1011' OR path='1101' OR path='1111';
  
INSERT INTO df_customers_behavior
SELECT 
  '浏览后收藏加购后购买',
  COUNT(*) num
FROM 
  customers_path
WHERE 
  path='1101' OR path='1011' OR path='1111';
  
# 购买用户的地区分布
CREATE TABLE df_customer_geohash_distribution
    (
    user_geohash  VARCHAR(25),
    NUM   INT(9)
    );
    
INSERT INTO df_customer_geohash_distribution
SELECT 
    user_geohash,
    COUNT(user_id) NUM 
FROM 
    customers_beauty_data
WHERE 
    behavior_type = 4
GROUP BY 
    user_geohash;
    
# 热门商品及种类统计
CREATE TABLE df_popular_item
    (
    item_id   INT(10),
    item_hot  INT(20)
    );
    
INSERT INTO df_popular_item
SELECT 
    item_id,
    COUNT(item_id) item_hot
FROM 
    customers_beauty_data
WHERE 
    behavior_type = 4
GROUP BY 
    item_id 
ORDER BY 
    item_hot DESC,
    item_id 
LIMIT 10;

CREATE TABLE df_popular_category
    (
    item_category  INT(10),
    category_hot  INT(20)
    );


INSERT INTO df_popular_category
SELECT 
    item_category,
    COUNT(item_category) category_hot
FROM 
    customers_beauty_data
WHERE 
    behavior_type = 4
GROUP BY 
    item_category
ORDER BY 
    category_hot DESC 
LIMIT 1;

# 统计各个商品种类被浏览、收藏、加入购物车、购买的次数，以此来看哪种类别商品需求大
CREATE TABLE df_category_count
    (
    item_category   int(10),
    pv   int(10),
    fav   int(10),
    cart  int(10),
    buy   int(10)
    );
    
INSERT INTO df_category_count    
SELECT    
    item_category,    
    COUNT(if(behavior_type=1,1,null)) pv,    
    count(if(behavior_type=2,1,null)) fav,    
    count(if(behavior_type=3,1,null)) cart,    
    count(if(behavior_type=4,1,null)) buy    
FROM    
    customers_beauty_data    
GROUP BY    
    item_category;