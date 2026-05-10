```sql
/* 
Проект: Разработка пользовательской витрины маркетплейса «ВсёТут»
Файл: 02_ad_hoc_analysis.sql
Описание: ad-hoc аналитические задачи на основе пользовательской витрины
Автор: Чаунина Инесса
*/


/* =========================================================
   ЗАДАЧА 1. Сегментация пользователей
========================================================= */

with segment as (

    select
        user_id,
        total_orders,
        avg_order_cost,
        num_orders_with_promo,
        total_order_costs,

        case
            when total_orders = 1 then '1 заказ'
            when total_orders between 2 and 5 then '2-5 заказов'
            when total_orders between 6 and 10 then '6-10 заказов'
            when total_orders >= 11 then '11 и более заказов'
        end as segment

    from ds_ecom.product_user_features
)

select
    segment,

    count(user_id) as count_users,
    round(avg(total_orders), 2) as avg_count_orders,

    round(
        sum(total_order_costs) / sum(total_orders),
        2
    ) as avg_order_sum,

    sum(num_orders_with_promo) as count_orders_with_promo

from segment
group by segment
order by count_users desc;


/*
Выводы:
- Большинство пользователей совершают только один заказ.
- Пользователи с большим количеством заказов встречаются значительно реже.
- Средняя стоимость заказа выше у пользователей с небольшим количеством заказов.
- Использование промокодов не оказывает значительного влияния на количество заказов.
*/



/* =========================================================
   ЗАДАЧА 2. Ранжирование пользователей
========================================================= */

select
    region,
    lifetime,
    total_orders,
    avg_order_cost,
    avg_order_rating,
    num_orders_with_rating,
    num_canceled_orders,
    num_installment_orders,
    num_orders_with_promo,
    used_money_transfer,
    used_installments,
    used_cancel

from ds_ecom.product_user_features

where total_orders >= 3

order by avg_order_cost desc

limit 15;


/*
Выводы:
- Пользователи с самым высоким средним чеком чаще совершают 3–5 заказов.
- Наибольшая доля пользователей с высоким средним чеком приходится на Санкт-Петербург.
- Большинство пользователей положительно оценивают заказы.
- Рассрочка используется достаточно часто.
- Промокоды используются редко.
*/



/* =========================================================
   ЗАДАЧА 3. Статистика по регионам
========================================================= */

select
    region,

    count(user_id) as count_users,
    sum(total_orders) as count_orders,

    round(
        sum(total_order_costs) / sum(total_orders),
        2
    ) as avg_order_sum,

    round(
        sum(num_installment_orders)::numeric
        / sum(total_orders),
        3
    ) as installment_orders_ratio,

    round(
        sum(num_orders_with_promo)::numeric
        / sum(total_orders),
        3
    ) as promo_orders_ratio,

    round(
        avg(used_cancel)::numeric,
        4
    ) as canceled_users_ratio

from ds_ecom.product_user_features

group by region

order by count_users desc;


/*
Выводы:
- Москва лидирует по количеству клиентов и заказов.
- Средняя стоимость заказа в крупнейших регионах отличается незначительно.
- Значительная часть заказов оформляется в рассрочку.
- Промокоды используются редко.
- Доля пользователей с отменами остается низкой.
*/



/* =========================================================
   ЗАДАЧА 4. Активность пользователей в 2023 году
========================================================= */

select
    date_trunc(
        'month',
        first_order_ts
    )::timestamp as first_order_month,

    count(user_id) as count_users,

    sum(total_orders) as count_orders,

    round(
        sum(total_order_costs) / sum(total_orders),
        2
    ) as avg_order_sum,

    round(
        avg(avg_order_rating),
        2
    ) as avg_order_rating,

    round(
        sum(used_money_transfer)::numeric
        / count(user_id),
        3
    ) as money_transfer_users_ratio,

    avg(lifetime) as avg_lifetime

from ds_ecom.product_user_features

where extract(year from first_order_ts) = 2023

group by first_order_month

order by first_order_month;


/*
Выводы:
- В течение 2023 года наблюдался рост количества пользователей и заказов.
- Средняя стоимость заказов менялась неравномерно в зависимости от сезона.
- Средний рейтинг заказов оставался высоким на протяжении всего года.
- Денежные переводы использовала примерно пятая часть пользователей.
- Продолжительность активности пользователей снижалась к концу года.
*/
```

