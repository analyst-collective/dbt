{{
    config(
        materialized='table', backup=False
    )
}}

select * from {{ ref('seed') }}
