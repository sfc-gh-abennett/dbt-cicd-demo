select
    c.customer_id,
    c.customer_name,
    c.market_segment,
    c.nation,
    count(o.order_id)   as order_count,
    sum(o.order_total)  as lifetime_revenue,
    min(o.order_date)   as first_order_date,
    max(o.order_date)   as last_order_date
from {{ ref('stg_customers') }} c
join {{ ref('stg_orders') }} o
  on c.customer_id = o.customer_id
group by 1, 2, 3, 4
