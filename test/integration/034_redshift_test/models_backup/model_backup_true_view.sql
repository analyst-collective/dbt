{{
    config(
        materialized='view', backup=True
    )
}}

select * from {{ ref('seed') }}
