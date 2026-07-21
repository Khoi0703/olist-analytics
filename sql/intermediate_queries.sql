-- ============================================================
-- Phase 8b — INTERMEDIATE QUERIES
-- CASE, CTE, Subquery, UNION, Temporary Tables
-- ============================================================

-- Q21. Phân loại đơn hàng theo tốc độ giao (CASE)
SELECT
    order_id,
    delivery_days,
    CASE
        WHEN delivery_days <= 3 THEN 'Fast (<=3 days)'
        WHEN delivery_days <= 7 THEN 'Normal (4-7 days)'
        WHEN delivery_days <= 15 THEN 'Slow (8-15 days)'
        ELSE 'Very Slow (>15 days)'
    END AS delivery_speed_category
FROM orders
WHERE order_status = 'delivered' AND delivery_days IS NOT NULL
LIMIT 100;

-- Q22. Đếm số đơn theo delivery_speed_category
SELECT
    CASE
        WHEN delivery_days <= 3 THEN 'Fast (<=3 days)'
        WHEN delivery_days <= 7 THEN 'Normal (4-7 days)'
        WHEN delivery_days <= 15 THEN 'Slow (8-15 days)'
        ELSE 'Very Slow (>15 days)'
    END AS delivery_speed_category,
    COUNT(*) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM orders
WHERE order_status = 'delivered' AND delivery_days IS NOT NULL
GROUP BY 1
ORDER BY total_orders DESC;

-- Q23. Phân khúc khách hàng theo chi tiêu (CASE)
SELECT
    customer_unique_id,
    customer_lifetime_value,
    CASE
        WHEN customer_lifetime_value = 0 THEN 'No Purchase'
        WHEN customer_lifetime_value < 100 THEN 'Low Value'
        WHEN customer_lifetime_value < 500 THEN 'Medium Value'
        ELSE 'High Value'
    END AS value_segment
FROM customers
ORDER BY customer_lifetime_value DESC
LIMIT 50;

-- Q24. CTE: Doanh thu theo tháng + Month-over-Month Growth
WITH monthly_rev AS (
    SELECT order_month, SUM(order_revenue) AS revenue
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2
    ) AS mom_growth_pct
FROM monthly_rev
ORDER BY order_month;

-- Q25. CTE: AOV theo tháng
WITH order_summary AS (
    SELECT order_month, order_id, order_revenue
    FROM orders
    WHERE order_status = 'delivered'
)
SELECT order_month,
       COUNT(order_id) AS total_orders,
       ROUND(AVG(order_revenue), 2) AS avg_order_value
FROM order_summary
GROUP BY order_month
ORDER BY order_month;

-- Q26. Subquery: Khách hàng có chi tiêu trên mức trung bình
SELECT customer_unique_id, customer_lifetime_value
FROM customers
WHERE customer_lifetime_value > (
    SELECT AVG(customer_lifetime_value) FROM customers WHERE customer_lifetime_value > 0
)
ORDER BY customer_lifetime_value DESC
LIMIT 20;

-- Q27. Subquery: Sản phẩm có giá trên trung bình của category đó
SELECT p.product_id, p.product_category_name_english, oi.price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE oi.price > (
    SELECT AVG(oi2.price)
    FROM order_items oi2
    JOIN products p2 ON oi2.product_id = p2.product_id
    WHERE p2.product_category_name_english = p.product_category_name_english
)
LIMIT 50;

-- Q28. Subquery: Sellers chưa từng nhận review dưới 3 sao (seller uy tín)
SELECT DISTINCT oi.seller_id
FROM order_items oi
WHERE oi.seller_id NOT IN (
    SELECT DISTINCT oi2.seller_id
    FROM order_items oi2
    JOIN order_reviews r ON oi2.order_id = r.order_id
    WHERE r.review_score < 3
)
LIMIT 20;

-- Q29. UNION: Gộp danh sách khách "High Value" và khách "Repeat" thành 1 danh sách target marketing
SELECT customer_unique_id, 'High Value' AS reason
FROM customers
WHERE customer_lifetime_value >= 500
UNION
SELECT customer_unique_id, 'Repeat Customer' AS reason
FROM customers
WHERE is_repeat_customer = TRUE
ORDER BY customer_unique_id
LIMIT 50;

-- Q30. Temporary table: Bảng tạm doanh thu theo category để tái sử dụng nhiều lần
CREATE TEMP TABLE tmp_category_revenue AS
SELECT p.product_category_name_english AS category,
       SUM(oi.price) AS total_revenue,
       COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english;

SELECT * FROM tmp_category_revenue ORDER BY total_revenue DESC LIMIT 10;
SELECT AVG(total_revenue) AS avg_revenue_per_category FROM tmp_category_revenue;
DROP TABLE tmp_category_revenue;

-- Q31. CTE: Category có review trung bình thấp nhất (>=50 đơn để đủ tin cậy)
WITH category_reviews AS (
    SELECT p.product_category_name_english AS category,
           AVG(o.review_score) AS avg_score,
           COUNT(DISTINCT oi.order_id) AS total_orders
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.review_score IS NOT NULL
    GROUP BY p.product_category_name_english
)
SELECT * FROM category_reviews
WHERE total_orders >= 50
ORDER BY avg_score ASC
LIMIT 10;

-- Q32. CASE + CTE: Phân loại payment theo installments (trả góp)
WITH payment_class AS (
    SELECT order_id, payment_type,
           CASE WHEN payment_installments <= 1 THEN 'One-time'
                WHEN payment_installments <= 6 THEN 'Short-term installment'
                ELSE 'Long-term installment'
           END AS installment_type
    FROM order_payments
)
SELECT installment_type, COUNT(*) AS total
FROM payment_class
GROUP BY installment_type
ORDER BY total DESC;
