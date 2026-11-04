# PSE Automation & Lakehouse Pipelines

Decoupled, enterprise-grade n8n automated pipelines for the Philippine Stock Exchange (PSE) and global morning notes, featuring a Medallion Lakehouse architecture (Bronze, Silver, Gold), Canva Brand Template autofill, Microsoft Teams adaptive card approvals, and social distribution (Facebook, Instagram, SMTP).

---

## Architecture Overview

```
                                      [ Bronze Ingestion ]
  PSE Edge (Firecrawl) ─────────► ml_bronze_raw_ingestions
  PSE Edge (Apify)     ─────────► ml_bronze_raw_ingestions
  Investagrams API     ─────────► ml_bronze_raw_ingestions
                                         │
                                         ▼ [ Silver Normalization ]
                                 ml_silver_daily_stock_quotes
                                         │
                                         ▼ [ Aggregation & Formatting ]
                             Gainers / Losers / Active / Dividends / REITs
                                         │
                                         ▼ [ Gold Staging ]
                            ml_gold_daily_market_wrap (publish_status = 'ready')
                                         │
                     ┌───────────────────┴───────────────────┐
                     ▼                                       ▼
    [ Scheduled / Manual Trigger ]             [ Webhook Trigger ]
                     │
                     ▼ [ Human Approval & Captions ]
           Microsoft Teams Form
                     │
                     ▼ [ Asset Generation ]
           Canva Brand Template Autofill ──► PNG Export
                     │
                     ▼ [ Multi-Channel Distribution ]
           Facebook Graph API ──► Instagram Media Container ──► SMTP Blast
                     │
                     ▼ [ Gold Finalization ]
          ml_gold_daily_market_wrap (publish_status = 'published')
```

---

## Workflows

### 1. Ingestion & Lakehouse ETL Pipeline
- **File:** [`pse-market-wrap-ingestion-workflow.json`](file:///c:/Users/JaysonDumagat/Desktop/n8n-automation/pse-market-wrap-ingestion-workflow.json)
- **Schedule:** Monday – Friday at 4:30 PM PHT (`30 16 * * 1-5`) + Manual Trigger
- **Execution Mode:** Completely autonomous (no human-in-the-loop blocking).
- **Core Operations:**
  1. **Firecrawl:** Scrapes PSE Edge main indices and market breadth (`advancers`, `decliners`, `unchanged`, sector index changes).
  2. **Apify:** Ingests official PSE announcements and regulatory frames.
  3. **Investagrams API:** Fetches full active stock universe with exact trade counts (`Trades`), dividend yields (`StockDivTTM`), 52-week ranges, and turnover.
  4. **Bronze Layer:** Stores raw JSON/HTML/Markdown in `ml_bronze_raw_ingestions`.
  5. **Silver Layer:** Normalizes, deduplicates, and type-casts stock quotes into `ml_silver_daily_stock_quotes`.
  6. **Analytics:** Generates Top 3 Gainers, Top 3 Losers, Top 3 Most Active by turnover, Dividend Yield Watchlist (8 stocks), and REITs Watchlist (6 REITs).
  7. **Gold Staging:** Saves the consolidated daily summary into `ml_gold_daily_market_wrap` marked with `publish_status = 'ready'`.

---

### 2. Publishing & Social Media Distribution
- **File:** [`pse-market-wrap-publishing-workflow.json`](file:///c:/Users/JaysonDumagat/Desktop/n8n-automation/pse-market-wrap-publishing-workflow.json)
- **Schedule:** Monday – Friday at 5:00 PM PHT (`00 17 * * 1-5`) + Manual Trigger + Webhook (`POST /webhook/publish-pse-market-wrap`)
- **Core Operations:**
  1. **Postgres Query:** Fetches latest staged wrap (`SELECT * FROM ml_gold_daily_market_wrap WHERE publish_status = 'ready' ORDER BY market_date DESC LIMIT 1;`).
  2. **Microsoft Teams Form (`sendAndWait`):** Sends interactive Adaptive Card summarizing today's market metrics; prompts reviewer for:
     - `Canva Graphic Caption` (explanation card)
     - `Social Media Post Caption` (FB/IG post text)
     - `Send Email Blast?` (`Yes` / `No`)
  3. **Canva Brand Template Autofill:** Formats all market metrics into Canva dataset and generates customized branded card.
  4. **Canva Export:** Renders high-resolution PNG image.
  5. **Distribution:**
     - **Facebook Graph API:** Publishes photo post with approved captions.
     - **Instagram Graph API:** Creates media container and publishes post.
     - **Custom SMTP:** Sends formatted email newsletter if approved.
  6. **Gold Status Update:** Sets `publish_status = 'published'`, saves final captions and exported PNG URL, and timestamps `published_at = NOW()`.

---

### 3. Morning Notes Pipeline
- **File:** [`pse-morning-notes-workflow.json`](file:///c:/Users/JaysonDumagat/Desktop/n8n-automation/pse-morning-notes-workflow.json)
- **Schedule:** Monday – Friday at 7:30 AM PHT (`30 7 * * 1-5`) + Manual Trigger
- **Core Operations:**
  1. Fetches global equity indices and forex from EODHD (`NASDAQ`, `S&P 500`, `Dow Jones`, `USD/PHP`).
  2. Fetches commodities and bonds from TradingView Scanner (`US 10Y Yield`, `Gold`, `WTI Crude`).
  3. Pulls Foreign News via EODHD Financial News API.
  4. Pulls Local News via Google News RSS (`PH:en`).
  5. Upserts into `ml_gold_morning_notes`.

---

## Database Schema Highlights

- **`ml_bronze_raw_ingestions`**: Raw payload history for backtesting and audits.
- **`ml_silver_daily_stock_quotes`**: Cleansed daily stock quotes with exact `trades` and `div_per_share_ttm`.
- **`ml_gold_daily_market_wrap`**: Primary market wrap table featuring:
  - `publish_status VARCHAR(20) DEFAULT 'ready'` (`ready` ➔ `published`)
  - Full sector breakdowns and structured JSONB watchlists.
- **`ml_gold_morning_notes`**: Daily pre-market briefing data.

---

## Setup & Execution

1. Start Postgres & n8n:
   ```bash
   docker compose up -d
   ```
2. Both workflows are already imported into n8n:
   - `PSE Daily Market Wrap - 1. Ingestion & Lakehouse ETL Pipeline`
   - `PSE Daily Market Wrap - 2. Publishing & Social Media Distribution`
   - `PSE Morning Notes (EODHD + News)`
3. Access n8n at `http://127.0.0.1:5678/`.

