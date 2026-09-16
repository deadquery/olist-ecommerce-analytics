-- ============================================================
-- Olist E-Commerce Analytics
-- SQL Analysis
-- PostgreSQL
-- ============================================================


-- ============================================================
-- 1. Total Revenue
-- Общая выручка
-- ============================================================

SELECT
    SUM(price) AS total_revenue
FROM public.olist_order_items_dataset;


-- ============================================================
-- 2. Total Orders
-- Количество уникальных заказов
-- ============================================================

SELECT
    COUNT(DISTINCT order_id) AS total_orders
FROM public.olist_order_items_dataset;


-- ============================================================
-- 3. Total Items
-- Общее количество товарных позиций в заказах
-- ============================================================

SELECT
    COUNT(*) AS total_items
FROM public.olist_order_items_dataset;


-- ============================================================
-- 4. Average Order Value (AOV)
-- Средний чек
-- ============================================================

WITH order_totals AS (
    SELECT
        order_id,
        SUM(price) AS order_total
    FROM public.olist_order_items_dataset
    GROUP BY order_id
)

SELECT
    AVG(order_total) AS average_order_value
FROM order_totals;


-- ============================================================
-- 5. Monthly Revenue
-- Выручка по месяцам
-- ============================================================

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month_date,
    TO_CHAR(
        DATE_TRUNC('month', o.order_purchase_timestamp),
        'YYYY-MM'
    ) AS month,
    SUM(oi.price) AS revenue
FROM public.olist_orders_dataset AS o
JOIN public.olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
GROUP BY
    DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY
    month_date;


-- ============================================================
-- 6. Top Product Categories by Revenue
-- Топ категорий по выручке
-- ============================================================

SELECT
    t.product_category_name_english AS category,
    SUM(oi.price) AS revenue
FROM public.olist_order_items_dataset AS oi
JOIN public.olist_products_dataset AS p
    ON oi.product_id = p.product_id
JOIN public.product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
GROUP BY
    t.product_category_name_english
ORDER BY
    revenue DESC;


-- ============================================================
-- 7. Repeat Customers
-- Клиенты, совершившие более одной покупки
-- ============================================================

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM public.olist_customers_dataset AS c
JOIN public.olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_unique_id
HAVING
    COUNT(DISTINCT o.order_id) > 1
ORDER BY
    order_count DESC;


-- ============================================================
-- 8. Repeat Customer Share
-- Доля клиентов с повторными покупками
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM public.olist_customers_dataset AS c
    JOIN public.olist_orders_dataset AS o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id
)

SELECT
    100.0 * COUNT(*) FILTER (
        WHERE order_count > 1
    ) / COUNT(*) AS repeat_customer_share_pct
FROM customer_orders;


-- ============================================================
-- 9. Average Delivery Time
-- Среднее время доставки
-- ============================================================

SELECT
    AVG(
        o.order_delivered_customer_date::date
        - o.order_purchase_timestamp::date
    ) AS average_delivery_days
FROM public.olist_orders_dataset AS o
WHERE
    o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL;


-- ============================================================
-- 10. Late Delivery Share
-- Доля заказов, доставленных позже расчетной даты
-- ============================================================

WITH delivered_orders AS (
    SELECT
        order_id,
        order_delivered_customer_date,
        order_estimated_delivery_date
    FROM public.olist_orders_dataset
    WHERE
        order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    100.0 * COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) / COUNT(*) AS late_delivery_share_pct
FROM delivered_orders;


-- ============================================================
-- 11. Average Review Score by Delivery Status
-- Средняя оценка в зависимости от своевременности доставки
-- ============================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On time'

        WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
            THEN 'Late'
    END AS delivery_status,

    AVG(r.review_score) AS average_review_score

FROM public.olist_orders_dataset AS o

JOIN public.olist_order_reviews_dataset AS r
    ON o.order_id = r.order_id

WHERE
    o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On time'

        WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
            THEN 'Late'
    END

ORDER BY
    average_review_score DESC;


-- ============================================================
-- 12. Average Review Score by Month
-- Средняя оценка по месяцам
-- ============================================================

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    ) AS month_date,

    TO_CHAR(
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ),
        'YYYY-MM'
    ) AS month,

    AVG(r.review_score) AS average_review_score

FROM public.olist_orders_dataset AS o

JOIN public.olist_order_reviews_dataset AS r
    ON o.order_id = r.order_id

GROUP BY
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )

ORDER BY
    month_date;


-- ============================================================
-- 13. Average Order Value by Month
-- Средний чек по месяцам
-- ============================================================

WITH order_totals AS (
    SELECT
        o.order_id,

        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ) AS month_date,

        SUM(oi.price) AS order_total

    FROM public.olist_orders_dataset AS o

    JOIN public.olist_order_items_dataset AS oi
        ON o.order_id = oi.order_id

    GROUP BY
        o.order_id,
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )
)

SELECT
    month_date,

    TO_CHAR(
        month_date,
        'YYYY-MM'
    ) AS month,

    AVG(order_total) AS average_order_value

FROM order_totals

GROUP BY
    month_date

ORDER BY
    month_date;


-- ============================================================
-- 14. Monthly Revenue + Previous Month + MoM Growth
-- Выручка, предыдущий месяц и рост месяц к месяцу
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ) AS month_date,

        SUM(oi.price) AS revenue

    FROM public.olist_orders_dataset AS o

    JOIN public.olist_order_items_dataset AS oi
        ON o.order_id = oi.order_id

    GROUP BY
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )
),

revenue_with_previous AS (

    SELECT
        month_date,
        revenue,

        LAG(revenue) OVER (
            ORDER BY month_date
        ) AS previous_month_revenue

    FROM monthly_revenue
)

SELECT
    month_date,

    TO_CHAR(
        month_date,
        'YYYY-MM'
    ) AS month,

    revenue,
    previous_month_revenue,

    100.0 * (
        revenue - previous_month_revenue
    )
    / NULLIF(
        previous_month_revenue,
        0
    ) AS mom_growth_pct

FROM revenue_with_previous

ORDER BY
    month_date;


-- ============================================================
-- 15. Monthly Orders, Revenue and AOV
-- Сводная месячная аналитика
-- ============================================================

WITH monthly_orders AS (

    SELECT
        o.order_id,

        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ) AS month_date,

        SUM(oi.price) AS order_total

    FROM public.olist_orders_dataset AS o

    JOIN public.olist_order_items_dataset AS oi
        ON o.order_id = oi.order_id

    GROUP BY
        o.order_id,

        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )
)

SELECT
    month_date,

    TO_CHAR(
        month_date,
        'YYYY-MM'
    ) AS month,

    COUNT(*) AS order_count,
    SUM(order_total) AS revenue,
    AVG(order_total) AS average_order_value

FROM monthly_orders

GROUP BY
    month_date

ORDER BY
    month_date;