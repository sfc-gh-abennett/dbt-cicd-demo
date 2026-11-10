-- Fails if any customer has non-positive revenue
select * from {{ ref('fct_customer_revenue') }}
where lifetime_revenue <= 0
