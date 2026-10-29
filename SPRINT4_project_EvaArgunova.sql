/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS total_users,
	   (SELECT COUNT(id)
	   FROM fantasy.users
	   WHERE payer = 1) AS payer_users,
	   ROUND((SELECT COUNT(id)
	   FROM fantasy.users
	   WHERE payer = 1)::numeric / COUNT(id), 2) AS payer_dolya
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race_id,
	   COUNT(id) AS total_users, -- общее кол-во пользователей
	   COUNT(CASE WHEN payer = 1 THEN 1 END) AS payer_users, -- кол-во платящих пользователей
	   ROUND(COUNT(CASE WHEN payer = 1 THEN 1 END)::numeric / COUNT(id), 2) AS payer_dolya -- доля платящих
FROM fantasy.users
GROUP BY race_id;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS total_transaction,
	   SUM(amount) AS sum_amount,
	   MAX(amount) AS max_amount,
	   MIN(amount) AS min_amount,
	   AVG(amount) AS avg_amount,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount,
	   STDDEV(amount) AS std_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(*) AS total_transaction, -- общее число покупок
	   COUNT(CASE WHEN amount = 0 THEN 1 END) AS total_anomaly, -- кол-во нулевых покупок
	   ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric / COUNT(*), 4) AS anomaly_dolya -- доля нулевых покупок
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:	  
WITH total AS (
    SELECT
        COUNT(*) AS total_transactions, -- общее кол-во продаж
        COUNT(DISTINCT id) AS total_users -- пользователи что-то купившие
    FROM fantasy.events
    WHERE amount > 0
)
SELECT
    i.game_items,
    COUNT(*) AS total_transactions_item, -- кол-во продаж текущего предмета
    ROUND(COUNT(*)::NUMERIC / (SELECT total_transactions FROM total), 4) AS item_dolya, -- доля продаж предмета
    ROUND(COUNT(DISTINCT e.id)::NUMERIC / (SELECT total_users FROM total), 4) AS user_dolya -- доля купившего предмет пользователя
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
WHERE e.amount > 0
GROUP BY i.game_items
ORDER BY total_transactions_item DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH total_users AS( 
	 SELECT r.race,
	 	    COUNT(u.id) AS total_users --общее кол-во зарегистрированных игркоов по расам
	 FROM fantasy.users AS u 
	 JOIN fantasy.race AS r USING(race_id)
	 GROUP BY r.race
),
buyers AS( -- считаем кол-во игроков, которые совершили покупку и долю платящих среди них
	SELECT  r.race,
		    COUNT(DISTINCT u.id) AS count_buyers, -- кол-во игроков с покупками
		    ROUND(SUM(u.payer)::numeric / COUNT(DISTINCT u.id), 3) AS buyers_dolya -- доля платящих
	FROM fantasy.users AS u
	JOIN fantasy.race AS r USING(race_id)
	WHERE u.id IN( -- берем только уникальных покупателей
		  SELECT DISTINCT id
		  FROM fantasy.events 
		  WHERE amount > 0
	) 
	GROUP BY r.race
),
buyers_activity AS( -- информация о покупках каждого игрока с учетом расы
	SELECT r.race,
		   e.id,
		   COUNT(*) AS transactions_count,-- кол-во покупок
		   SUM(e.amount) AS total_amount-- суммарная стоимость всех покупок игрока
	 FROM fantasy.events e
    JOIN fantasy.users AS u USING(id)
    JOIN fantasy.race AS r USING(race_id)
    WHERE e.amount > 0                -- учитываем только ненулевые покупки
    GROUP BY r.race, e.id 
)
SELECT tu.race,
	   tu.total_users,
	   b.count_buyers, -- игроки с покупками
	   b.buyers_dolya, --доля платящих
	   ROUND(b.count_buyers::numeric / tu.total_users, 3) AS dolya, -- доля игроков с покупками среди общего кол-ва игроков
	   ROUND(AVG(ba.transactions_count)::numeric, 3) AS avg_transactions_count, -- среднее количество покупок на одного покупателя
	   ROUND(SUM(ba.total_amount)::numeric / SUM(ba.transactions_count), 3) AS avg_price, --ИСПРАВЛЕННЫЙ РАСЧЕТ средней стоимости одной покупки
	   ROUND(AVG(ba.total_amount)::numeric, 3) AS avg_sum_price -- средняя суммарная стоимость покупок на одного покупателя
FROM total_users AS tu
LEFT JOIN buyers AS b ON tu.race = b.race
LEFT JOIN buyers_activity AS ba ON tu.race = ba.race
GROUP BY tu.race, tu.total_users, b.count_buyers, b.buyers_dolya
ORDER BY avg_sum_price DESC;
	   

