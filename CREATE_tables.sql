CREATE TABLE product_ref (
        product_id VARCHAR(6) NOT NULL PRIMARY KEY,
        product_name VARCHAR(100) NOT NULL,
        product_reference VARCHAR(100) NOT NULL,
        inserted_datetime DATETIME2 NOT NULL
    );


CREATE TABLE orders (
        order_id VARCHAR(6) NOT NULL PRIMARY KEY,
        customer_id VARCHAR(5) NOT NULL,
        total_sales_amount_usd DECIMAL(10,2) NOT NULL,
        region VARCHAR(50) NOT NULL,
        order_date DATE NOT NULL,
        inserted_datetime DATETIME2 NOT NULL
    );

CREATE TABLE order_product (
        order_product_id VARCHAR(15) NOT NULL PRIMARY KEY,
        order_id VARCHAR(6) NOT NULL,
        product_id VARCHAR(6) NOT NULL,
        sale_amount_usd DECIMAL(8,2) NOT NULL,
        sale_amount DECIMAL(8,2) NOT NULL,
        base_currency VARCHAR(2) NOT NULL,
        exchange_rate DECIMAL(12,6) NOT NULL,
        exchange_timestamp DATETIME2 NOT NULL,
        discount DECIMAL(8,2),
        inserted_datetime DATETIME2 NOT NULL
    );
