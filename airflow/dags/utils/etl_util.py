# utils/convert_columns_to_schema.py
from datetime import date, datetime, timedelta
from shapely import wkt, wkb
from shapely.errors import WKTReadingError
import pandas as pd
from sqlalchemy import create_engine,  cast, String, func, text
from sqlalchemy.dialects.postgresql import insert
import jaydebeapi
import gc
import pendulum
from geoalchemy2 import Geography # ต้องติดตั้ง GeoAlchemy2==0.11.1

CHUNK_SIZE = 10000  


def get_shapely_geom(value):
    if not value or value.strip() == "": return None
    
    # ตัด 0x ออกถ้ามี และแปลง hex เป็น bytes
    hex_data = value[2:] if value.lower().startswith("0x") else value
    b = bytes.fromhex(hex_data)
    
    # loads จะอ่าน EWKB ที่มี SRID ติดมาด้วยได้โดยตรง (Shapely 2.0+)
    geom = wkb.loads(b) 
    return geom


def safe_wkt(value):
    if not value or value.strip() == "":
        return None
    try:
        b = bytes.fromhex(value[2:] if value.lower().startswith("0x") else value)
        geom = wkb.loads(b, hex=False)  # 2D only
        return geom.wkt
    except:
        return None


def convert_columns_to_schema(df, table_schema):
    
    # Comparative (postgres --> dataframe)
    # Varchar, Bigint --> STRING
    # Integer --> INTEGER
    # Numeric, Decimal --> FLOAT
    # Date, Timestamp --> TIMESTAMP
    # Boolean --> BOOLEAN
    
    df_copy = df.copy()
    # Lowercase all column names
    df_copy.columns = [c.lower() for c in df_copy.columns]
    
    for col in table_schema:
        col_name = col['name'].lower()
        col_type = col['type'].upper()
        
        if col_name not in df_copy.columns:
            # ถ้า column ไม่มีใน DataFrame ให้ข้าม
            continue
        elif col_type == "BOOLEAN":
            df_copy[col_name] = df_copy[col_name].astype('boolean')
        elif col_type == "STRING":
            s = df_copy[col_name].astype("string").str.strip()
            df_copy[col_name] = s.replace("", pd.NA)
        elif col_type == "INT":
            df_copy[col_name] = pd.to_numeric(df_copy[col_name], errors='coerce').astype('Int64')
        elif col_type == "FLOAT":
            df_copy[col_name] = pd.to_numeric(df_copy[col_name], errors='coerce').astype(float)
        elif col_type == "TIMESTAMP":
            df_copy[col_name] = pd.to_datetime(df_copy[col_name], errors='coerce')
        else:
            raise ValueError(f"Unsupported type '{col_type}' for column '{col_name}'")
    
    return df_copy



def resolve_date_range(start_date=None, end_date=None):
    """
    start_date, end_date: 'YYYY-MM-DD' หรือ None
    return:
      start_date: 'YYYY-MM-DD'
      end_date_plus_1: 'YYYY-MM-DD'  (end_date + 1 day)
    """

    # ถ้ามีตัวใดตัวหนึ่งเป็น None → ใช้เดือนที่แล้วทั้งคู่
    if not start_date or not end_date:
        today = date.today()
        first_this_month = today.replace(day=1)
        last_month_end = first_this_month - timedelta(days=1)
        last_month_start = last_month_end.replace(day=1)

        end_plus_1 = last_month_end + timedelta(days=1)

        return (
            f"{last_month_start.isoformat()} 00:00:00",
            f"{end_plus_1.isoformat()} 00:00:00"
        )

    # แปลง end_date + 1 วัน
    end_plus_1 = (
        datetime.strptime(end_date, "%Y-%m-%d").date()
        + timedelta(days=1)
    )

    return f"{start_date} 00:00:00", f"{end_plus_1.isoformat()} 00:00:00"

def fetch_reprocess_list(config, reprocess_query):
    
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
        "?sslmode=require"
    )
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    reprocess_list = []
    with pg_quality_engine.connect() as conn:
        result = conn.execute(reprocess_query)
        for row in result.fetchall():
            reprocess_list.append(tuple(row))
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()
    
    print(f"✅ Fetched {len(reprocess_list)} records for reprocessing.")
    return reprocess_list

def normalize_hex_wkb(value):
        """
        Normalize EWKB hex:
        - remove 0x
        - remove SRID prefix (E6100000) if exists
        """
        hex_value = value.lower().replace("0x", "")

        # EWKB with SRID prefix (E6100000 = SRID 4326)
        if hex_value.startswith("e6100000"):
            hex_value = hex_value[8:]  # strip SRID prefix

        return hex_value



def make_upsert_method(conflict_cols, geom_cols=None):

    def upsert_method(table, conn, keys, data_iter):
        real_table = table.table
        processed_data = []

        for row in data_iter:
            row_dict = dict(zip(keys, row))

            if geom_cols:
                for col in geom_cols:
                    geom_value = row_dict.get(col)

                    if geom_value and isinstance(geom_value, str):
                        clean_hex = geom_value.lower().replace('0x', '')
                        if len(clean_hex) >= 12:
                            # 1. ประกอบ Hex ใหม่
                            fixed_hex = '0101000020e6100000' + clean_hex[12:]
                            
                            # 2. แปลงเป็น Geometry -> สลับพิกัด (Flip) -> Cast เป็น Geography
                            row_dict[col] = (
                                func.ST_FlipCoordinates(
                                    func.ST_GeomFromEWKB(func.decode(fixed_hex, 'hex'))
                                ).cast(Geography)
                            )

                            
                    else:
                        row_dict[col] = None

            processed_data.append(row_dict)

        stmt = insert(real_table).values(processed_data)

        update_dict = {
            col.name: stmt.excluded[col.name]
            for col in real_table.columns
            if col.name not in conflict_cols
        }

        stmt = stmt.on_conflict_do_update(
            index_elements=conflict_cols,
            set_=update_dict
        )

        conn.execute(stmt)

    return upsert_method



def extract_data_quality_df(config, dq_query, table_psql_staging):
    pg_staging_conf = config['postgres-staging']
    pg_staging_conn_str = (
        f"postgresql+psycopg2://{pg_staging_conf['user']}:{pg_staging_conf['password']}"
        f"@{pg_staging_conf['host']}:{pg_staging_conf['port']}/{pg_staging_conf['database']}"
    )
    pg_staging_engine = create_engine(pg_staging_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    data_list = []
    with pg_staging_engine.connect() as conn:
        result = conn.execute(dq_query)
        columns = result.keys()
        for row in result.fetchall():
            data_list.append(dict(zip(columns, row)))
            
    dq_df = pd.DataFrame(data_list)
    
    if pg_staging_engine is not None: pg_staging_engine.dispose()
    gc.collect()
    
    print(f"✅ Extracted data quality DataFrame with {len(dq_df)} rows from {table_psql_staging}.")
    print( dq_df.head(5) )
    return dq_df

def extract_staging_raw_df(config, table_psql_staging, schema_psql_staging):
    pg_staging_conf = config['postgres-staging']
    pg_staging_conn_str = (
        f"postgresql+psycopg2://{pg_staging_conf['user']}:{pg_staging_conf['password']}"
        f"@{pg_staging_conf['host']}:{pg_staging_conf['port']}/{pg_staging_conf['database']}"
    )
    pg_staging_engine = create_engine(pg_staging_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    data_list = []
    with pg_staging_engine.connect() as conn:
        result = conn.execute(text(f"SELECT * FROM {schema_psql_staging}.{table_psql_staging};"))
        columns = result.keys()
        for row in result.fetchall():
            data_list.append(dict(zip(columns, row)))
            
    staging_raw_df = pd.DataFrame(data_list)
    
    if pg_staging_engine is not None: pg_staging_engine.dispose()
    gc.collect()
    
    print(f"✅ Extracted staging raw DataFrame with {len(staging_raw_df)} rows from {table_psql_staging}.")
    print( staging_raw_df.head(5) )
    return staging_raw_df

def extract_ref_rule_df(config, schema_psql_data_quality):
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
    )
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    data_list = []
    with pg_quality_engine.connect() as conn:
        result = conn.execute(text(f"SELECT * FROM {schema_psql_data_quality}.ref_rule;")) # Edit
        columns = result.keys()
        for row in result.fetchall():
            data_list.append(dict(zip(columns, row)))
            
    rule_df = pd.DataFrame(data_list)
    
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()
    
    print(f"✅ Extracted reference rule DataFrame with {len(rule_df)} rows from ref_business_rule.")
    print( rule_df.head(5) )
    return rule_df

def transfer_hive_to_postgres(hive_config,table_psql_staging, schema_psql_staging, config, hive_query, table_schema, conflict_cols_staging, geometry_cols):
    
    hive_conf = config[hive_config]
    conn_hive = None
    cursor = None
    
    try:
        conn_hive = jaydebeapi.connect(
            hive_conf['driver'],
            hive_conf['jdbc_url'],
            [hive_conf['user'], hive_conf['password']],
            jars=hive_conf['jar_path']
        )
        
        cursor = conn_hive.cursor()
        cursor.execute(hive_query)
        
        columns = [desc[0] for desc in cursor.description]
        
        data_list = []
        while True:
            chunk = cursor.fetchmany(CHUNK_SIZE)
            if not chunk:
                break
            data_list.extend(chunk)
        
        df = pd.DataFrame(data_list, columns=columns)
            
    finally:
        if cursor:
            cursor.close()
        if conn_hive:
            conn_hive.close()
        gc.collect()  # บังคับ garbage collection

    df = convert_columns_to_schema(df, table_schema)
    
    pg_staging_conf = config['postgres-staging']
    pg_conn_str = (
        f"postgresql+psycopg2://{pg_staging_conf['user']}:{pg_staging_conf['password']}"
        f"@{pg_staging_conf['host']}:{pg_staging_conf['port']}/{pg_staging_conf['database']}"
    )

    pg_engine = create_engine(pg_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)

    df.dropna(subset=conflict_cols_staging, inplace=True)
    row_count = len(df)
    print(f"✅ Row count before insert: {row_count}")

    upsert_fn = make_upsert_method(conflict_cols_staging, geometry_cols)
    with pg_engine.begin() as conn:
        conn.execute( text(f"TRUNCATE TABLE {schema_psql_staging}.{table_psql_staging};") )
        if not df.empty:
            df.to_sql(name=table_psql_staging, schema=schema_psql_staging, con=conn,  if_exists='append', index=False, method=upsert_fn, chunksize=5000)
            print(f"✅ Upserted {row_count} rows into {table_psql_staging}")
        else:
            print("⚠️ No data to transfer.")

    del df
    if pg_engine:
        pg_engine.dispose()
    gc.collect()
    
    
def transfer_staging_to_data_quality(config, table_psql_quality, schema_psql_quality, dq_df):
    
    conflict_cols_data_quality = ['uid', 'rule_id']
    
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
        "?sslmode=require"
    )
    
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    upsert_fn = make_upsert_method(conflict_cols_data_quality)
    
    if not dq_df.empty:
        dq_df_final = dq_df.drop(columns=['recordstatus'])
    else:
        dq_df_final = dq_df.copy()
    
    if not dq_df.empty:
        with pg_quality_engine.begin() as conn:
            dq_df_final.to_sql(name=table_psql_quality, schema=schema_psql_quality, con=conn, if_exists='append', index=False, method=upsert_fn, chunksize=5000)      
        print(f"✅ Upserted {len(dq_df_final)} rows into {table_psql_quality}")
    else:
        print("⚠️ No data to transfer.")
    del dq_df_final
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()
    

def transfer_staging_to_good_bad_summary(config,  start_ts, end_ts, run_type, REPROCESS, table_psql_staging, table_psql_good, schema_psql_good, table_psql_bad, schema_psql_bad, table_psql_summary, schema_psql_summary, conflict_cols_staging, dq_df, staging_df, rule_df):
    
    #------------------------------ good/bad ---------------------------------#
    
    is_df_empty = dq_df.empty or staging_df.empty or rule_df.empty
    
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
        "?sslmode=require"
    )
    
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    if not is_df_empty:
        
        upsert_fn = make_upsert_method(conflict_cols_staging)
        
        dq_merge_rule_df = dq_df.merge(
            rule_df,
            on='rule_id',
            how='left',
        )
        
        dq_merge_rule_df["has_error"] = dq_merge_rule_df["recordcount"] > 0
        
        print(dq_merge_rule_df.columns)
        
        uid_flag_status_df = (
            dq_merge_rule_df
            .groupby("uid", dropna=False)
            .agg(
                recordcount=("recordcount", "sum"),
                errordescriptions=(
                    "invalid_condition",
                    lambda x: ", ".join(
                        x[dq_merge_rule_df.loc[x.index, "has_error"]].astype(str).unique()
                    )
                ),
                recordstatus=("recordstatus", "first")
            )
            .reset_index()
        )
        
        uid_flag_status_df["flag"] = uid_flag_status_df["recordcount"] == 0
        uid_flag_status_df = uid_flag_status_df[["uid", "flag", "errordescriptions", "recordstatus"]]
        
        # print(uid_flag_status_df.head(10))
        
        staging_merge_ufs_df = staging_df.merge(
            uid_flag_status_df[['uid', 'flag', 'errordescriptions']],
            left_on=conflict_cols_staging,
            right_on=['uid'],
            how='left',
        )
        
        if not staging_merge_ufs_df.empty:
            good_df = staging_merge_ufs_df[staging_merge_ufs_df['flag'] == True].copy()
            bad_df = staging_merge_ufs_df[staging_merge_ufs_df['flag'] == False].copy()
            
            good_df.drop(columns=['uid'], inplace=True)
            bad_df.drop(columns=['uid'], inplace=True)
            
            if not good_df.empty:
                with pg_quality_engine.begin() as conn:
                    good_df.to_sql(name=table_psql_good, schema=schema_psql_good, con=conn, if_exists='append', index=False, method=upsert_fn, chunksize=5000)
                print(f"✅ Upserted {len(good_df)} rows into {table_psql_good}")
            else:
                print("⚠️ No good data to transfer.")
                
            if not bad_df.empty:
                with pg_quality_engine.begin() as conn:
                    bad_df.to_sql(name=table_psql_bad, schema=schema_psql_bad, con=conn, if_exists='append', index=False, method=upsert_fn, chunksize=5000)
                print(f"✅ Upserted {len(bad_df)} rows into {table_psql_bad}")
            else:
                print("⚠️ No bad data to transfer.")
            
            del good_df
            del bad_df

        #------------------------------ summary ---------------------------------#
        
        right_summary_1_df = (
            dq_merge_rule_df
            .groupby(
                ["dataset_id", "business_rule_id", "uid"],
                dropna=False
            )
            .agg(
                flag=("recordcount", lambda x: x.sum() > 0),
                recordstatus=("recordstatus", "first")
            )
            .reset_index()
        )
    
        right_summary_2_df = (
            right_summary_1_df
            .groupby(["dataset_id","business_rule_id"], dropna=False)
            .agg(
                failcount=("flag", lambda x: ((x == True) & (right_summary_1_df.loc[x.index, "recordstatus"] != 'RE')).sum()),
                reprocess_failcount=("flag", lambda x: ((x == True) & (right_summary_1_df.loc[x.index, "recordstatus"] == 'RE')).sum()),
            )   
            .reset_index()
        )
    
    start_ts = pendulum.parse(start_ts, tz="Asia/Bangkok")
    end_ts = pendulum.parse(end_ts, tz="Asia/Bangkok")
    now_ts = pendulum.now("Asia/Bangkok")
    
    left_summary_df = pd.DataFrame([{
        "trigger_id": f"{table_psql_staging}_{now_ts.format('YYYYMMDDHHmmssSSS')}",
        "trigger_timestamp": now_ts.naive(),
        "trigger_type": run_type,
        "reprocess": REPROCESS,
        "ingest_start_date": start_ts.date(),
        "ingest_end_date": end_ts.subtract(days=1).date(),
        "ingest_year": None if run_type == "manual" else start_ts.year,
        "ingest_month": None if run_type == "manual" else start_ts.month,
        "table_name": table_psql_staging,
        "goodcount": 0 if is_df_empty else ((uid_flag_status_df["flag"] == True) & (uid_flag_status_df["recordstatus"] == "DM")).sum(),
        "badcount": 0 if is_df_empty else ((uid_flag_status_df["flag"] == False) & (uid_flag_status_df["recordstatus"] == "DM")).sum(),
        "reprocess_goodcount": 0 if is_df_empty else ((uid_flag_status_df["flag"] == True) & (uid_flag_status_df["recordstatus"] == "RE")).sum(),
        "reprocess_badcount": 0 if is_df_empty else ((uid_flag_status_df["flag"] == False) & (uid_flag_status_df["recordstatus"] == "RE")).sum(),
    }])
        
    if is_df_empty:
        right_summary_2_df = pd.DataFrame([{
            "dataset_id": None,
            "business_rule_id": None,
            "failcount": 0,
            "reprocess_failcount": 0,
        }])
    
    cross_summary_df = left_summary_df.merge(
        right_summary_2_df,
        how='cross'
    )
    
    print(cross_summary_df.head(5))
    
    with pg_quality_engine.begin() as conn:
        cross_summary_df.to_sql(name=table_psql_summary, schema=schema_psql_summary, con=conn, if_exists='append', index=False, chunksize=5000)
    print(f"✅ Inserted {len(cross_summary_df)} rows into {schema_psql_summary}.{table_psql_summary}")

    if not is_df_empty:
        del staging_merge_ufs_df
        del dq_merge_rule_df
        del uid_flag_status_df
        del left_summary_df
        del right_summary_1_df
        del right_summary_2_df
    del cross_summary_df
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()
    
        
    
def fetch_manual_date_range(config, manual_date_query):
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
        "?sslmode=require"
    )
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    manual_start_date_string = None
    manual_end_date_string = None
    with pg_quality_engine.connect() as conn:
        result = conn.execute(manual_date_query)
        row = result.fetchone()
        if row:
            manual_start_date_string = row['ingest_start_date']
            manual_end_date_string = row['ingest_end_date']
        else:
            manual_start_date_string = '1980-01-01'
            manual_end_date_string = '1980-01-01'
    
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()
    #convert to string before return
    manual_end_date_string = str(manual_end_date_string)
    manual_start_date_string = str(manual_start_date_string)
    print(f"✅ Fetched manual date range: {manual_start_date_string} to {manual_end_date_string}")
    return manual_end_date_string, manual_start_date_string

def execute_cleanup_staging_query(config, cleanup_query):
    pg_staging_conf = config['postgres-staging']
    pg_staging_conn_str = (
        f"postgresql+psycopg2://{pg_staging_conf['user']}:{pg_staging_conf['password']}"
        f"@{pg_staging_conf['host']}:{pg_staging_conf['port']}/{pg_staging_conf['database']}"
    )
    pg_staging_engine = create_engine(pg_staging_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    with pg_staging_engine.begin() as conn:
        conn.execute(cleanup_query)
        print("✅ Executed cleanup staging query.")
    
    if pg_staging_engine is not None: pg_staging_engine.dispose()
    gc.collect()

def execute_cleanup_quality_query(config, cleanup_query):
    pg_quality_conf = config['postgres-quality']
    pg_quality_conn_str = (
        f"postgresql+psycopg2://{pg_quality_conf['user']}:{pg_quality_conf['password']}"
        f"@{pg_quality_conf['host']}:{pg_quality_conf['port']}/{pg_quality_conf['database']}"
        "?sslmode=require"
    )
    pg_quality_engine = create_engine(pg_quality_conn_str, pool_pre_ping=True, pool_recycle=3600, pool_size=5, max_overflow=10)
    
    with pg_quality_engine.begin() as conn:
        conn.execute(cleanup_query)
        print("✅ Executed cleanup query.")
    
    if pg_quality_engine is not None: pg_quality_engine.dispose()
    gc.collect()