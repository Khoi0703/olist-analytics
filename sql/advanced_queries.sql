-- ============================================================
-- ADVANCED QUERIES (Window Functions)
-- ROW_NUMBER, RANK, DENSE_RANK, LEAD, LAG, FIRST_VALUE,
-- Rolling Average, Moving Sum, Percentile, NTILE
-- ============================================================

-- Q33. RANK khách hàng theo tổng chi tiêu
SELECT
    customer_unique_id,
    customer_lifetime_value,
    RANK() OVER (ORDER BY customer_lifetime_value DESC) AS spending_rank
FROM customers
WHERE customer_lifetime_value > 0
LIMIT 20;

-- Q34. DENSE_RANK sản phẩm theo doanh thu trong từng category
SELECT * FROM (
    SELECT
        p.product_category_name_english AS category,
        oi.product_id,
        SUM(oi.price) AS product_revenue,
        DENSE_RANK() OVER (
            PARTITION BY p.product_category_name_english
            ORDER BY SUM(oi.price) DESC
        ) AS rank_in_category
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name_english, oi.product_id
) ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- Q35. ROW_NUMBER: đơn hàng gần nhất của mỗi khách hàng
SELECT * FROM (
    SELECT
        o.order_id, c.customer_unique_id, o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp DESC
        ) AS rn
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
) latest_orders
WHERE rn = 1
LIMIT 20;

-- Q36. LAG/LEAD: So sánh doanh thu tháng hiện tại với tháng trước và tháng sau
SELECT
    order_month,
    SUM(order_revenue) AS revenue,
    LAG(SUM(order_revenue)) OVER (ORDER BY order_month) AS prev_month,
    LEAD(SUM(order_revenue)) OVER (ORDER BY order_month) AS next_month
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

-- Q37. Year-over-Year Growth (so sánh cùng kỳ năm trước, dùng LAG với offset 12 nếu đủ dữ liệu)
WITH monthly_rev AS (
    SELECT order_month, SUM(order_revenue) AS revenue
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    LAG(revenue, 12) OVER (ORDER BY order_month) AS revenue_same_month_last_year,
    ROUND(
        100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue, 12) OVER (ORDER BY order_month), 0), 2
    ) AS yoy_growth_pct
FROM monthly_rev
ORDER BY order_month;

-- Q38. FIRST_VALUE: Đơn hàng đầu tiên của mỗi khách hàng (ngày + giá trị)
SELECT DISTINCT
    c.customer_unique_id,
    FIRST_VALUE(o.order_purchase_timestamp) OVER (
        PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp
    ) AS first_purchase_date,
    FIRST_VALUE(o.order_revenue) OVER (
        PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp
    ) AS first_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
LIMIT 20;

-- Q39. Rolling 3-month average revenue (Moving Average)
WITH monthly_rev AS (
    SELECT order_month, SUM(order_revenue) AS revenue
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    ROUND(AVG(revenue) OVER (
        ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3mo_avg
FROM monthly_rev
ORDER BY order_month;

-- Q40. Moving Sum: Doanh thu lũy kế (cumulative revenue) theo tháng
WITH monthly_rev AS (
    SELECT order_month, SUM(order_revenue) AS revenue
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    SUM(revenue) OVER (ORDER BY order_month) AS cumulative_revenue
FROM monthly_rev
ORDER BY order_month;

-- Q41. NTILE(4): Chia khách hàng thành 4 nhóm (quartile) theo chi tiêu
SELECT
    customer_unique_id,
    customer_lifetime_value,
    NTILE(4) OVER (ORDER BY customer_lifetime_value DESC) AS spending_quartile
FROM customers
WHERE customer_lifetime_value > 0;

-- Q42. Percentile: Xác định ngưỡng chi tiêu Top 10% khách hàng (PERCENT_RANK)
SELECT customer_unique_id, customer_lifetime_value, pct_rank
FROM (
    SELECT
        customer_unique_id,
        customer_lifetime_value,
        PERCENT_RANK() OVER (ORDER BY customer_lifetime_value DESC) AS pct_rank
    FROM customers
    WHERE customer_lifetime_value > 0
) t
WHERE pct_rank <= 0.10
ORDER BY customer_lifetime_value DESC;

-- Q43. Xếp hạng seller theo doanh thu mỗi tháng (window PARTITION theo tháng)
SELECT * FROM (
    SELECT
        o.order_month,
        oi.seller_id,
        SUM(oi.price) AS monthly_revenue,
        RANK() OVER (PARTITION BY o.order_month ORDER BY SUM(oi.price) DESC) AS rank_in_month
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_month, oi.seller_id
) ranked
WHERE rank_in_month <= 3
ORDER BY order_month, rank_in_month;

-- Q44. Khoảng cách giữa các lần mua hàng liên tiếp của mỗi khách (dùng LAG)
SELECT
    customer_unique_id,
    order_purchase_timestamp,
    LAG(order_purchase_timestamp) OVER (
        PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp
    ) AS previous_purchase,
    order_purchase_timestamp - LAG(order_purchase_timestamp) OVER (
        PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp
    ) AS days_since_last_purchase
FROM (
    SELECT c.customer_unique_id, o.order_purchase_timestamp
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
) t
ORDER BY customer_unique_id, order_purchase_timestamp
LIMIT 50;
