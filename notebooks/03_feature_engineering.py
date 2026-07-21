"""
Feature Engineering
Tạo các cột/metric nghiệp vụ mới từ dữ liệu đã làm sạch.
Output: data/processed/*.csv — sẵn sàng để load vào PostgreSQL (Phase 7)
"""
import pandas as pd
import numpy as np

CLEAN = "data/cleaned/"
PROC = "data/processed/"

customers = pd.read_csv(CLEAN + "customers_cleaned.csv", dtype={"customer_zip_code_prefix": str})
orders = pd.read_csv(CLEAN + "orders_cleaned.csv", parse_dates=[
    "order_purchase_timestamp", "order_approved_at",
    "order_delivered_carrier_date", "order_delivered_customer_date",
    "order_estimated_delivery_date"
])
order_items = pd.read_csv(CLEAN + "order_items_cleaned.csv", parse_dates=["shipping_limit_date"])
order_payments = pd.read_csv(CLEAN + "order_payments_cleaned.csv")
order_reviews = pd.read_csv(CLEAN + "order_reviews_cleaned.csv", parse_dates=[
    "review_creation_date", "review_answer_timestamp"
])
products = pd.read_csv(CLEAN + "products_cleaned.csv")
sellers = pd.read_csv(CLEAN + "sellers_cleaned.csv", dtype={"seller_zip_code_prefix": str})

# ========== 1. ORDERS: thêm cột thời gian & delivery ==========
orders["order_month"] = orders["order_purchase_timestamp"].dt.to_period("M").astype(str)
orders["order_year"] = orders["order_purchase_timestamp"].dt.year
orders["order_quarter"] = orders["order_purchase_timestamp"].dt.to_period("Q").astype(str)
orders["order_weekday"] = orders["order_purchase_timestamp"].dt.day_name()
orders["is_weekend_purchase"] = orders["order_purchase_timestamp"].dt.dayofweek.isin([5, 6])

orders["delivery_days"] = (
    orders["order_delivered_customer_date"] - orders["order_purchase_timestamp"]
).dt.days

orders["is_late_delivery"] = (
    orders["order_delivered_customer_date"] > orders["order_estimated_delivery_date"]
).astype("object")
# Với đơn chưa giao (delivered_customer_date null), late = NaN (không xác định được)
orders.loc[orders["order_delivered_customer_date"].isnull(), "is_late_delivery"] = np.nan

orders["is_cancelled"] = orders["order_status"] == "canceled"

# ========== 2. ORDER ITEMS + PAYMENTS -> revenue theo order ==========
item_revenue = order_items.groupby("order_id").agg(
    items_count=("order_item_id", "count"),
    product_revenue=("price", "sum"),
    freight_total=("freight_value", "sum"),
).reset_index()
item_revenue["order_revenue"] = item_revenue["product_revenue"] + item_revenue["freight_total"]

orders = orders.merge(item_revenue, on="order_id", how="left")

# ========== 3. REVIEW SCORE CATEGORY ==========
def score_category(score):
    if pd.isnull(score):
        return np.nan
    if score >= 4:
        return "Positive"
    elif score == 3:
        return "Neutral"
    else:
        return "Negative"

order_reviews["review_score_category"] = order_reviews["review_score"].apply(score_category)

# Gắn review vào orders (1 order có thể có 1 review chủ yếu)
review_per_order = order_reviews.groupby("order_id").agg(
    review_score=("review_score", "mean"),
    review_score_category=("review_score_category", "first"),
).reset_index()
orders = orders.merge(review_per_order, on="order_id", how="left")

# ========== 4. CUSTOMER-LEVEL FEATURES ==========
orders_with_customer = orders.merge(
    customers[["customer_id", "customer_unique_id", "customer_state", "customer_city"]],
    on="customer_id", how="left"
)

customer_orders_count = orders_with_customer.groupby("customer_unique_id")["order_id"].nunique()
orders_with_customer["is_repeat_customer"] = orders_with_customer["customer_unique_id"].map(
    lambda x: customer_orders_count.get(x, 0) > 1
)

# Customer Lifetime Value (tổng revenue của các order hoàn thành, theo customer_unique_id)
clv = (
    orders_with_customer[orders_with_customer["order_status"] == "delivered"]
    .groupby("customer_unique_id")["order_revenue"].sum()
    .reset_index()
    .rename(columns={"order_revenue": "customer_lifetime_value"})
)

orders["is_repeat_customer"] = orders_with_customer["is_repeat_customer"]

# ========== 5. Lưu bảng orders đã enrich (bảng trung tâm - fact table) ==========
orders.to_csv(PROC + "orders_processed.csv", index=False)

# ========== 6. Bảng customers enrich với CLV & order count ==========
customers_processed = customers.merge(clv, on="customer_unique_id", how="left")
customers_processed["customer_lifetime_value"] = customers_processed["customer_lifetime_value"].fillna(0)
customers_processed["total_orders"] = customers_processed["customer_unique_id"].map(customer_orders_count).fillna(0).astype(int)
customers_processed["is_repeat_customer"] = customers_processed["total_orders"] > 1
customers_processed.to_csv(PROC + "customers_processed.csv", index=False)

# ========== 7. Các bảng dimension giữ nguyên (copy sang processed) ==========
order_items.to_csv(PROC + "order_items_processed.csv", index=False)
order_payments.to_csv(PROC + "order_payments_processed.csv", index=False)
order_reviews.to_csv(PROC + "order_reviews_processed.csv", index=False)
products.to_csv(PROC + "products_processed.csv", index=False)
sellers.to_csv(PROC + "sellers_processed.csv", index=False)

# ========== Summary ==========
print("=== FEATURE ENGINEERING SUMMARY ===")
print(f"Orders processed: {len(orders):,}")
print(f"Cột mới trong orders: order_month, order_year, order_quarter, order_weekday, "
      f"is_weekend_purchase, delivery_days, is_late_delivery, is_cancelled, "
      f"items_count, product_revenue, freight_total, order_revenue, "
      f"review_score, review_score_category, is_repeat_customer")
print(f"\nTổng doanh thu (delivered orders): "
      f"R$ {orders[orders['order_status']=='delivered']['order_revenue'].sum():,.2f}")
print(f"Delivery days trung bình: {orders['delivery_days'].mean():.1f} ngày")
print(f"Tỷ lệ giao trễ: {orders['is_late_delivery'].mean()*100:.2f}%")
print(f"Tỷ lệ hủy đơn: {orders['is_cancelled'].mean()*100:.2f}%")
print(f"Số khách hàng mua lại (repeat): {customers_processed['is_repeat_customer'].sum():,} "
      f"/ {customers_processed['customer_unique_id'].nunique():,}")
print("\nĐã lưu 6 bảng vào data/processed/")
