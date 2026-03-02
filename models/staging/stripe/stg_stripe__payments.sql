with source as (
    select * from {{ source('stripe', 'payments') }}
),

renamed as (
    select
        id as payments_id,
        cast(orderid as string) as order_id,
        paymentmethod as payment_method,
        status,

        -- amount is stored in cents, convert it to dollars
        amount / 100 as amount,
        created as created_at
    from source    
)

select * from renamed