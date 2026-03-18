-- Create databases for all services
-- Flyway will handle table creation on service startup

CREATE DATABASE IF NOT EXISTS `awsome_shop_auth`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS `awsome_shop_product`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS `awsome_shop_point`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS `awsome_shop_order`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
