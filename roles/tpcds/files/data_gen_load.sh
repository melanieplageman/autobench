#!/bin/bash

echo "Generating data ..." 1>&2

# Use the TPC-provided data generation tool, `dsdgen`, to generate data files
# at the specified scale in parallel.
parallel="$(nproc)"
pids=()
for i in $(seq "$parallel"); do
  ./dsdgen -FORCE -DIR data -SCALE $1 -PARALLEL "$parallel" -CHILD "$i" &
  pids+=($!)
done
wait "${pids[@]}"

# Load each data file into the appropriate table. Loading the data in
# parallel results in file names like web_sales_1_2.dat, so use a regular
# expression to get the base table name.
for i in data/*.dat; do
  [[ $i =~ ([a-z_]+)_[0-9]*_[0-9]*\.dat$ ]] || continue
  table="${BASH_REMATCH[1]}"
  echo "Loading $table ..." 1>&2

  # dsdgen's TERMINATE flag doesn't work (it strips all trailing delimiters,
  # not just one, so the number of columns would be interpreted incorrectly
  # during loading), alas, do it ourselves.
  sed -i -e 's/|$//' "$i"

  # TODO: it would be nice to have a worker pool to parallelize this
  # dsdgen generates pipe delimited, CSV-like, LATIN1 encoded data
  psql -c "\\copy $table FROM '$i' WITH (FORMAT CSV, DELIMITER '|', ENCODING 'LATIN1')"
done

# Add indexes on all of the foreign keys and a few other indexes as
# recommended by pivotalguru. See:
#   https://github.com/pivotalguru/TPC-DS/blob/master/03_ddl/051.postgresql.foreignkeys.sql
#   https://github.com/pivotalguru/TPC-DS/blob/master/03_ddl/052.postgresql.indexes.sql
psql <<PSQL
-- Foreign key indexes
CREATE INDEX idx_ss_sold_date_sk ON store_sales(ss_sold_date_sk);
CREATE INDEX idx_ss_sold_time_sk ON store_sales(ss_sold_time_sk);
CREATE INDEX idx_ss_item_sk ON store_sales(ss_item_sk);
CREATE INDEX idx_ss_customer_sk ON store_sales(ss_customer_sk);
CREATE INDEX idx_ss_cdemo_sk ON store_sales(ss_cdemo_sk);
CREATE INDEX idx_ss_hdemo_sk ON store_sales(ss_hdemo_sk);
CREATE INDEX idx_ss_addr_sk ON store_sales(ss_addr_sk);
CREATE INDEX idx_ss_store_sk ON store_sales(ss_store_sk);
CREATE INDEX idx_ss_promo_sk ON store_sales(ss_promo_sk);
CREATE INDEX idx_ss_ticket_number ON store_sales(ss_ticket_number);

CREATE INDEX idx_sr_returned_date_sk ON store_returns(sr_returned_date_sk);
CREATE INDEX idx_sr_return_time_sk ON store_returns(sr_return_time_sk);
CREATE INDEX idx_sr_item_sk ON store_returns(sr_item_sk);
CREATE INDEX idx_sr_customer_sk ON store_returns(sr_customer_sk);
CREATE INDEX idx_sr_cdemo_sk ON store_returns(sr_cdemo_sk);
CREATE INDEX idx_sr_hdemo_sk ON store_returns(sr_hdemo_sk);
CREATE INDEX idx_sr_addr_sk ON store_returns(sr_addr_sk);
CREATE INDEX idx_sr_store_sk ON store_returns(sr_store_sk);
CREATE INDEX idx_sr_reason_sk ON store_returns(sr_reason_sk);
CREATE INDEX idx_sr_ticket_number ON store_returns(sr_ticket_number);

CREATE INDEX idx_cs_sold_date_sk ON catalog_sales(cs_sold_date_sk);
CREATE INDEX idx_cs_sold_time_sk ON catalog_sales(cs_sold_time_sk);
CREATE INDEX idx_cs_ship_date_sk ON catalog_sales(cs_ship_date_sk);
CREATE INDEX idx_cs_bill_customer_sk ON catalog_sales(cs_bill_customer_sk);
CREATE INDEX idx_cs_bill_cdemo_sk ON catalog_sales(cs_bill_cdemo_sk);
CREATE INDEX idx_cs_bill_hdemo_sk ON catalog_sales(cs_bill_hdemo_sk);
CREATE INDEX idx_cs_bill_addr_sk ON catalog_sales(cs_bill_addr_sk);
CREATE INDEX idx_cs_ship_customer_sk ON catalog_sales(cs_ship_customer_sk);
CREATE INDEX idx_cs_ship_cdemo_sk ON catalog_sales(cs_ship_cdemo_sk);
CREATE INDEX idx_cs_ship_hdemo_sk ON catalog_sales(cs_ship_hdemo_sk);
CREATE INDEX idx_cs_ship_addr_sk ON catalog_sales(cs_ship_addr_sk);
CREATE INDEX idx_cs_call_center_sk ON catalog_sales(cs_call_center_sk);
CREATE INDEX idx_cs_catalog_page_sk ON catalog_sales(cs_catalog_page_sk);
CREATE INDEX idx_cs_ship_mode_sk ON catalog_sales(cs_ship_mode_sk);
CREATE INDEX idx_cs_warehouse_sk ON catalog_sales(cs_warehouse_sk);
CREATE INDEX idx_cs_item_sk ON catalog_sales(cs_item_sk);
CREATE INDEX idx_cs_promo_sk ON catalog_sales(cs_promo_sk);
CREATE INDEX idx_cs_order_number ON catalog_sales(cs_order_number);

CREATE INDEX idx_cr_returned_date_sk ON catalog_returns(cr_returned_date_sk);
CREATE INDEX idx_cr_returned_time_sk ON catalog_returns(cr_returned_time_sk);
CREATE INDEX idx_cr_item_sk ON catalog_returns(cr_item_sk);
CREATE INDEX idx_cr_refunded_customer_sk ON catalog_returns(cr_refunded_customer_sk);
CREATE INDEX idx_cr_refunded_cdemo_sk ON catalog_returns(cr_refunded_cdemo_sk);
CREATE INDEX idx_cr_refunded_hdemo_sk ON catalog_returns(cr_refunded_hdemo_sk);
CREATE INDEX idx_cr_refunded_addr_sk ON catalog_returns(cr_refunded_addr_sk);
CREATE INDEX idx_cr_returning_customer_sk ON catalog_returns(cr_returning_customer_sk);
CREATE INDEX idx_cr_returning_cdemo_sk ON catalog_returns(cr_returning_cdemo_sk);
CREATE INDEX idx_cr_returning_hdemo_sk ON catalog_returns(cr_returning_hdemo_sk);
CREATE INDEX idx_cr_returning_addr_sk ON catalog_returns(cr_returning_addr_sk);
CREATE INDEX idx_cr_call_center_sk ON catalog_returns(cr_call_center_sk);
CREATE INDEX idx_cr_catalog_page_sk ON catalog_returns(cr_catalog_page_sk);
CREATE INDEX idx_cr_ship_mode_sk ON catalog_returns(cr_ship_mode_sk);
CREATE INDEX idx_cr_warehouse_sk ON catalog_returns(cr_warehouse_sk);
CREATE INDEX idx_cr_reason_sk ON catalog_returns(cr_reason_sk);
CREATE INDEX idx_cr_order_number ON catalog_returns(cr_order_number);

CREATE INDEX idx_ws_sold_date_sk ON web_sales(ws_sold_date_sk);
CREATE INDEX idx_ws_sold_time_sk ON web_sales(ws_sold_time_sk);
CREATE INDEX idx_ws_ship_date_sk ON web_sales(ws_ship_date_sk);
CREATE INDEX idx_ws_item_sk ON web_sales(ws_item_sk);
CREATE INDEX idx_ws_bill_customer_sk ON web_sales(ws_bill_customer_sk);
CREATE INDEX idx_ws_bill_cdemo_sk ON web_sales(ws_bill_cdemo_sk);
CREATE INDEX idx_ws_bill_hdemo_sk ON web_sales(ws_bill_hdemo_sk);
CREATE INDEX idx_ws_bill_addr_sk ON web_sales(ws_bill_addr_sk);
CREATE INDEX idx_ws_ship_customer_sk ON web_sales(ws_ship_customer_sk);
CREATE INDEX idx_ws_ship_cdemo_sk ON web_sales(ws_ship_cdemo_sk);
CREATE INDEX idx_ws_ship_hdemo_sk ON web_sales(ws_ship_hdemo_sk);
CREATE INDEX idx_ws_ship_addr_sk ON web_sales(ws_ship_addr_sk);
CREATE INDEX idx_ws_web_page_sk ON web_sales(ws_web_page_sk);
CREATE INDEX idx_ws_web_site_sk ON web_sales(ws_web_site_sk);
CREATE INDEX idx_ws_ship_mode_sk ON web_sales(ws_ship_mode_sk);
CREATE INDEX idx_ws_warehouse_sk ON web_sales(ws_warehouse_sk);
CREATE INDEX idx_ws_promo_sk ON web_sales(ws_promo_sk);
CREATE INDEX idx_ws_order_number ON web_sales(ws_order_number);

CREATE INDEX idx_wr_returned_date_sk ON web_returns(wr_returned_date_sk);
CREATE INDEX idx_wr_returned_time_sk ON web_returns(wr_returned_time_sk);
CREATE INDEX idx_wr_item_sk ON web_returns(wr_item_sk);
CREATE INDEX idx_wr_refunded_customer_sk ON web_returns(wr_refunded_customer_sk);
CREATE INDEX idx_wr_refunded_cdemo_sk ON web_returns(wr_refunded_cdemo_sk);
CREATE INDEX idx_wr_refunded_hdemo_sk ON web_returns(wr_refunded_hdemo_sk);
CREATE INDEX idx_wr_refunded_addr_sk ON web_returns(wr_refunded_addr_sk);
CREATE INDEX idx_wr_returning_customer_sk ON web_returns(wr_returning_customer_sk);
CREATE INDEX idx_wr_returning_cdemo_sk ON web_returns(wr_returning_cdemo_sk);
CREATE INDEX idx_wr_returning_hdemo_sk ON web_returns(wr_returning_hdemo_sk);
CREATE INDEX idx_wr_returning_addr_sk ON web_returns(wr_returning_addr_sk);
CREATE INDEX idx_wr_web_page_sk ON web_returns(wr_web_page_sk);
CREATE INDEX idx_wr_reason_sk ON web_returns(wr_reason_sk);
CREATE INDEX idx_wr_order_number ON web_returns(wr_order_number);

CREATE INDEX idx_inv_date_sk ON inventory(inv_date_sk);
CREATE INDEX idx_inv_item_sk ON inventory(inv_item_sk);
CREATE INDEX idx_inv_warehouse_sk ON inventory(inv_warehouse_sk);

CREATE INDEX idx_s_closed_date_sk ON store(s_closed_date_sk);

CREATE INDEX idx_cc_closed_date_sk ON call_center(cc_closed_date_sk);
CREATE INDEX idx_cc_open_date_sk ON call_center(cc_open_date_sk);

CREATE INDEX idx_cp_start_date_sk ON catalog_page(cp_start_date_sk);
CREATE INDEX idx_cp_end_date_sk ON catalog_page(cp_end_date_sk);

CREATE INDEX idx_web_open_date_sk ON web_site(web_open_date_sk);
CREATE INDEX idx_web_close_date_sk ON web_site(web_close_date_sk);

CREATE INDEX idx_wp_creation_date_sk ON web_page(wp_creation_date_sk);
CREATE INDEX idx_wp_access_date_sk ON web_page(wp_access_date_sk);
CREATE INDEX idx_wp_customer_sk ON web_page(wp_customer_sk);

CREATE INDEX idx_c_current_cdemo_sk ON customer(c_current_cdemo_sk);
CREATE INDEX idx_c_current_hdemo_sk ON customer(c_current_hdemo_sk);
CREATE INDEX idx_c_current_addr_sk ON customer(c_current_addr_sk);
CREATE INDEX idx_c_first_shipto_date_sk ON customer(c_first_shipto_date_sk);
CREATE INDEX idx_c_first_sales_date_sk ON customer(c_first_sales_date_sk);

CREATE INDEX idx_hd_income_band_sk ON household_demographics(hd_income_band_sk);

CREATE INDEX idx_p_start_date_sk ON promotion(p_start_date_sk);
CREATE INDEX idx_p_end_date_sk ON promotion(p_end_date_sk);
CREATE INDEX idx_p_item_sk ON promotion(p_item_sk);

-- Other indexes
CREATE INDEX idx_customer_demographics_1 ON customer_demographics(cd_marital_status, cd_education_status);
CREATE INDEX idx_customer_address_1 ON customer_address(ca_state, ca_country);
CREATE INDEX idx_store_sales_1 ON store_sales(ss_sales_price, ss_net_profit);
CREATE INDEX idx_store_sales_2 ON store_sales(ss_quantity, ss_ext_sales_price, ss_net_profit);
CREATE INDEX idx_store_sales_quantity_1 ON store_sales(ss_quantity);
CREATE INDEX idx_store_sales_quantity_2 ON store_sales(ss_quantity, ss_list_price, ss_coupon_amt, ss_wholesale_cost);
CREATE INDEX idx_item_1 ON item(i_category);
CREATE INDEX idx_item_2 ON item(i_category, i_current_price);

ANALYZE VERBOSE;
PSQL
