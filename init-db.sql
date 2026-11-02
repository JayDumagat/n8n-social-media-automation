-- ============================================================================
-- PSE Market Automation: Bronze / Silver / Gold Data Lakehouse for ML & Analytics
-- Automatically executed by PostgreSQL on container initialization
-- ============================================================================

-- 1. BRONZE LAYER: Unstructured & Raw Scraped Data (For ML Pre-training / NLP / Replay)
CREATE TABLE IF NOT EXISTS ml_bronze_raw_ingestions (
    id BIGSERIAL PRIMARY KEY,
    market_date DATE NOT NULL DEFAULT CURRENT_DATE,
    scraper_engine VARCHAR(50) NOT NULL,      -- 'firecrawl', 'apify', 'tradingview'
    source_name VARCHAR(100) NOT NULL,        -- e.g. 'pse_edge_summary', 'pse_frames', 'pse_disclosures'
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
    price NUMERIC(14, 4) NOT NULL,
    change_points NUMERIC(14, 4),
    percent_change NUMERIC(10, 4),
    volume BIGINT NOT NULL,
    value_traded NUMERIC(20, 2) NOT NULL,
    dividend_yield_ttm NUMERIC(10, 4),
    cleaned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (market_date, symbol)
);

CREATE INDEX IF NOT EXISTS idx_silver_symbol_date
    ON ml_silver_daily_stock_quotes (symbol, market_date DESC);


-- 3. GOLD LAYER: Aggregated Daily Market Wrap + Human-Labeled Teams Captions (For LLM Fine-Tuning)
CREATE TABLE IF NOT EXISTS ml_gold_daily_market_wrap (
    market_date DATE PRIMARY KEY DEFAULT CURRENT_DATE,
    as_of_label VARCHAR(100),
    psei_close NUMERIC(14, 2),
    psei_change_pts NUMERIC(14, 2),
    psei_change_pct NUMERIC(10, 4),
    all_shares_pct NUMERIC(10, 4),
    financials_pct NUMERIC(10, 4),
    industrial_pct NUMERIC(10, 4),
    holding_firms_pct NUMERIC(10, 4),
    property_pct NUMERIC(10, 4),
    services_pct NUMERIC(10, 4),
    mining_oil_pct NUMERIC(10, 4),
    psei_total_return_close NUMERIC(14, 2),
    pse_divy_close NUMERIC(14, 2),
    pse_midcap_close NUMERIC(14, 2),
    total_volume BIGINT,
    total_trades BIGINT,
    total_value_turnover NUMERIC(20, 2),
    advancers INT,
    decliners INT,
    unchanged INT,
    top_gainers JSONB,
    top_losers JSONB,
    most_active JSONB,
    canva_graphic_caption TEXT,               -- Human-written headline/commentary from MS Teams
    social_post_caption TEXT,                 -- Human-written post caption from MS Teams
    send_email_blast VARCHAR(10),
    canva_exported_png_url TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

