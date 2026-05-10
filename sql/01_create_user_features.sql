/* 
Проект: Разработка пользовательской витрины маркетплейса «ВсёТут»
Файл: 01_create_user_features.sql
Описание: создание пользовательской витрины с метриками заказов, оплат, отмен и рейтингов
Автор: Чаунина Инесса
*/

WITH top_region as (
    -- Топ-3 региона по количеству доставленных и отмененных заказов
    select
        u.region,
        dense_rank() over (
            order by count(distinct o.order_id) desc
        ) as region_rank
    from ds_ecom.orders as o
    join ds_ecom.users as u
        using (buyer_id)
    where o.order_status in ('Доставлено', 'Отменено')
    group by u.region
),

order_payments_stat as (
    -- Статистика по оплатам на уровне пользователя
    select
        u.user_id,
        tr.region,

        count(distinct case
            when op.payment_installments > 1 then o.order_id
        end) as num_installment_orders,

        count(distinct case
            when op.payment_type = 'промокод' then o.order_id
        end) as num_orders_with_promo,

        count(distinct case
            when op.payment_sequential = 1
             and op.payment_type = 'денежный перевод' then o.order_id
        end) as num_money_transfer_orders

    from ds_ecom.order_payments as op
    join ds_ecom.orders as o
        using (order_id)
    join ds_ecom.users as u
        using (buyer_id)
    join top_region as tr
        on u.region = tr.region
    where tr.region_rank <= 3
      and o.order_status in ('Доставлено', 'Отменено')
    group by
        u.user_id,
        tr.region
),

order_costs as (
    -- Стоимость каждого заказа
    select
        o.order_id,
        sum(
            case
                when o.order_status = 'Отменено' then null::numeric
                else oi.price::numeric + oi.delivery_cost::numeric
            end
        ) as order_cost
    from ds_ecom.orders as o
    join ds_ecom.order_items as oi
        using (order_id)
    where o.order_status in ('Доставлено', 'Отменено')
    group by o.order_id
),

user_order_costs as (
    -- Общая и средняя стоимость заказов пользователя
    select
        u.user_id,
        tr.region,
        sum(oc.order_cost) as total_order_costs,
        avg(oc.order_cost)::numeric(9, 2) as avg_order_cost
    from ds_ecom.orders as o
    join order_costs as oc
        using (order_id)
    join ds_ecom.users as u
        using (buyer_id)
    join top_region as tr
        on u.region = tr.region
    where tr.region_rank <= 3
      and o.order_status in ('Доставлено', 'Отменено')
    group by
        u.user_id,
        tr.region
),

order_ratings as (
    -- Средний рейтинг заказа
    select
        order_id,
        avg(
            case
                when review_score > 5 then review_score::numeric / 10
                when review_score <= 5 and review_score is not null then review_score::numeric
            end
        ) as review_score
    from ds_ecom.order_reviews
    group by order_id
),

user_rating_stat as (
    -- Статистика по рейтингам пользователя
    select
        u.user_id,
        tr.region,
        avg(r.review_score)::numeric(9, 2) as avg_order_rating,
        count(r.review_score) as num_orders_with_rating,
        count(distinct o.order_id) as total_orders
    from ds_ecom.users as u
    join top_region as tr
        on u.region = tr.region
    join ds_ecom.orders as o
        using (buyer_id)
    left join order_ratings as r
        using (order_id)
    where tr.region_rank <= 3
      and o.order_status in ('Доставлено', 'Отменено')
    group by
        u.user_id,
        tr.region
),

user_activity_stat as (
    -- Статистика активности пользователя
    select
        u.user_id,
        tr.region,
        min(o.order_purchase_ts::timestamp) as first_order_ts,
        max(o.order_purchase_ts::timestamp) as last_order_ts,

        date_trunc(
            'day',
            max(o.order_purchase_ts::timestamp) - min(o.order_purchase_ts::timestamp)
        ) as lifetime,

        sum(case when o.order_status = 'Отменено' then 1 else 0 end)::numeric as num_canceled_orders,

        round(
            sum(case when o.order_status = 'Отменено' then 1 else 0 end)::numeric
            / count(o.order_id)::numeric,
            4
        ) as canceled_orders_ratio

    from ds_ecom.users as u
    join top_region as tr
        on u.region = tr.region
    join ds_ecom.orders as o
        using (buyer_id)
    where tr.region_rank <= 3
      and o.order_status in ('Доставлено', 'Отменено')
    group by
        u.user_id,
        tr.region
)

select
    uas.user_id,
    uas.region,
    uas.first_order_ts,
    uas.last_order_ts,
    uas.lifetime,

    urs.total_orders,
    urs.avg_order_rating,
    urs.num_orders_with_rating,

    uas.num_canceled_orders,
    uas.canceled_orders_ratio,

    uoc.total_order_costs,
    uoc.avg_order_cost,

    ops.num_installment_orders,
    ops.num_orders_with_promo,

    case
        when ops.num_money_transfer_orders >= 1 then 1
        else 0
    end as used_money_transfer,

    case
        when ops.num_installment_orders >= 1 then 1
        else 0
    end as used_installments,

    case
        when uas.num_canceled_orders >= 1 then 1
        else 0
    end as used_cancel

from user_activity_stat as uas
join user_rating_stat as urs
    using (user_id, region)
join user_order_costs as uoc
    using (user_id, region)
join order_payments_stat as ops
    using (user_id, region)
order by
    urs.total_orders desc;

