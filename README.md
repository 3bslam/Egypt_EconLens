<p align="center">
  <img src="screenshots/hero_banner.png" alt="Egypt EconLens Banner" width="100%"/>
</p>

<h1 align="center">🇪🇬 Egypt EconLens — Trade & Supply Chain BI Platform</h1>

<p align="center">
  <strong>A comprehensive Business Intelligence platform analyzing Egypt's trade dynamics, supply chain performance, and macroeconomic indicators (2019–2025)</strong>
</p>

<p align="center">
  <a href="#-overview"><img src="https://img.shields.io/badge/Platform-BI%20%26%20Analytics-0a192f?style=for-the-badge&logo=powerbi&logoColor=F2C811" alt="Platform"/></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/SQL%20Server-2022-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white" alt="SQL Server"/></a>
  <a href="#-etl-pipeline"><img src="https://img.shields.io/badge/SSIS-ETL%20Pipeline-217346?style=for-the-badge&logo=microsoft&logoColor=white" alt="SSIS"/></a>
  <a href="#-power-bi-dashboard"><img src="https://img.shields.io/badge/Power%20BI-Interactive%20Dashboard-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" alt="Power BI"/></a>
  <img src="https://img.shields.io/badge/ITI-Graduation%20Project-1e3a5f?style=for-the-badge" alt="ITI"/>
</p>

<p align="center">
  <img src="https://img.shields.io/github/last-commit/3bslam/Egypt_EconLens?style=flat-square&color=d4a843" alt="Last Commit"/>
  <img src="https://img.shields.io/github/repo-size/3bslam/Egypt_EconLens?style=flat-square&color=1e3a5f" alt="Repo Size"/>
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"/>
  <img src="https://img.shields.io/badge/status-Complete-brightgreen?style=flat-square" alt="Status"/>
</p>

---

## 📋 Overview

**Egypt EconLens** is an end-to-end BI platform built as an **ITI Graduation Project**. It transforms raw trade data, supply chain records, and macroeconomic indicators into actionable insights through an automated data pipeline and interactive dashboards.

### 🎯 Problem Statement

Egypt's trade ecosystem generates massive volumes of data across multiple agencies — **UN Comtrade**, the **World Bank**, and internal procurement systems. Decision-makers lack a unified view to:

- Track **trade balance trends** and identify deficit/surplus patterns
- Monitor **supply chain KPIs** (OTIF, late deliveries, fraud rates)
- Analyze the impact of **economic crises** (COVID-19, currency devaluations) on trade flows
- Identify **strategic commodities** and top trading partners
- Correlate **macroeconomic indicators** (GDP, inflation, USD/EGP rates) with trade performance

### ✅ Our Solution

A fully automated BI pipeline that:

1. **Ingests** data from 4+ heterogeneous sources
2. **Transforms & validates** using SSIS ETL packages with built-in DQ checks
3. **Stores** in an optimized Star Schema data warehouse
4. **Analyzes** through 21 stored procedures covering CRUD + analytics
5. **Visualizes** via an interactive Power BI dashboard with 10+ report pages

---

## 🏗️ Architecture

```mermaid
flowchart LR
    subgraph Sources["📥 Data Sources"]
        A["🌍 UN Comtrade\nTrade Data"]
        B["🏦 World Bank\nMacro Indicators"]
        C["💱 USD/EGP\nExchange Rates"]
        D["📦 Supply Chain\nOLTP System"]
    end

    subgraph ETL["⚙️ SSIS ETL Pipeline"]
        E["Master.dtsx\nOrchestrator"]
        F["Data Validation\n& DQ Checks"]
    end

    subgraph DWH["🗄️ SQL Server DWH"]
        G["⭐ Star Schema\n5 Dims + 2 Facts"]
        H["📝 21 Stored\nProcedures"]
    end

    subgraph BI["📊 Power BI"]
        I["Interactive\nDashboard"]
    end

    A --> E
    B --> E
    C --> E
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I

    style Sources fill:#1a365d,stroke:#d4a843,color:#fff
    style ETL fill:#2d4a3e,stroke:#d4a843,color:#fff
    style DWH fill:#4a2040,stroke:#d4a843,color:#fff
    style BI fill:#5c3d1a,stroke:#d4a843,color:#fff
```

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|:---:|:---:|:---|
| 📊 | **Power BI** | Interactive dashboards & data visualization |
| 🗄️ | **SQL Server 2022** | Data Warehouse (Star Schema) |
| ⚙️ | **SSIS** | ETL pipeline & data orchestration |
| 📝 | **T-SQL** | Stored procedures, DQ validation |
| 🐍 | **Python** | Data preprocessing & synthetic data generation |
| 💱 | **REST APIs** | World Bank & exchange rate data ingestion |

---

## ⭐ Data Warehouse Schema

The DWH follows a **Star Schema** design optimized for analytical queries:

```mermaid
erDiagram
    fact_trade_flows {
        int trade_key PK
        int date_key FK
        int country_key FK
        int commodity_key FK
        char flow_type
        decimal trade_value_usd
    }

    fact_supply_chain {
        int order_key PK
        int date_key FK
        int product_key FK
        int country_key FK
        varchar order_status
        decimal sales_usd
        decimal profit_usd
        int shipping_delay_days
        bit is_late
        varchar shipping_mode
    }

    dim_date {
        int date_key PK
        int year
        int month
        varchar month_name
        bit is_crisis_year
    }

    dim_country {
        int country_key PK
        varchar iso_code
        varchar country_name
        varchar region
        varchar income_group
        bit is_egypt
    }

    dim_commodity {
        int commodity_key PK
        varchar hs_code
        varchar description
        varchar category
        bit is_strategic
    }

    dim_product {
        int product_key PK
        varchar product_name
        varchar category_name
        varchar department_name
    }

    dim_egypt_macro {
        int date_key PK
        int year
        decimal usd_egp_annual_avg
        decimal gdp_usd
        decimal inflation_pct
        decimal foreign_reserves_usd
    }

    fact_trade_flows ||--o{ dim_date : "date_key"
    fact_trade_flows ||--o{ dim_country : "country_key"
    fact_trade_flows ||--o{ dim_commodity : "commodity_key"
    fact_supply_chain ||--o{ dim_date : "date_key"
    fact_supply_chain ||--o{ dim_product : "product_key"
    fact_supply_chain ||--o{ dim_country : "country_key"
    dim_egypt_macro ||--o{ dim_date : "date_key"
```

---

## ⚙️ ETL Pipeline (SSIS)

The ETL pipeline consists of **9 SSIS packages** orchestrated by a Master package:

| # | Package | Description |
|:---:|:---|:---|
| 🎯 | `Master.dtsx` | **Orchestrator** — executes all packages in dependency order |
| 1 | `010_Load_dim_date.dtsx` | Loads 84 monthly date records (2019–2025) |
| 2 | `020_Load_dim_country.dtsx` | Loads country dimension with ISO codes & regions |
| 3 | `030_Load_dim_commodity.dtsx` | Loads HS commodity codes with strategic flags |
| 4 | `040_Load_dim_egypt_macro.dtsx` | Loads World Bank macro indicators + exchange rates |
| 5 | `050_Load_dim_product.dtsx` | Loads product catalog from supply chain source |
| 6 | `060_Load_fact_trade_flows.dtsx` | Loads Comtrade trade data with FK lookups |
| 7 | `070_Load_fact_supply_chain.dtsx` | Loads supply chain orders with derived columns |
| 8 | `080_DQ_Validation.dtsx` | Runs data quality checks & logs results |

### ETL Screenshots

<details>
<summary>📸 Click to expand ETL pipeline screenshots</summary>

#### Fact Supply Chain — Data Flow
> Complex ETL with Flat File Source → Data Conversion → Lookups (date, product, country, macro) → Derived Columns (shipping_delay_days, is_late, is_synthetic) → Conditional Split → OLE DB Destination + Reject File

<p align="center">
  <img src="screenshots/ssis_supply_chain_etl.png" alt="Supply Chain ETL Data Flow" width="90%"/>
</p>

#### Fact Trade Flows — Data Flow
> Flat File Source → Conditional Split → Lookups (date, country, commodity) → Data Conversions → OLE DB Destination

<p align="center">
  <img src="screenshots/ssis_trade_flows_etl.png" alt="Trade Flows ETL Data Flow" width="90%"/>
</p>

#### Macro Indicators — Control Flow
> Load World Bank data → Update Exchange Rates (sequential execution with precedence constraints)

<p align="center">
  <img src="screenshots/ssis_macro_etl.png" alt="Macro Indicators ETL" width="90%"/>
</p>

</details>

---

## 📝 Stored Procedures (21 Total)

### 📖 READ Operations (10)

| Procedure | Description | Example Usage |
|:---|:---|:---|
| `sp_GetTradeSummary` | Trade summary by year/month | `EXEC sp_GetTradeSummary @year = 2023` |
| `sp_GetTradeBalance` | Exports vs. imports + deficit/surplus status | `EXEC sp_GetTradeBalance` |
| `sp_GetTopPartners` | Top N trading partners by value | `EXEC sp_GetTopPartners @flow='X', @top=10` |
| `sp_GetTopCommodities` | Top N traded commodities | `EXEC sp_GetTopCommodities @flow='M', @year=2022` |
| `sp_GetMacroIndicators` | Annual macro indicators (aggregated) | `EXEC sp_GetMacroIndicators @year = 2023` |
| `sp_GetMacroMonthly` | Monthly macro indicators (84 rows) | `EXEC sp_GetMacroMonthly @year = 2022` |
| `sp_GetSupplyChainKPIs` | OTIF, late %, cancellation %, fraud % | `EXEC sp_GetSupplyChainKPIs @year = 2024` |
| `sp_GetProductPerformance` | Product ranking by sales & margin | `EXEC sp_GetProductPerformance @top = 20` |
| `sp_GetShippingAnalysis` | Shipping mode comparison | `EXEC sp_GetShippingAnalysis @year = 2024` |
| `sp_GetCrisisImpact` | Crisis vs. normal period comparison | `EXEC sp_GetCrisisImpact` |

### ➕ CREATE Operations (3)

| Procedure | Description |
|:---|:---|
| `sp_AddCountry` | Add new country to dimension |
| `sp_AddCommodity` | Add new commodity with HS code |
| `sp_AddMacroData` | Add monthly macro indicator row |

### ✏️ UPDATE Operations (3)

| Procedure | Description |
|:---|:---|
| `sp_UpdCountry` | Update country details (region, GDP, population) |
| `sp_UpdMacroData` | Update macro indicators for a specific month |
| `sp_UpdCommodity` | Update commodity category or strategic flag |

### 🗑️ DELETE Operations (2)

| Procedure | Description |
|:---|:---|
| `sp_DelCountry` | Delete country (only if not referenced in facts) |
| `sp_DelCommodity` | Delete commodity (only if not referenced in facts) |

### 🔧 UTILITY Operations (3)

| Procedure | Description |
|:---|:---|
| `sp_DWH_HealthCheck` | Row counts for all tables vs. expected |
| `sp_SearchTrade` | Keyword search in trade data (for Text-to-SQL) |
| `sp_RunDQValidation` | Run DQ checks: row counts, value sums, FK integrity |

---

## 📊 Power BI Dashboard

The interactive Power BI dashboard features **10+ report pages** covering:

| Page | Key Visualizations |
|:---|:---|
| 🏠 **Executive Cockpit** | High-level KPIs, trade balance, GDP trends |
| 📈 **Trade Analytics** | Import/export trends, year-over-year growth |
| ⚖️ **Trade Balance** | Surplus/deficit analysis, balance by partner |
| 🌍 **Top Partners** | Geographic map, partner ranking by value |
| 🏷️ **Strategic Commodities** | HS code analysis, strategic item tracking |
| 📦 **Supply Chain KPIs** | OTIF %, late delivery %, cancellation rates |
| 🚚 **Shipping Analysis** | Mode comparison, delay distribution |
| ⚠️ **Risk & Fraud** | Suspected fraud detection, risk scoring |
| 🔄 **OTIF Performance** | On-Time In-Full delivery tracking |
| 📅 **Time Intelligence** | Date-based drill-down, crisis period overlays |
| 💱 **Exchange Rate Impact** | USD/EGP correlation with trade volumes |
| 🔴 **Crisis Analysis** | COVID-19 & devaluation impact assessment |

---

## 🤖 Egypt Trade AI Dashboard Web App

Egypt EconLens includes a Flask-based web application that integrates the Power BI dashboards with a smart **AI Chat Assistant** and **Power Automate workflow automation**.

### 🌟 Key Web App Features
- **Power BI Embedded Dashboard:** Seamless integration of interactive reports and paginated report canvases directly in the browser.
- **AI Text-to-SQL Chatbot:** Translates natural language questions about Egypt's trade and supply chain into SQL queries, executes them against the DWH, and displays real-time tabular and textual summaries.
- **Security & Integrity Middleware:** Checks generated SQL for safety (prevents destructive commands) and employs a self-repair mechanism to handle query syntax errors.
- **Power Automate Integration:** Allows users to subscribe to report update alerts and request instant PDF exports of dashboard views.

---

## 📂 Project Structure

```
📦 Egypt-EconLens/
├── 🐍 app2.py                           # Flask Web App entry point
├── 📄 requirements.txt                  # Python dependencies
├── 📄 .env.example                      # Configuration template
├── 📊 Full_Light_Mode_PowerBI.pbix      # Power BI dashboard
├── 📜 stored_procedures_FIXED.sql       # 21 DWH stored procedures
├── 📂 SSIS_Packages/                    # SSIS ETL packages
│   ├── Master.dtsx                      #   ├── Master orchestrator
│   ├── 010_Load_dim_date.dtsx         #   ├── Dimension loaders
│   ├── 020_Load_dim_country.dtsx      #   │
│   ├── 030_Load_dim_commodity.dtsx    #   │
│   ├── 040_Load_dim_egypt_macro.dtsx  #   │
│   ├── 050_Load_dim_product.dtsx      #   │
│   ├── 060_Load_fact_trade_flows.dtsx #   ├── Fact loaders
│   ├── 070_Load_fact_supply_chain.dtsx#   │
│   └── 080_DQ_Validation.dtsx        #   └── Data quality validation
├── 📂 middleware/                       # AI Assistant query and prompt logic
│   ├── prompt_builder.py                #   ├── Prompt construction
│   ├── schema_retriever.py              #   ├── DWH metadata lookup
│   └── sql_validator.py                 #   └── SQL validation and repair
├── 📂 templates/                        # HTML UI pages
│   └── index.html                       #   └── Main dashboard & chat interface
├── 📂 static/                           # UI Assets & Styling
│   └── css/                             #   
│       └── style.css                    #   └── Styling rules
├── 📂 knowledge/                        # LLM context references
│   ├── schema.json                      #   ├── JSON schema of DWH
│   └── schema.txt                       #   └── Text description of tables
├── 📂 data/                             # Sample data files
│   ├── dim_egypt_macro_READY.csv      #   ├── Macro indicators
│   └── USD_EGP Historical Data.csv    #   └── Exchange rates
├── 📂 screenshots/                      # ETL & architecture screenshots
└── 📄 .gitignore                        # Repository exclusion rules
```

> **📁 Full datasets** (CSV files > 100MB) are hosted on Google Drive:
> 🔗 **[Download Data Files](https://drive.google.com/drive/u/0/folders/15fnZJjcYtHDwM4jHUdfjSmm11OHchYoX)**

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Purpose |
|:---|:---|:---|
| SQL Server | 2019+ | Data Warehouse hosting |
| SSMS | Latest | Database management |
| Visual Studio | 2019+ | SSIS package development |
| SSIS Extension | Latest | VS integration for SSIS |
| Power BI Desktop | Latest | Dashboard viewing |
| Python | 3.10+ | Flask Web App & AI Assistant backend |
| ODBC Driver 17 | Latest | SQL Server connection for Python |

### Setup Steps

```bash
# 1. Clone the repository
git clone https://github.com/3bslam/Egypt_EconLens.git

# 2. Download data files from Google Drive
# 🔗 https://drive.google.com/drive/u/0/folders/15fnZJjcYtHDwM4jHUdfjSmm11OHchYoX

# 3. Restore the database backup
# Open SSMS → Right-click Databases → Restore Database
# Select: EgyptBI_DWH1_Compressed.bak (from Google Drive)

# 4. Run stored procedures
# Open stored_procedures_FIXED.sql in SSMS → Execute

# 5. Configure SSIS
# Open SSIS packages in Visual Studio
# Update connection managers to point to your SQL Server instance

# 6. Open Power BI Dashboard
# Open Full_Light_Mode_PowerBI.pbix in Power BI Desktop
# Update data source connection if needed

# 7. Configure Flask Web App Environment
# Copy the example environment file and fill in your keys (OpenRouter API key, SQL Server name, etc.)
cp .env.example .env

# 8. Create Python Virtual Environment & Install Dependencies
python -m venv .venv
# On Windows (Powershell):
.\.venv\Scripts\Activate.ps1
# On Linux/macOS:
# source .venv/bin/activate

python -m pip install --upgrade pip
pip install -r requirements.txt

# 9. Run the Flask Web Application
python app2.py
```

---

## 📊 Key Data Sources

| Source | Description | Records | Period |
|:---|:---|:---:|:---:|
| 🌍 **UN Comtrade** | International trade flows (HS2 level) | ~250K+ | 2019–2025 |
| 🏦 **World Bank** | GDP, inflation, foreign reserves | 84 rows | 2019–2025 |
| 💱 **Investing.com** | USD/EGP monthly exchange rates | 84 rows | 2019–2025 |
| 📦 **Supply Chain (Synthetic)** | Orders, shipping, procurement data | ~315K | 2019–2025 |

---

## 🔍 Key Insights Discovered

<table>
<tr>
<td width="50%">

### 📉 Trade Balance
- Egypt maintains a **persistent trade deficit**
- Deficit widens significantly during **crisis years**
- Top import categories: mineral fuels, machinery, cereals

</td>
<td width="50%">

### 💱 Currency Impact
- **EGP depreciation** (15.66 → 50.83 EGP/USD) correlates with:
  - Rising import costs
  - Inflation spikes (5% → 34%)
  - Reserve drawdowns

</td>
</tr>
<tr>
<td width="50%">

### 📦 Supply Chain
- Average **OTIF rate**: tracked across shipping modes
- **Fraud detection**: SUSPECTED_FRAUD orders isolated
- **Late delivery %**: varies by shipping mode and season

</td>
<td width="50%">

### 🔴 Crisis Analysis
- **2022 devaluation**: trade value shifted dramatically
- **COVID-19**: supply chain disruptions quantified
- **2023 inflation peak**: 33.88% — highest in study period

</td>
</tr>
</table>

---

## 👥 Team Members

<table>
<tr>
<td align="center" width="20%">
<h4>Moaaz Ashraf</h4>
<a href="https://github.com/moaaz311"><img src="https://img.shields.io/badge/GitHub-moaaz311-181717?style=flat-square&logo=github" alt="GitHub"/></a>
</td>
<td align="center" width="20%">
<h4>Shaimaa Hesham</h4>
<img src="https://img.shields.io/badge/Team-Member-1e3a5f?style=flat-square" alt="Team"/>
</td>
<td align="center" width="20%">
<h4>Ayman Abdelsalam</h4>
<a href="https://github.com/3bslam"><img src="https://img.shields.io/badge/GitHub-3bslam-181717?style=flat-square&logo=github" alt="GitHub"/></a>
</td>
<td align="center" width="20%">
<h4>Eman Salah</h4>
<img src="https://img.shields.io/badge/Team-Member-1e3a5f?style=flat-square" alt="Team"/>
</td>
<td align="center" width="20%">
<h4>Mahmoud Reda</h4>
<img src="https://img.shields.io/badge/Team-Member-1e3a5f?style=flat-square" alt="Team"/>
</td>
</tr>
</table>

<p align="center">
  <strong>🎓 ITI — Information Technology Institute</strong><br/>
  <em>BI Track — Graduation Project 2026</em>
</p>

---

## 📖 Documentation

- 📄 **[Project Documentation](https://docs.google.com/document/d/1lHbXuJEGga4qOJOjWLg2ndSixNY3V0OE/edit?usp=sharing&ouid=115243931777492490675&rtpof=true&sd=true)** — Full project pitch, methodology, and analysis
- 📁 **[Data Files (Google Drive)](https://drive.google.com/drive/u/0/folders/15fnZJjcYtHDwM4jHUdfjSmm11OHchYoX)** — Raw datasets and database backup

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-❤️%20at%20ITI-d4a843?style=for-the-badge" alt="Built with love at ITI"/>
</p>
