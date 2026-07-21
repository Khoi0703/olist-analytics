-- ============================================================
-- Olist E-commerce Analytics — Database Schema (PostgreSQL)
-- Phase 6 - Database Design
-- ============================================================

DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;

-- ---------- CUSTOMERS ----------
CREATE TABLE customers (
    customer_id             VARCHAR(32) PRIMARY KEY,
    customer_unique_id      VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(10),
    customer_city           VARCHAR(100),
    customer_state          VARCHAR(2),
    customer_lifetime_value NUMERIC(12,2) DEFAULT 0,
    total_orders            INTEGER DEFAULT 0,
    is_repeat_customer      BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);
CREATE INDEX idx_customers_state ON customers(customer_state);

-- ---------- SELLERS ----------
CREATE TABLE sellers (
    seller_id             VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city           VARCHAR(100),
    seller_state          VARCHAR(2)
);

-- ---------- PRODUCTS ----------
CREATE TABLE products (
    product_id                    VARCHAR(32) PRIMARY KEY,
    product_category_name         VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_name_lenght           NUMERIC,
    product_description_lenght    NUMERIC,
    product_photos_qty            NUMERIC,
    product_weight_g              NUMERIC,
    product_length_cm             NUMERIC,
    product_height_cm             NUMERIC,
    product_width_cm              NUMERIC
);
CREATE INDEX idx_products_category ON products(product_category_name_english);

-- ---------- ORDERS (fact table trung tâm) ----------
CREATE TABLE orders (
    order_id                        VARCHAR(32) PRIMARY KEY,
    customer_id                     VARCHAR(32) REFERENCES customers(customer_id),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP,
    order_month                     VARCHAR(7),
    order_year                      INTEGER,
    order_quarter                   VARCHAR(7),
    order_weekday                   VARCHAR(10),
    is_weekend_purchase             BOOLEAN,
    delivery_days                   INTEGER,
    is_late_delivery                BOOLEAN,
    is_cancelled                    BOOLEAN,
    items_count                     INTEGER,
    product_revenue                 NUMERIC(12,2),
    freight_total                   NUMERIC(12,2),
    order_revenue                   NUMERIC(12,2),
    review_score                    NUMERIC(3,2),
    review_score_category           VARCHAR(10),
    is_repeat_customer              BOOLEAN
);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_month ON orders(order_month);
CREATE INDEX idx_orders_purchase_ts ON orders(order_purchase_timestamp);

-- ---------- ORDER ITEMS ----------
CREATE TABLE order_items (
    order_id            VARCHAR(32) REFERENCES orders(order_id),
    order_item_id        INTEGER,
    product_id           VARCHAR(32) REFERENCES products(product_id),
    seller_id            VARCHAR(32) REFERENCES sellers(seller_id),
    shipping_limit_date   TIMESTAMP,
    price                 NUMERIC(10,2),
    freight_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_seller ON order_items(seller_id);

-- ---------- ORDER PAYMENTS ----------
CREATE TABLE order_payments (
    order_id             VARCHAR(32) REFERENCES orders(order_id),
    payment_sequential    INTEGER,
    payment_type          VARCHAR(20),
    payment_installments   INTEGER,
    payment_value          NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);
CREATE INDEX idx_payments_type ON order_payments(payment_type);

-- ---------- ORDER REVIEWS ----------
CREATE TABLE order_reviews (
    review_id               VARCHAR(32) PRIMARY KEY,
    order_id                 VARCHAR(32) REFERENCES orders(order_id),
    review_score              SMALLINT,
    review_comment_title       TEXT,
    review_comment_message     TEXT,
    review_creation_date        TIMESTAMP,
    review_answer_timestamp     TIMESTAMP,
    review_score_category       VARCHAR(10)
);
CREATE INDEX idx_reviews_order ON order_reviews(order_id);
CREATE INDEX idx_reviews_score ON order_reviews(review_score);

-- ---------- GEOLOCATION ----------
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat              NUMERIC(10,7),
    geolocation_lng              NUMERIC(10,7),
    geolocation_city             VARCHAR(100),
    geolocation_state            VARCHAR(2)
);
CREATE INDEX idx_geo_zip ON geolocation(geolocation_zip_code_prefix);

-- ============================================================
-- VIEWS hữu ích cho Phase 8 (SQL Business Analysis)
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_revenue,
    ROUND(AVG(order_revenue), 2) AS avg_order_value
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

CREATE OR REPLACE VIEW vw_revenue_by_state AS
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.order_revenue) AS total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW vw_category_performance AS
SELECT
    p.product_category_name_english AS category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(o.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC;
