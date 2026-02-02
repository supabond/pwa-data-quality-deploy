import requests
import re

def extract_opm_query(config, opm_service, table_psql_staging, schema_psql_staging):
    opm_config = config['openmetadata']
    api_url = f"{opm_config['host']}/api/v1"
    token = opm_config['token']
    database = config['postgres-staging']['database']

    table_fqn = f"{opm_service}.{database}.{schema_psql_staging}.{table_psql_staging}"
    headers = {"Authorization": f"Bearer {token}"}
    entity_link = f"<#E::table::{table_fqn}>"

    endpoint = f"{api_url}/dataQuality/testCases"
    response = requests.get(
        endpoint,
        headers=headers,
        params={"entityLink": entity_link},
        timeout=30
    )
    response.raise_for_status()

    test_cases = response.json().get("data", [])

    dq_cores = []

    for tc in test_cases:
        sql_expression = None

        for param in tc.get("parameterValues", []):
            if param.get("name") == "sqlExpression":
                sql_expression = param.get("value")
                break

        if not sql_expression:
            continue

        match = re.search(
            r"/\*__DQ_CORE_START__\*/(.*?)/\*__DQ_CORE_END__\*/",
            sql_expression,
            re.DOTALL
        )

        if match:
            core_sql = match.group(1).strip()
            dq_cores.append(core_sql)
        else:
            print(f"⚠️ No DQ_CORE found in testCase: {tc.get('name')}")

    if not dq_cores:
        return ""

    union_sql = "\nUNION ALL\n".join(dq_cores)
    opm_query = f"""
        SELECT * FROM (
        {union_sql}
        ) opm_dq_results
        WHERE opm_dq_results.recordstatus = 'DM' OR opm_dq_results.recordstatus = 'RE'
    """

    return opm_query

def get_cleanup_staging_query(table_psql_staging, schema_psql_staging):
    cleanup_query = f"""
        DELETE FROM {schema_psql_staging}.{table_psql_staging}
        WHERE NOT (
            (
                CreatedDate >= date_trunc('month', now()) - interval '1 month'
                AND CreatedDate <  date_trunc('month', now())
            )
            OR
            (
                UpdatedDate >= date_trunc('month', now()) - interval '1 month'
                AND UpdatedDate <  date_trunc('month', now())
            )
        );
    """
    return cleanup_query

def get_cleanup_good_data_query(table_psql_good, schema_psql_good, manual_start_ts, manual_end_ts, remain_month):
    cleanup_query = f"""
        DELETE FROM {schema_psql_good}.{table_psql_good}
        WHERE NOT ( flag = TRUE AND (
            (
                CreatedDate >= date_trunc('month', now()) - interval '{remain_month} month'
                AND CreatedDate <  date_trunc('month', now())
            )
            OR
            (
                UpdatedDate >= date_trunc('month', now()) - interval '{remain_month} month'
                AND UpdatedDate <  date_trunc('month', now())
            )
            OR
            (
                CreatedDate >= TIMESTAMP '{manual_start_ts}' 
                AND CreatedDate <  TIMESTAMP '{manual_end_ts}' 
            )
            OR
            (
                UpdatedDate >= TIMESTAMP '{manual_start_ts}' 
                AND UpdatedDate <  TIMESTAMP '{manual_end_ts}'
            )
        ));
    """
    return cleanup_query

def get_cleanup_bad_data_query(table_psql_bad, schema_psql_bad):
    cleanup_query = f"""
        DELETE FROM {schema_psql_bad}.{table_psql_bad}
        WHERE flag = TRUE;
    """
    return cleanup_query

def get_cleanup_data_quality_query(table_psql_data_quality, schema_psql_data_quality):
    cleanup_query = f"""
        DELETE FROM {schema_psql_data_quality}.{table_psql_data_quality}
        WHERE recordcount = 0;
    """
    return cleanup_query

def get_manual_date_query(table_psql_staging, table_psql_summary, schema_psql_summary):
    manual_date_query = f"""
        SELECT 
            ingest_start_date, ingest_end_date
        FROM {schema_psql_summary}.{table_psql_summary}
        WHERE table_name = '{table_psql_staging}' AND trigger_type = 'manual'
        ORDER BY trigger_timestamp DESC
        LIMIT 1;
    """
    return manual_date_query

def get_reprocess_query(table_psql_bad, schema_psql_bad, conflict_cols_staging):
    cols = ", ".join(conflict_cols_staging)
    return f"""
SELECT
    {cols}
FROM {schema_psql_bad}.{table_psql_bad}
"""
