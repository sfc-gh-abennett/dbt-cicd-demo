select
    o_orderkey      as order_id,
    o_custkey       as customer_id,
    o_orderstatus   as order_status,
    o_totalprice    as order_total,
    o_orderdate     as order_date
from {{ source('tpch', 'orders') }}
{% if target.name != 'prod' %}
-- Keep dev/test fast and cheap: one year of data outside prod
where o_orderdate >= '1998-01-01'
{% endif %}
