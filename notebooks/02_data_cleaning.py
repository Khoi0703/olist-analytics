"""
Phase 4 - Data Cleaning
- Convert timestamps
- Xử lý missing values
- Xóa duplicate
- Chuẩn hóa category names, payment types
- Validate ID
- Xử lý order bị cancelled (giữ lại, gắn flag, không xóa để không mất dữ liệu lịch sử)
"""
import pandas as pd
import numpy as np

RAW = "data/raw/"
CLEAN = "data/cleaned/"

# ---------- Load ----------
customers = pd.read_csv(RAW + "olist_customers_dataset.csv")
geolocation = pd.read_csv(RAW + "olist_geolocation_dataset.csv")
order_items = pd.read_csv(RAW + "olist_order_items_dataset.csv")
order_payments = pd.read_csv(RAW + "olist_order_payments_dataset.csv")
order_reviews = pd.read_csv(RAW + "olist_order_reviews_dataset.csv")
orders = pd.read_csv(RAW + "olist_orders_dataset.csv")
products = pd.read_csv(RAW + "olist_products_dataset.csv")
sellers = pd.read_csv(RAW + "olist_sellers_dataset.csv")
category_translation = pd.read_csv(RAW + "product_category_name_translation.csv")

log = []

# ========== 1. CUSTOMERS ==========
before = len(customers)
customers = customers.drop_duplicates(subset="customer_id")
customers["customer_zip_code_prefix"] = customers["customer_zip_code_prefix"].astype(str)
customers["customer_city"] = customers["customer_city"].str.strip().str.title()
customers["customer_state"] = customers["customer_state"].str.strip().str.upper()
log.append(f"customers: {before} -> {len(customers)} dòng sau khi bỏ duplicate")

# ========== 2. GEOLOCATION ==========
before = len(geolocation)
geolocation = geolocation.drop_duplicates()
geolocation["geolocation_zip_code_prefix"] = geolocation["geolocation_zip_code_prefix"].astype(str)
geolocation["geolocation_city"] = geolocation["geolocation_city"].str.strip().str.title()
geolocation["geolocation_state"] = geolocation["geolocation_state"].str.strip().str.upper()
# Loại tọa độ rõ ràng sai (ngoài phạm vi Brazil: lat -34..6, lng -74..-32)
before_geo = len(geolocation)
geolocation = geolocation[
    geolocation["geolocation_lat"].between(-34, 6) &
    geolocation["geolocation_lng"].between(-74, -32)
]
log.append(f"geolocation: {before} -> {len(geolocation)} dòng "
           f"(bỏ duplicate + {before_geo - len(geolocation)} tọa độ ngoài Brazil)")

# ========== 3. ORDERS ==========
before = len(orders)
orders = orders.drop_duplicates(subset="order_id")

timestamp_cols = [
    "order_purchase_timestamp", "order_approved_at",
    "order_delivered_carrier_date", "order_delivered_customer_date",
    "order_estimated_delivery_date"
]
for col in timestamp_cols:
    orders[col] = pd.to_datetime(orders[col], errors="coerce")

orders["order_status"] = orders["order_status"].str.strip().str.lower()
log.append(f"orders: {before} -> {len(orders)} dòng, convert {len(timestamp_cols)} cột sang datetime")
log.append(f"orders: order_status đã chuẩn hóa lowercase, giữ lại toàn bộ order kể cả "
           f"canceled/unavailable (không xóa để không mất dữ liệu lịch sử — sẽ gắn flag ở Phase 5)")

# ========== 4. ORDER ITEMS ==========
before = len(order_items)
order_items = order_items.drop_duplicates()
order_items["shipping_limit_date"] = pd.to_datetime(order_items["shipping_limit_date"], errors="coerce")
# Validate: order_id phải tồn tại trong orders
order_items = order_items[order_items["order_id"].isin(orders["order_id"])]
# Validate: price/freight không âm
order_items = order_items[(order_items["price"] >= 0) & (order_items["freight_value"] >= 0)]
log.append(f"order_items: {before} -> {len(order_items)} dòng "
           f"(bỏ duplicate, orphan order_id, giá trị âm)")

# ========== 5. ORDER PAYMENTS ==========
before = len(order_payments)
order_payments = order_payments.drop_duplicates()
order_payments["payment_type"] = order_payments["payment_type"].str.strip().str.lower()
order_payments = order_payments[order_payments["order_id"].isin(orders["order_id"])]
order_payments = order_payments[order_payments["payment_value"] >= 0]
log.append(f"order_payments: {before} -> {len(order_payments)} dòng "
           f"(chuẩn hóa payment_type, bỏ orphan/giá trị âm)")

# ========== 6. ORDER REVIEWS ==========
before = len(order_reviews)
order_reviews = order_reviews.drop_duplicates(subset="review_id")
for col in ["review_creation_date", "review_answer_timestamp"]:
    order_reviews[col] = pd.to_datetime(order_reviews[col], errors="coerce")
# Giữ nguyên comment message rỗng = NaN (khách không để lại comment, đây là thông tin hợp lệ)
order_reviews = order_reviews[order_reviews["order_id"].isin(orders["order_id"])]
order_reviews = order_reviews[order_reviews["review_score"].between(1, 5)]
log.append(f"order_reviews: {before} -> {len(order_reviews)} dòng "
           f"(bỏ duplicate review_id, orphan order_id, review_score ngoài 1-5)")

# ========== 7. PRODUCTS ==========
before = len(products)
products = products.drop_duplicates(subset="product_id")
products["product_category_name"] = products["product_category_name"].str.strip()
# Điền category thiếu bằng "unknown" thay vì xóa (tránh mất dữ liệu order_items liên quan)
missing_cat = products["product_category_name"].isnull().sum()
products["product_category_name"] = products["product_category_name"].fillna("unknown")
# Merge tên tiếng Anh
products = products.merge(category_translation, on="product_category_name", how="left")
products["product_category_name_english"] = products["product_category_name_english"].fillna("unknown")
# Điền số đo thiếu bằng median (không xóa sản phẩm)
numeric_cols = ["product_name_lenght", "product_description_lenght", "product_photos_qty",
                "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"]
for col in numeric_cols:
    products[col] = products[col].fillna(products[col].median())
log.append(f"products: {before} -> {len(products)} dòng, "
           f"điền {missing_cat} category thiếu = 'unknown', merge tên tiếng Anh, "
           f"điền missing numeric bằng median")

# ========== 8. SELLERS ==========
before = len(sellers)
sellers = sellers.drop_duplicates(subset="seller_id")
sellers["seller_zip_code_prefix"] = sellers["seller_zip_code_prefix"].astype(str)
sellers["seller_city"] = sellers["seller_city"].str.strip().str.title()
sellers["seller_state"] = sellers["seller_state"].str.strip().str.upper()
log.append(f"sellers: {before} -> {len(sellers)} dòng sau khi bỏ duplicate")

# ========== Save cleaned data ==========
customers.to_csv(CLEAN + "customers_cleaned.csv", index=False)
geolocation.to_csv(CLEAN + "geolocation_cleaned.csv", index=False)
orders.to_csv(CLEAN + "orders_cleaned.csv", index=False)
order_items.to_csv(CLEAN + "order_items_cleaned.csv", index=False)
order_payments.to_csv(CLEAN + "order_payments_cleaned.csv", index=False)
order_reviews.to_csv(CLEAN + "order_reviews_cleaned.csv", index=False)
products.to_csv(CLEAN + "products_cleaned.csv", index=False)
sellers.to_csv(CLEAN + "sellers_cleaned.csv", index=False)

with open("reports/Cleaning_Log.md", "w", encoding="utf-8") as f:
    f.write("# Phase 4 — Data Cleaning Log\n\n")
    f.write("\n".join(f"- {line}" for line in log))

print("\n".join(log))
print("\nĐã lưu 8 bảng đã làm sạch vào data/cleaned/")
