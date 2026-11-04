-- ============================================================================
-- PSE Market Automation: Bronze / Silver / Gold Data Lakehouse for ML & Analytics
-- Automatically executed by PostgreSQL on container initialization
-- ============================================================================

-- 1. BRONZE LAYER: Unstructured & Raw Scraped Data (For ML Pre-training / NLP / Replay)
CREATE TABLE IF NOT EXISTS ml_bronze_raw_ingestions (
    id BIGSERIAL PRIMARY KEY,
    market_date DATE NOT NULL DEFAULT CURRENT_DATE,
    scraper_engine VARCHAR(50) NOT NULL,      -- 'firecrawl', 'apify', 'tradingview'
    source_name VARCHAR(100) NOT NULL,        -- e.g. 'pse_edge_index_summary', 'pse_frames_and_disclosures', 'pse_stock_universe_scan'
    source_url TEXT,
    raw_markdown TEXT,                        -- Unstructured Markdown from Firecrawl
    raw_html TEXT,                            -- Raw HTML DOM snapshot
    raw_payload JSONB,                        -- Raw unstructured JSON from Apify / Firecrawl / API
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bronze_date_source
    ON ml_bronze_raw_ingestions (market_date, scraper_engine, source_name);


-- 2. SILVER LAYER: Filtered, Cleaned & Normalized Daily Stock Quotes (For Quantitative ML / Time-Series)
CREATE TABLE IF NOT EXISTS ml_silver_daily_stock_quotes (
    id BIGSERIAL PRIMARY KEY,
    market_date DATE NOT NULL DEFAULT CURRENT_DATE,
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(200),
    price NUMERIC(14, 4) NOT NULL,
    change_points NUMERIC(14, 4),
    percent_change NUMERIC(10, 4),
    volume BIGINT NOT NULL,
    value_traded NUMERIC(20, 2) NOT NULL,
    trades BIGINT,
    div_per_share_ttm NUMERIC(14, 4),
    dividend_yield_ttm NUMERIC(10, 4),
    board_lot INT,
    min_investment NUMERIC(20, 2),
    cleaned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (market_date, symbol)
);

ALTER TABLE ml_silver_daily_stock_quotes
    ADD COLUMN IF NOT EXISTS name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS trades BIGINT,
    ADD COLUMN IF NOT EXISTS div_per_share_ttm NUMERIC(14, 4),
    ADD COLUMN IF NOT EXISTS board_lot INT,
    ADD COLUMN IF NOT EXISTS min_investment NUMERIC(20, 2);

CREATE INDEX IF NOT EXISTS idx_silver_symbol_date
    ON ml_silver_daily_stock_quotes (symbol, market_date DESC);


-- 3. GOLD LAYER: Aggregated Daily Market Wrap + Sector Indices + Dividend & REIT Watchlists + Teams Captions
CREATE TABLE IF NOT EXISTS ml_gold_daily_market_wrap (
    market_date DATE PRIMARY KEY DEFAULT CURRENT_DATE,
    as_of_label VARCHAR(100),
    -- PSEi Main Summary
    psei_close NUMERIC(14, 2),
    psei_up_down VARCHAR(10),
    psei_arrow VARCHAR(5),
    psei_change_pts NUMERIC(14, 2),
    psei_change_pct NUMERIC(10, 4),
    total_volume BIGINT,
    total_trades BIGINT,
    total_value_turnover NUMERIC(20, 2),
    advancers INT,
    decliners INT,
    unchanged INT,
    -- Sector Indices: Arrow, Value (Close), Chg Value (Points), Chg %
    all_shares_arrow VARCHAR(5),
    all_shares_close NUMERIC(14, 2),
    all_shares_change_pts NUMERIC(14, 2),
    all_shares_pct NUMERIC(10, 4),
    financials_arrow VARCHAR(5),
    financials_close NUMERIC(14, 2),
    financials_change_pts NUMERIC(14, 2),
    financials_pct NUMERIC(10, 4),
    industrial_arrow VARCHAR(5),
    industrial_close NUMERIC(14, 2),
    industrial_change_pts NUMERIC(14, 2),
    industrial_pct NUMERIC(10, 4),
    holding_firms_arrow VARCHAR(5),
    holding_firms_close NUMERIC(14, 2),
    holding_firms_change_pts NUMERIC(14, 2),
    holding_firms_pct NUMERIC(10, 4),
    property_arrow VARCHAR(5),
    property_close NUMERIC(14, 2),
    property_change_pts NUMERIC(14, 2),
    property_pct NUMERIC(10, 4),
    services_arrow VARCHAR(5),
    services_close NUMERIC(14, 2),
    services_change_pts NUMERIC(14, 2),
    services_pct NUMERIC(10, 4),
    mining_oil_arrow VARCHAR(5),
    mining_oil_close NUMERIC(14, 2),
    mining_oil_change_pts NUMERIC(14, 2),
    mining_oil_pct NUMERIC(10, 4),
    psei_total_return_close NUMERIC(14, 2),
    pse_divy_close NUMERIC(14, 2),
    pse_midcap_close NUMERIC(14, 2),
    -- Structured JSONB Collections for Graphics & ML
    sectors_summary JSONB,                    -- All 7 sectors (Arrow, Value, Chg Pts, Chg %)
    dividend_yield_stocks JSONB,              -- Fixed 8 stocks: GLO, TEL, SCC, RCR, LTG, MBT, MREIT, DMC
    reit_stocks JSONB,                        -- Fixed 6 REITs: FILRT, RCR, CREIT, AREIT, MREIT, PREIT
    top_gainers JSONB,
    top_losers JSONB,
    most_active JSONB,
    -- Human-in-the-Loop Explanations & Captions from Microsoft Teams
    canva_graphic_caption TEXT,               -- 1-paragraph Market Explanation from MS Teams
    social_post_caption TEXT,                 -- Social Media Post Caption from MS Teams
    send_email_blast VARCHAR(10),
    canva_exported_png_url TEXT,
    publish_status VARCHAR(20) DEFAULT 'ready',
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ml_gold_daily_market_wrap
    ADD COLUMN IF NOT EXISTS publish_status VARCHAR(20) DEFAULT 'ready',
    ADD COLUMN IF NOT EXISTS psei_up_down VARCHAR(10),
    ADD COLUMN IF NOT EXISTS psei_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS all_shares_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS all_shares_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS all_shares_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS financials_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS financials_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS financials_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS industrial_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS industrial_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS industrial_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS holding_firms_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS holding_firms_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS holding_firms_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS property_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS property_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS property_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS services_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS services_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS services_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS mining_oil_arrow VARCHAR(5),
    ADD COLUMN IF NOT EXISTS mining_oil_close NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS mining_oil_change_pts NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS sectors_summary JSONB,
    ADD COLUMN IF NOT EXISTS dividend_yield_stocks JSONB,
    ADD COLUMN IF NOT EXISTS reit_stocks JSONB;

-- =========================================================================
-- GOLD LAYER: Daily Morning Notes (Global Markets + Foreign & Local News)
-- =========================================================================
CREATE TABLE IF NOT EXISTS ml_gold_morning_notes (
    id SERIAL PRIMARY KEY,
    market_date DATE NOT NULL UNIQUE,
    nasdaq_value NUMERIC(14, 2),
    nasdaq_chg_pct NUMERIC(8, 2),
    sp500_value NUMERIC(14, 2),
    sp500_chg_pct NUMERIC(8, 2),
    dow_value NUMERIC(14, 2),
    dow_chg_pct NUMERIC(8, 2),
    us10yr_value NUMERIC(10, 3),
    us10yr_chg_pct NUMERIC(8, 2),
    gold_value NUMERIC(14, 2),
    gold_chg_pct NUMERIC(8, 2),
    wti_crude_value NUMERIC(14, 2),
    wti_crude_chg_pct NUMERIC(8, 2),
    usd_php_value NUMERIC(10, 4),
    usd_php_chg_pct NUMERIC(8, 2),
    foreign_news JSONB,
    local_news JSONB,
    data_sources JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
