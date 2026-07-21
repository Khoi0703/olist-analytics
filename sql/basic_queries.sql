-- ============================================================
-- Phase 8a — BASIC QUERIES
-- SELECT, WHERE, GROUP BY, HAVING, JOIN, ORDER BY, LIMIT
-- ============================================================

-- Q1. Tổng doanh thu, tổng số đơn hàng, AOV (Average Order Value)
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_revenue,
    ROUND(AVG(order_revenue), 2) AS avg_order_value
FROM orders
WHERE order_status = 'delivered';

-- Q2. Doanh thu theo tháng
SELECT order_month, SUM(order_revenue) AS revenue
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

-- Q3. Doanh thu theo năm
SELECT order_year, SUM(order_revenue) AS revenue
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_year
ORDER BY order_year;

-- Q4. Top 10 sản phẩm bán chạy nhất theo doanh thu
SELECT oi.product_id, p.product_category_name_english,
       SUM(oi.price) AS total_revenue,
       COUNT(*) AS units_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id, p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

-- Q5. 10 sản phẩm bán kém nhất (có ít nhất 1 đơn bán được)
SELECT oi.product_id, p.product_category_name_english,
       SUM(oi.price) AS total_revenue,
       COUNT(*) AS units_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id, p.product_category_name_english
ORDER BY total_revenue ASC
LIMIT 10;

-- Q6. Top 10 category theo doanh thu
SELECT p.product_category_name_english AS category,
       SUM(oi.price) AS total_revenue,
       COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

-- Q7. Top 10 seller theo doanh thu
SELECT oi.seller_id, s.seller_state,
       SUM(oi.price) AS total_revenue,
       COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;

-- Q8. Doanh thu theo bang (state) của khách hàng
SELECT c.customer_state, SUM(o.order_revenue) AS revenue, COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Q9. Doanh thu theo thành phố (top 15)
SELECT c.customer_city, c.customer_state, SUM(o.order_revenue) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_city, c.customer_state
ORDER BY revenue DESC
LIMIT 15;

-- Q10. Phân bố phương thức thanh toán
SELECT payment_type, COUNT(*) AS total_transactions,
       SUM(payment_value) AS total_value,
       ROUND(AVG(payment_installments), 1) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- Q11. Thời gian giao hàng trung bình toàn hệ thống
SELECT ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
       MIN(delivery_days) AS min_days,
       MAX(delivery_days) AS max_days
FROM orders
WHERE order_status = 'delivered';

-- Q12. Tỷ lệ giao trễ (Late Delivery Rate)
SELECT
    SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) AS late_orders,
    COUNT(*) AS total_delivered,
    ROUND(100.0 * SUM(CASE WHEN is_late_delivery THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_rate_pct
FROM orders
WHERE order_status = 'delivered';

-- Q13. Tỷ lệ hủy đơn (Cancellation Rate) theo tháng
SELECT order_month,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END) AS cancelled_orders,
       ROUND(100.0 * SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancel_rate_pct
FROM orders
GROUP BY order_month
ORDER BY order_month;

-- Q14. Phân bố điểm đánh giá (review score)
SELECT review_score, COUNT(*) AS total_reviews
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- Q15. Điểm đánh giá trung bình theo tháng
SELECT order_month, ROUND(AVG(review_score), 2) AS avg_review_score
FROM orders
WHERE review_score IS NOT NULL
GROUP BY order_month
ORDER BY order_month;

-- Q16. Số lượng đơn hàng theo trạng thái (order_status)
SELECT order_status, COUNT(*) AS total
FROM orders
GROUP BY order_status
ORDER BY total DESC;

-- Q17. Trung bình số sản phẩm mỗi đơn (Average Basket Size)
SELECT ROUND(AVG(items_count), 2) AS avg_items_per_order
FROM orders
WHERE order_status = 'delivered';

-- Q18. Doanh thu trung bình theo category (AOV theo category)
SELECT p.product_category_name_english AS category,
       ROUND(AVG(oi.price), 2) AS avg_item_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
HAVING COUNT(*) > 30
ORDER BY avg_item_price DESC
LIMIT 15;

-- Q19. Khách hàng có nhiều đơn nhất (Top 10)
SELECT customer_unique_id, total_orders, customer_lifetime_value
FROM customers
ORDER BY total_orders DESC
LIMIT 10;

-- Q20. Tỷ lệ khách hàng mua lại (Repeat Customer Rate) tổng thể
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_repeat_customer THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN is_repeat_customer THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_rate_pct
FROM customers;
