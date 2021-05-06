{{
    config(
        materialized='table', backup=True
    )
}}

select * from {{ ref('seed') }}
