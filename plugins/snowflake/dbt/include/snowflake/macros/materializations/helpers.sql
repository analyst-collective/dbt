{% macro incremental_validate_on_schema_change(on_schema_change, default_value='ignore') %}
   
   {% if on_schema_change not in ['full_refresh', 'sync_all_columns', 'append_new_columns', 'fail', 'ignore'] %}
     
     {% set log_message = 'invalid value for on_schema_change {{ on_schema_change }} specified. Setting default value of {{ default_value }}.' %}
     {% do log(log_message, info=true) %}
     
     {{ return(default_value) }}

   {% else %}
     {{ return(on_schema_change) }}
   
   {% endif %}

{% endmacro %}

{% macro get_column_names(columns) %}

  {% set result = [] %}
  
  {% for col in columns %}
    {{ result.append(col.column) }}
  {% endfor %}
  
  {{ return(result) }}

{% endmacro %}

{% macro snowflake_diff_columns(source_columns, target_columns) %}

  {% set result = [] %}
  {% set source_names = get_column_names(source_columns) %}
  {% set target_names = get_column_names(target_columns) %}
   
   {# check whether the name attribute exists in the target, but dont worry about data type differences #}
   {%- for col in source_columns -%} 
     {%- if col.column not in target_names -%}
      {{ result.append(col) }}
      {%- endif -%}
   {%- endfor -%}
  
  {{ return(result) }}

{% endmacro %}

{% macro check_for_schema_changes(source_relation, target_relation) %}
  
  {% set schema_changed = False %}
  
  {%- set source_columns = adapter.get_columns_in_relation(source_relation) -%}
  {%- set target_columns = adapter.get_columns_in_relation(target_relation) -%}
  {%- set source_not_in_target = snowflake_diff_columns(source_columns, target_columns) -%}
  {%- set target_not_in_source = snowflake_diff_columns(target_columns, source_columns) -%}

  {% if source_not_in_target != [] %}
    {% set schema_changed = True %}
  {% elif target_not_in_source != [] %}
    {% set schema_changed = True %}
  {% endif %}

  {{ return(schema_changed) }}

{% endmacro %}

{% macro sync_schemas(source_relation, target_relation, on_schema_change='append_new_columns') %}
  
  {%- set source_columns = adapter.get_columns_in_relation(source_relation) -%}
  {%- set target_columns = adapter.get_columns_in_relation(target_relation) -%}
  {%- set add_to_target_arr = diff_columns(source_columns, target_columns) -%}
  {%- set remove_from_target_arr = diff_columns(target_columns, source_columns) -%}
  
  -- Validates on_schema_change config vs. whether there are column differences
  {% if on_schema_change=='append_new_columns' and add_to_target_arr == [] %}
    
    {{ 
        exceptions.raise_compiler_error('append_new_columns was set, but no new columns to append. Review the schemas in the source and target relations') 
    }}

  {% endif %}


  {%- if on_schema_change == 'append_new_columns' -%}
   {%- do alter_relation_add_remove_columns(target_relation, add_to_target_arr) -%}
  {% elif on_schema_change == 'sync_all_columns' %}
   {%- do alter_relation_add_remove_columns(target_relation, add_to_target_arr, remove_from_target_arr) -%}
  {% endif %}

  {{ 
      return(
             {
              'columns_added': add_to_target_arr,
              'columns_removed': remove_from_target_arr
             }
          )
  }}
  
{% endmacro %}

{% macro process_schema_changes(on_schema_change, source_relation, target_relation) %}
      
    {% if on_schema_change=='fail' %}
      
      {{ 
        exceptions.raise_compiler_error('The source and target schemas on this incremental model are out of sync!
             You can specify one of ["fail", "ignore", "add_new_columns", "sync_all_columns", "full_refresh"] in the on_schema_change config to control this behavior.
             Please re-run the incremental model with full_refresh set to True to update the target schema.
             Alternatively, you can update the schema manually and re-run the process.') 
      }}
    
    {# unless we ignore, run the sync operation per the config #}
    {% elif on_schema_change != 'ignore' %}
      
      {% set schema_changes = sync_schemas(source_relation, target_relation, on_schema_change) %}
      {% set columns_added = schema_changes['columns_added'] %}
      {% set columns_removed = schema_changes['columns_removed'] %}
      {% do log('columns added: ' + columns_added|join(', '), info=true) %}
      {% do log('columns removed: ' + columns_removed|join(', '), info=true) %}
    
    {% endif %}

{% endmacro %}