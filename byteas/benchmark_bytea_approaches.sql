-- The intention of this script is to benchmark the performance of different
-- approaches to storing a BYTEA column in Postgres.

CREATE TABLE receipt_fixtures (image_data BYTEA);

INSERT INTO receipt_fixtures (image_data)
SELECT pg_read_binary_file('/fixtures/receipt.jpeg');

-- use-case 1: receipt image in the receipts table.
-- 100K rows:
-- Time: 194.156s (3.0 minutes 14 seconds), executed in: 194.155s (3.0 minutes 14 seconds)
-- 1M rows:
-- Time: 957.547s (15.0 minutes 57 seconds), executed in: 957.546s (15.0 minutes 57 seconds)
CREATE UNLOGGED TABLE receipt_with_image (
    id SERIAL PRIMARY KEY,
    receipt_image BYTEA
);

INSERT INTO receipt_with_image (receipt_image)
SELECT image_data
FROM receipt_fixtures
CROSS JOIN generate_series(1, 1000000);

-- use-case 2: receipt image in a separate table.
-- 100K rows:
-- Time: 197.029s (3.0 minutes 17 seconds), executed in: 197.029s (3.0 minutes 17 seconds)
-- 1M rows:
CREATE UNLOGGED TABLE receipts (
    id SERIAL PRIMARY KEY
);

CREATE UNLOGGED TABLE receipt_images (
    id SERIAL PRIMARY KEY,
    receipt_id INT REFERENCES receipts (id),
    image_data BYTEA
);

INSERT INTO receipts
SELECT generate_series(1, 1000000);

INSERT INTO receipt_images (receipt_id, image_data)
SELECT
    receipts.id,
    receipt_fixtures.image_data
FROM receipts
CROSS JOIN receipt_fixtures;
