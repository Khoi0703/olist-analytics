-- ============================================================
-- BUSINESS ANALYSIS QUERIES
-- RFM Segmentation, Cohort Analysis, Retention, Deep-dive nghiệp vụ
-- ============================================================

-- ============ RFM ANALYSIS ============
-- Q45. RFM: Tính Recency, Frequency, Monetary cho từng khách hàng
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.order_revenue) AS monetary
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_calc AS (
    SELECT
        customer_unique_id,
        (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered')
            - last_purchase_date AS recency_interval,
        frequency,
        monetary
    FROM rfm_base
)
SELECT
    customer_unique_id,
    EXTRACT(DAY FROM recency_interval) AS recency_days,
    frequency,
    monetary
FROM rfm_calc
ORDER BY monetary DESC
LIMIT 20;

-- Q46. RFM: Chấm điểm 1-5 cho từng chiều bằng NTILE và tính RFM Score tổng hợp
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM (
            (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered')
            - MAX(o.order_purchase_timestamp)
        )) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.order_revenue) AS monetary
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scored AS (
    SELECT
        customer_unique_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- recency thấp hơn = tốt hơn -> đảo chiều
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id, recency_days, frequency, monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score) AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalist'
        WHEN (r_score + f_score + m_score) >= 4  THEN 'At Risk'
        ELSE 'Lost'
    END AS rfm_segment
FROM rfm_scored
ORDER BY rfm_total DESC
LIMIT 50;

-- Q47. Đếm số khách hàng theo từng RFM Segment
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM (
            (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered')
            - MAX(o.order_purchase_timestamp)
        )) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.order_revenue) AS monetary
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scored AS (
    SELECT
        customer_unique_id,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
),
rfm_segment AS (
    SELECT customer_unique_id,
        CASE
            WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
            WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
            WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalist'
            WHEN (r_score + f_score + m_score) >= 4  THEN 'At Risk'
            ELSE 'Lost'
        END AS rfm_segment
    FROM rfm_scored
)
SELECT rfm_segment, COUNT(*) AS total_customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM rfm_segment
GROUP BY rfm_segment
ORDER BY total_customers DESC;

-- ============ COHORT ANALYSIS ============
-- Q48. Cohort: Xác định tháng "sinh" (first purchase month) của mỗi khách hàng
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT cohort_month, COUNT(*) AS new_customers
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q49. Cohort Retention Matrix: khách hàng ở mỗi cohort còn hoạt động ở tháng thứ N sau đó
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
)
SELECT
    fp.cohort_month,
    EXTRACT(YEAR FROM AGE(ca.activity_month, fp.cohort_month)) * 12
        + EXTRACT(MONTH FROM AGE(ca.activity_month, fp.cohort_month)) AS month_number,
    COUNT(DISTINCT ca.customer_unique_id) AS active_customers
FROM first_purchase fp
JOIN customer_activity ca ON fp.customer_unique_id = ca.customer_unique_id
GROUP BY fp.cohort_month, month_number
ORDER BY fp.cohort_month, month_number;

-- Q50. Retention Rate: % khách quay lại mua ở tháng thứ 1 sau lần mua đầu tiên
WITH first_purchase AS (
    SELECT c.customer_unique_id,
           DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS total_customers
    FROM first_purchase GROUP BY cohort_month
),
retained_month1 AS (
    SELECT fp.cohort_month, COUNT(DISTINCT fp.customer_unique_id) AS retained
    FROM first_purchase fp
    JOIN orders o ON o.customer_id IN (
        SELECT customer_id FROM customers WHERE customer_unique_id = fp.customer_unique_id
    )
    JOIN customers c ON o.customer_id = c.customer_id AND c.customer_unique_id = fp.customer_unique_id
    WHERE DATE_TRUNC('month', o.order_purchase_timestamp) = fp.cohort_month + INTERVAL '1 month'
      AND o.order_status = 'delivered'
    GROUP BY fp.cohort_month
)
SELECT cs.cohort_month, cs.total_customers,
       COALESCE(rm.retained, 0) AS retained_month1,
       ROUND(100.0 * COALESCE(rm.retained, 0) / cs.total_customers, 2) AS retention_rate_pct
FROM cohort_size cs
LEFT JOIN retained_month1 rm ON cs.cohort_month = rm.cohort_month
ORDER BY cs.cohort_month;

-- ============ DEEP-DIVE NGHIỆP VỤ ============
-- Q51. Late delivery rate theo bang
SELECT c.customer_state,
       COUNT(*) AS total_delivered,
       SUM(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END) AS late_orders,
       ROUND(100.0 * SUM(CASE WHEN o.is_late_delivery THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_rate_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING COUNT(*) >= 50
ORDER BY late_rate_pct DESC;

-- Q52. Ảnh hưởng của giao trễ đến review score
SELECT
    is_late_delivery,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'delivered' AND is_late_delivery IS NOT NULL AND review_score IS NOT NULL
GROUP BY is_late_delivery;

-- Q53. Review score trung bình theo category (đủ dữ liệu tin cậy >= 30 đơn)
SELECT p.product_category_name_english AS category,
       ROUND(AVG(o.review_score), 2) AS avg_review_score,
       COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.review_score IS NOT NULL
GROUP BY p.product_category_name_english
HAVING COUNT(DISTINCT oi.order_id) >= 30
ORDER BY avg_review_score ASC
LIMIT 10;

-- Q54. Correlation giữa delivery_days và review_score (theo nhóm delivery_days)
SELECT
    WIDTH_BUCKET(delivery_days, 0, 60, 6) AS delivery_days_bucket,
    MIN(delivery_days) AS min_days, MAX(delivery_days) AS max_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'delivered' AND delivery_days IS NOT NULL AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q55. Top 20% khách hàng đóng góp bao nhiêu % doanh thu (Pareto/80-20 check)
WITH ranked AS (
    SELECT customer_unique_id, customer_lifetime_value,
           NTILE(5) OVER (ORDER BY customer_lifetime_value DESC) AS quintile
    FROM customers
    WHERE customer_lifetime_value > 0
)
SELECT
    CASE WHEN quintile = 1 THEN 'Top 20%' ELSE 'Remaining 80%' END AS customer_group,
    SUM(customer_lifetime_value) AS total_revenue,
    ROUND(100.0 * SUM(customer_lifetime_value) / SUM(SUM(customer_lifetime_value)) OVER (), 2) AS pct_of_revenue
FROM ranked
GROUP BY CASE WHEN quintile = 1 THEN 'Top 20%' ELSE 'Remaining 80%' END;

-- Q56. Sales peak theo tháng trong năm (kiểm tra mùa vụ, vd tháng 11)
SELECT
    EXTRACT(MONTH FROM order_purchase_timestamp) AS month_number,
    TO_CHAR(order_purchase_timestamp, 'Month') AS month_name,
    COUNT(*) AS total_orders,
    SUM(order_revenue) AS total_revenue
FROM orders
WHERE order_status = 'delivered'
GROUP BY 1, 2
ORDER BY 1;

-- Q57. Khách hàng mua nhiều category khác nhau có CLV cao hơn không?
WITH customer_category_count AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT p.product_category_name_english) AS distinct_categories,
           MAX(c.customer_lifetime_value) AS clv
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN distinct_categories = 1 THEN '1 category'
         WHEN distinct_categories = 2 THEN '2 categories'
         ELSE '3+ categories' END AS category_diversity,
    ROUND(AVG(clv), 2) AS avg_clv,
    COUNT(*) AS total_customers
FROM customer_category_count
GROUP BY 1
ORDER BY avg_clv DESC;

-- Q58. Payment type nào phổ biến nhất theo từng bang
SELECT * FROM (
    SELECT c.customer_state, op.payment_type,
           COUNT(*) AS total,
           RANK() OVER (PARTITION BY c.customer_state ORDER BY COUNT(*) DESC) AS rnk
    FROM order_payments op
    JOIN orders o ON op.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_state, op.payment_type
) t
WHERE rnk = 1
ORDER BY customer_state;

-- Q59. Health & Beauty products: doanh thu cao nhưng review thấp? (kiểm chứng insight mẫu)
SELECT
    p.product_category_name_english AS category,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(o.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 15;

-- Q60. Bottom 10 khách hàng (đã từng mua nhưng CLV rất thấp - đối tượng cần win-back)
SELECT customer_unique_id, total_orders, customer_lifetime_value
FROM customers
WHERE customer_lifetime_value > 0
ORDER BY customer_lifetime_value ASC
LIMIT 10;
