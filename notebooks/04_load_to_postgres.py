"""
pip install sqlalchemy psycopg2-binary pandas
python 04_load_to_postgres.py
"""
import pandas as pd
from sqlalchemy import create_engine, text

from dotenv import load_dotenv
import os

# ============ CẬP NHẬT THÔNG TIN KẾT NỐI CỦA BẠN ============
load_dotenv()

DB_CONFIG = {
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT"),
    "database": os.getenv("DB_NAME"),
}
# ==============================================================

PROC = "data/processed/"   
CLEAN = "data/cleaned/"   
engine = create_engine(
    f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
    f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
)

# Thứ tự load QUAN TRỌNG — phải theo đúng thứ tự để không vi phạm Foreign Key:
# customers, sellers, products  ->  orders  ->  order_items, order_payments, order_reviews  ->  geolocation
load_plan = [
    ("customers",      PROC + "customers_processed.csv"),
    ("sellers",        PROC + "sellers_processed.csv"),
    ("products",       PROC + "products_processed.csv"),
    ("orders",         PROC + "orders_processed.csv"),
    ("order_items",    PROC + "order_items_processed.csv"),
    ("order_payments", PROC + "order_payments_processed.csv"),
    ("order_reviews",  PROC + "order_reviews_processed.csv"),
    ("geolocation",    CLEAN + "geolocation_cleaned.csv"),
]

with engine.connect() as conn:
    for table_name, csv_path in load_plan:
        print(f"Đang load {table_name} từ {csv_path} ...")
        df = pd.read_csv(csv_path)

        # Xóa dữ liệu cũ trong bảng trước khi load (idempotent — chạy lại không bị lỗi trùng PK)
        conn.execute(text(f"TRUNCATE TABLE {table_name} CASCADE"))
        conn.commit()

        df.to_sql(table_name, engine, if_exists="append", index=False, method="multi", chunksize=5000)
        print(f"  -> Đã load {len(df):,} dòng vào bảng '{table_name}'")

print("\n✅ Hoàn tất load dữ liệu vào PostgreSQL!")

# ============ Kiểm tra nhanh sau khi load ============
with engine.connect() as conn:
    print("\n=== Kiểm tra số dòng mỗi bảng ===")
    for table_name, _ in load_plan:
        count = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}")).scalar()
        print(f"{table_name}: {count:,} dòng")
