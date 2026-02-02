from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.python import get_current_context
from datetime import datetime
import yaml
import utils.etl_util as utils
import queries.p1_ingestion as ingestion_queries # Edit
import queries.p1_quality as quality_queries # Edit
from airflow.models import Variable
from pendulum import timezone

SCHEDULE = Variable.get("p1_schedule", default_var="0 1 5 * *") # Edit
REPROCESS = Variable.get("p1_reprocess", default_var="false").lower() == "true" # Edit
REMAIN_MONTH = int(Variable.get("p1_remain_month", default_var="3")) # Edit

opm_service = "pwa-staging-data"  # Edit

schema_psql_staging = "staging"  # Edit
table_psql_staging = "tbbudgetrequest"  # Edit

conflict_cols_staging = ['budgetrequestid']  # Edit

schema_psql_data_quality = "quality"  # Edit
table_psql_data_quality = "data_quality"  # Edit
schema_psql_good = "good"  # Edit
table_psql_good = "tbbudgetrequest"  # Edit
schema_psql_bad = "bad"  # Edit
table_psql_bad = "tbbudgetrequest"  # Edit
schema_psql_summary = "quality"  # Edit
table_psql_summary = "summary"  # Edit

geometry_cols = ["endlocation", "polygon", "startlocation","position","integrationposition"] # Edit

config_path = ('/opt/airflow/config/config.yaml') 
with open(config_path, 'r') as file:
    config = yaml.safe_load(file)


def convert_date_to_timestamp_fn():
    context = get_current_context()
    conf = context["dag_run"].conf
    start_ts, end_ts = utils.resolve_date_range(conf.get("start_date"), conf.get("end_date"))
    print(f"Converted date range: {start_ts} to {end_ts}")
    ti = context['ti']
    ti.xcom_push(key='ts', value={'start_ts': start_ts, 'end_ts': end_ts})

def transfer_hive_to_postgres_fn():
    context = get_current_context()
    ti = context['ti']
    start_ts = ti.xcom_pull(task_ids = 'extract_date_time', key='ts')['start_ts']
    end_ts = ti.xcom_pull(task_ids = 'extract_date_time', key='ts')['end_ts']
    start_ts_schedule, end_ts_schedule = utils.resolve_date_range(None, None)
    reprocess_query = quality_queries.get_reprocess_query(table_psql_bad, schema_psql_bad, conflict_cols_staging)  
    reprocess_list = utils.fetch_reprocess_list(config, reprocess_query) if REPROCESS else []
    hive_query = ingestion_queries.get_tbBudgetRequest_ingestion_query(start_ts, end_ts, start_ts_schedule, end_ts_schedule, reprocess_list)  # Edit
    table_schema = ingestion_queries.get_tbBudgetRequest_staging_schema()  # Edit
    utils.transfer_hive_to_postgres(table_psql_staging, schema_psql_staging, config, hive_query, table_schema, conflict_cols_staging, geometry_cols)
    

def transfer_staging_to_quality_fn():
    context = get_current_context()
    ti = context['ti']
    start_ts = ti.xcom_pull(task_ids = 'extract_date_time', key='ts')['start_ts']
    end_ts = ti.xcom_pull(task_ids = 'extract_date_time', key='ts')['end_ts']
    run_type = context["dag_run"].run_type
    dq_query = quality_queries.extract_opm_query(config, opm_service, table_psql_staging, schema_psql_staging)  
    dq_df =  utils.extract_data_quality_df(config, dq_query, table_psql_staging)
    staging_df =  utils.extract_staging_raw_df(config, table_psql_staging,schema_psql_staging)
    rule_df =  utils.extract_ref_rule_df(config, schema_psql_data_quality)

    utils.transfer_staging_to_data_quality(config, table_psql_data_quality, schema_psql_data_quality, dq_df)
    utils.transfer_staging_to_good_bad_summary(config, start_ts, end_ts, run_type, REPROCESS, table_psql_staging, table_psql_good, schema_psql_good, table_psql_bad, schema_psql_bad, table_psql_summary, schema_psql_summary,conflict_cols_staging, dq_df, staging_df, rule_df)

def clear_database():
    manual_date_query = quality_queries.get_manual_date_query(table_psql_staging, table_psql_summary, schema_psql_summary)
    manual_start_date, manual_end_date = utils.fetch_manual_date_range(config, manual_date_query)
    manual_start_ts, manual_end_ts = utils.resolve_date_range(manual_start_date, manual_end_date)
    cleanup_staging_query = quality_queries.get_cleanup_staging_query(table_psql_staging, schema_psql_staging)
    cleanup_good_data_query = quality_queries.get_cleanup_good_data_query(table_psql_good, schema_psql_good, manual_start_ts, manual_end_ts, REMAIN_MONTH)
    cleanup_bad_data_query = quality_queries.get_cleanup_bad_data_query(table_psql_bad, schema_psql_bad)
    cleanup_data_quality_query = quality_queries.get_cleanup_data_quality_query(table_psql_data_quality, schema_psql_data_quality)
    utils.execute_cleanup_staging_query(config, cleanup_staging_query)
    utils.execute_cleanup_quality_query(config, cleanup_good_data_query)
    utils.execute_cleanup_quality_query(config, cleanup_bad_data_query)
    utils.execute_cleanup_quality_query(config, cleanup_data_quality_query)


# DAG definition
default_args = {
    'owner': 'airflow',
    'start_date': datetime(2026, 1, 15, tzinfo=timezone('Asia/Bangkok')),
}

with DAG(
    dag_id='dag_tbBudgetRequest', # Edit
    default_args=default_args,
    schedule_interval=SCHEDULE,
    max_active_runs=1,
    catchup=False,
    tags=['hive', 'postgres', 'ETL Pipeline','p1'] # Edit
) as dag:

    convert_date_to_timestamp_task = PythonOperator(
        task_id = 'extract_date_time',
        python_callable = convert_date_to_timestamp_fn,    
        pool = 'shared_pool'
    )
    
    transfer_hive_to_postgres_task = PythonOperator(
        task_id='transfer_hive_to_postgres',
        python_callable=transfer_hive_to_postgres_fn,
        pool = 'shared_pool'
    )
    
    
    transfer_staging_to_quality_task = PythonOperator(
        task_id='transfer_staging_to_quality',
        python_callable=transfer_staging_to_quality_fn,
        pool = 'shared_pool'
    )
    
    clear_database_task = PythonOperator(
        task_id='clear_database',
        python_callable=clear_database,
        pool = 'shared_pool'
    )

    convert_date_to_timestamp_task >> \
    transfer_hive_to_postgres_task >> \
    transfer_staging_to_quality_task >> \
    clear_database_task