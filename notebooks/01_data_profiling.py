"""
Phase 3 - Data Profiling
Kiểm tra missing values, duplicates, invalid values, cardinality
trước khi làm sạch dữ liệu.
"""
import pandas as pd

RAW = "data/raw/"

files = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}

dfs = {name: pd.read_csv(RAW + fname) for name, fname in files.items()}

report_lines = []
report_lines.append("# Phase 3 — Data Profiling Report\n")
report_lines.append("Kiểm tra chất lượng dữ liệu thô (raw) trước khi làm sạch.\n")

for name, df in dfs.items():
    report_lines.append(f"\n## Bảng: `{name}`")
    report_lines.append(f"- Số dòng: **{len(df):,}** | Số cột: **{df.shape[1]}**")

    dup_count = df.duplicated().sum()
    report_lines.append(f"- Số dòng trùng lặp (duplicate rows): **{dup_count:,}**")

    missing = df.isnull().sum()
    missing = missing[missing > 0]
    if len(missing) > 0:
        report_lines.append("- Missing values:")
        for col, cnt in missing.items():
            pct = cnt / len(df) * 100
            report_lines.append(f"  - `{col}`: {cnt:,} ({pct:.2f}%)")
    else:
        report_lines.append("- Missing values: không có")

    report_lines.append("- Kiểu dữ liệu:")
    for col, dtype in df.dtypes.items():
        report_lines.append(f"  - `{col}`: {dtype}")

# ==== Các câu hỏi nghiệp vụ cụ thể (Phase 3 examples) ====
report_lines.append("\n## Trả lời các câu hỏi profiling cụ thể\n")

orders = dfs["orders"]
status_counts = orders["order_status"].value_counts()
report_lines.append("### Phân bố order_status")
for status, cnt in status_counts.items():
    report_lines.append(f"- {status}: {cnt:,}")

cancelled = (orders["order_status"] == "canceled").sum()
report_lines.append(f"\n**Số đơn hàng bị hủy (canceled): {cancelled:,} "
                     f"({cancelled/len(orders)*100:.2f}%)**")

reviews = dfs["order_reviews"]
missing_comment = reviews["review_comment_message"].isnull().sum()
report_lines.append(f"\n**Review thiếu comment message: {missing_comment:,} "
                     f"({missing_comment/len(reviews)*100:.2f}%)**")

products = dfs["products"]
missing_category = products["product_category_name"].isnull().sum()
report_lines.append(f"\n**Sản phẩm thiếu category: {missing_category:,} "
                     f"({missing_category/len(products)*100:.2f}%)**")

customers = dfs["customers"]
orders_customers = orders["customer_id"].nunique()
report_lines.append(f"\n**Số customer_id duy nhất trong orders: {orders_customers:,} "
                     f"/ tổng customers: {len(customers):,}**")
report_lines.append("(Lưu ý: mỗi order có 1 customer_id riêng ngay cả khi cùng "
                     "1 khách mua nhiều lần — cần dùng `customer_unique_id` để "
                     "xác định khách hàng thật sự.)")

unique_customers_real = customers["customer_unique_id"].nunique()
report_lines.append(f"\n**Số khách hàng thật sự (customer_unique_id) duy nhất: "
                     f"{unique_customers_real:,}**")
report_lines.append("→ Cho thấy có khách hàng quay lại mua nhiều lần "
                     "(nhiều customer_id map về cùng 1 customer_unique_id).")

order_items = dfs["order_items"]
orphan_items = order_items[~order_items["order_id"].isin(orders["order_id"])]
report_lines.append(f"\n**Order items không khớp với order nào: {len(orphan_items):,}**")

# Delivery date outlier check
orders["order_purchase_timestamp"] = pd.to_datetime(orders["order_purchase_timestamp"])
orders["order_delivered_customer_date"] = pd.to_datetime(orders["order_delivered_customer_date"])
delivered = orders.dropna(subset=["order_delivered_customer_date"])
delivery_days = (delivered["order_delivered_customer_date"] - delivered["order_purchase_timestamp"]).dt.days
report_lines.append(f"\n**Delivery days — min: {delivery_days.min()}, max: {delivery_days.max()}, "
                     f"mean: {delivery_days.mean():.1f}, median: {delivery_days.median():.1f}**")
negative_delivery = (delivery_days < 0).sum()
report_lines.append(f"**Số đơn có delivery_days âm (bất thường): {negative_delivery:,}**")

with open("reports/Profiling_Report.md", "w", encoding="utf-8") as f:
    f.write("\n".join(report_lines))

print("Đã xuất Profiling_Report.md")
print(f"\nTổng quan nhanh:")
print(f"- Orders: {len(orders):,} | Canceled: {cancelled:,}")
print(f"- Customers (unique_id): {unique_customers_real:,}")
print(f"- Products thiếu category: {missing_category:,}")
print(f"- Delivery days âm: {negative_delivery:,}")
