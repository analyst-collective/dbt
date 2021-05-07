{% macro run_hooks(hooks, inside_transaction=True) %}
  {% for hook in hooks | selectattr('transaction', 'equalto', inside_transaction)  %}
    {% if not inside_transaction and loop.first %}
      {% call statement(auto_begin=inside_transaction) %}
        commit;
      {% endcall %}
    {% endif %}
    {% set rendered = render(hook.get('sql')) | trim %}
    {% if (rendered | length) > 0 %}
      {% call statement(auto_begin=inside_transaction) %}
        {{ rendered }}
      {% endcall %}
    {% endif %}
  {% endfor %}
{% endmacro %}


{% macro column_list(columns) %}
  {%- for col in columns %}
    {{ col.name }} {% if not loop.last %},{% endif %}
  {% endfor -%}
{% endmacro %}


{% macro column_list_for_create_table(columns) %}
  {%- for col in columns %}
    {{ col.name }} {{ col.data_type }} {%- if not loop.last %},{% endif %}
  {% endfor -%}
{% endmacro %}


{% macro make_hook_config(sql, inside_transaction) %}
    {{ tojson({"sql": sql, "transaction": inside_transaction}) }}
{% endmacro %}


{% macro before_begin(sql) %}
    {{ make_hook_config(sql, inside_transaction=False) }}
{% endmacro %}


{% macro in_transaction(sql) %}
    {{ make_hook_config(sql, inside_transaction=True) }}
{% endmacro %}


{% macro after_commit(sql) %}
    {{ make_hook_config(sql, inside_transaction=False) }}
{% endmacro %}


{% macro drop_relation_if_exists(relation) %}
  {% if relation is not none %}
    {{ adapter.drop_relation(relation) }}
  {% endif %}
{% endmacro %}


{% macro load_relation(relation) %}
  {% do return(adapter.get_relation(
    database=relation.database,
    schema=relation.schema,
    identifier=relation.identifier
  )) -%}
{% endmacro %}


{% macro should_full_refresh() %}
  {% set config_full_refresh = config.get('full_refresh') %}
  {% if config_full_refresh is none %}
    {% set config_full_refresh = flags.FULL_REFRESH %}
  {% endif %}
  {% do return(config_full_refresh) %}
{% endmacro %}


{% macro incremental_validate_on_schema_change(on_schema_change, default_value='ignore') %}
   
   {% if on_schema_change not in ['full_refresh', 'sync_all_columns', 'append_new_columns', 'fail', 'ignore'] %}
     
     {% set log_message = 'invalid value for on_schema_change {{ on_schema_change }} specified. Setting default value of {{ default_value }}.' %}
     {% do log(log_message, debug=true) %}
     
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

{% macro diff_columns(source_columns, target_columns) %}

  {% set result = [] %}
  {% set source_names = get_column_names(source_columns) %}
  {% set target_names = get_column_names(target_columns) %}
   
   {# check whether the name attribute exists in the target, but dont worry about data type differences #}
   {%- for col in source_columns -%} 
     {%- if col.name not in target_names -%}
      {{ result.append(col) }}
      {%- endif -%}
   {%- endfor -%}
  
  {{ return(result) }}

{% endmacro %}

{% macro check_for_schema_changes(source_relation, target_relation) %}
  
  {% set schema_changed = False %}
  {%- set source_columns = adapter.get_columns_in_relation(source_relation) -%}
  {%- set target_columns = adapter.get_columns_in_relation(target_relation) -%}
  {%- set source_not_in_target = diff_columns(source_columns, target_columns) -%}
  {%- set target_not_in_source = diff_columns(target_columns, source_columns) -%}

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

  {%- if on_schema_change == 'append_new_columns' -%}
   {%- do alter_relation_add_remove_columns(target_relation, add_to_target_arr) -%}
  {% elif on_schema_change == 'sync_all_columns' %}
   {%- do alter_relation_add_remove_columns(target_relation, add_to_target_arr, remove_from_target_arr) -%}
  {% elif on_schema_change == 'full_refresh' %}
    
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

{% macro process_schema_changes(schema_changed, on_schema_change, tmp_relation, target_relation) %}

    {% if schema_changed %}
      
      {% if on_schema_change=='fail' %}
        
        {{ 
          exceptions.raise_compiler_error('The source and target schemas on this incremental model are out of sync!
               You can specify one of ["fail", "ignore", "add_new_columns", "sync_all_columns", "full_refresh"] in the on_schema_change config to control this behavior.
               Please re-run the incremental model with full_refresh set to True to update the target schema.
               Alternatively, you can update the schema manually and re-run the process.') 
        }}
      
      {# unless we ignore, run the sync operation per the config #}
      {% elif on_schema_change != 'ignore' %}
        
        {% set schema_changes = sync_schemas(tmp_relation, target_relation, on_schema_change) %}
        {% set columns_added = schema_changes['columns_added'] %}
        {% set columns_removed = schema_changes['columns_removed'] %}

        {# logging conditionally based on specified behavior #}
        
        {% if on_schema_change == 'append_new_columns' %}
          {% set log_message = 'Schema change detected. dbt performed {{ on_schema_change }} by adding {{ columns_added }}. ' %}
        {% else %}
          {% set log_message = 'Schema change detected. dbt performed {{ on_schema_change }} by adding {{ columns_added }} and removing {{ columns_removed }}. ' %}
        {% endif %}
        
        {% do log(log_message, debug=true) %}

      {% endif %}

    {% endif %}

{% endmacro %}

{% macro run_refresh_procedure(existing_relation, target_relation, sql) %}
  {% set backup_identifier = existing_relation.identifier ~ "__dbt_backup" %}
  {% set backup_relation = existing_relation.incorporate(path={"identifier": backup_identifier}) %}
  {% do adapter.drop_relation(backup_relation) %}

  {% do adapter.rename_relation(target_relation, backup_relation) %}
  {% set build_sql = create_table_as(False, target_relation, sql) %}
  {% do to_drop.append(backup_relation) %}
  
  {{ return(build_sql) }}
{% endmacro %}