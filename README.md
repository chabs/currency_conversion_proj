# Sales Data Pipeline - Production ETL Implementation

## Goal
Build a production-ready PySpark data pipeline to ingest sales transaction data and persist business-ready data in an Azure SQL database for downstream analytics.

## Objectives
1. Implement a production-grade ETL pipeline in a single PySpark notebook
2. Target either Azure SQL Database or SQL Server as the destination
3. Convert all sales amounts to USD currency
4. Ensure data quality: eliminate NULLs, duplicates, and enforce consistent formatting
5. Implement data quarantine for records failing business rules
6. Abort job execution if >5% of records fail validation (with appropriate logging)
7. Document all technical decisions, assumptions, and design rationale

## Pipeline Architecture

### Stage 1: Data Ingestion
**Assumptions:**
- OrderID and ProductID form a composite key identifying unique sales records
- Sales data may contain legitimate negative values (refunds) and zero values (promotions)
- All incoming data is initially ingested as String datatypes to prevent schema inference failures

**Technical Decisions:**
- Extract all sales data into PySpark DataFrames as String datatypes to avoid early failures from type violations
- Load all available data first, then quarantine erroneous records during processing
- Reference data (product catalogue) is reloaded on each pipeline execution

### Stage 2: Data Processing & Validation
**Assumptions:**
- Business rules are based on fictional requirements and have not been validated with stakeholders
- CustomerID is not currently a foreign key but may become one in future data model expansions
- Product transactions with SalesAmount = 0 are valid (promotional scenarios)

**Technical Decisions:**
- Implement comprehensive data validation including null checks, duplicate detection, and format validation
- Set failure threshold at 25% (adjusted from 5% based on provided test data characteristics) - configurable parameter
- Quarantine invalid records with detailed error logging and timestamps

### Stage 3: Currency Conversion
**Assumptions:**
- Sales transactions are immutable; currency conversion uses exchange rates from processing date only
- Final USD amounts will not be recalculated retrospectively

**Technical Decisions:**
- Integrate with external exchange rate API (exchangerate-api.com) for real-time conversion rates. The latest version (version 6) of the API has been used opposed to version 4.
- Implement graceful API failure handling with fallback mechanisms (for example, a response status code of 429 indicates the rate limit has been hit which resets after 20 minutes following the API documentation)
- Store original currency alongside converted USD amount for transparency and auditability
- Flatten API response using PySpark RDD operations (alternative: Python processing for small payloads)

### Stage 4: Data Caching Strategy
**Technical Decisions:**
After evaluating multiple caching approaches:
- **Database staging tables:** Rejected due to additional I/O overhead and database dependency but preferred for mitigating interruped Spark sessions in production
- **Spark caching:** Selected for in-memory persistence during session
- **Session caching:** Utilised for reference data
- **External caching solutions:** Rejected as over-engineered for current requirements

<i> Please note this currently has not been implemented due to time constraints but above detailes the options outlined and selected choice </i>

### Stage 5: Data Storage & Target Schema
**Technical Decisions:**
- Normalised schema design separating orders from order line items (order_product)
- Pre-aggregated main entity (order) to optimise downstream analytics performance
- Introduced surrogate primary key (order_product_id) alongside composite key
- Added audit fields (inserted_datetime) with provision for soft deletes and change tracking in the future
- Omitted separate currency exchange audit table to avoid data redundancy whilst maintaining immutability
- The username and password for the database is stored in .env file using the dotenv Python library to increase security (compared to plain text in the Python notebook). A better solution for production would be using a tool such as Azure Key Vault. 

**Schema Rationale:**
The target data model prioritises:
- **Normalisation:** Reduces storage requirements and improves query performance
- **Extensibility:** Supports future dimensional extensions (regions, customers)
- **Performance:** Pre-aggregated order summaries for analytical workloads
- **Auditability:** Comprehensive logging and timestamp tracking

<i> The target data schema is available in diagram form within /Documents/ </i>

## Data Quality Framework
- **Validation Rules:** Configurable business rules with detailed error classification which are documented in the data dictionary within the /Documents/ folder
- **Error Monitoring:** Real-time error rate tracking with automatic job termination (for example, when the error limit is hit)
- **Quarantine Process:** Systematic isolation of invalid records with full audit trail into the database. This allows them to be fed back to the business/ a reporting pipeline to be built in the future. 


## Setup Instructions
1. **Environment Prerequisites:**
   - Local IDE with Python notebook support
   - JVM installation (Apache Spark requirements)
   - Required Python libraries (see requirements.txt)

2. **Database Configuration:**
   - Azure SQL Database or SQL Server instance*
   - Execute provided DDL scripts for schema creation (the pipeline set-up in the Python notebook does run this for you but it is ok to run manually too)
   - Configure connection parameters in notebook (these are at the top of the notebook for convenience)

   * For this project an Azure SQL Database (Free - General Purpose - Serverless: Gen5, 2 vCores) was set-up with SQL Server authentication only.

3. **Security Configuration:**
   Create `.env` file in repository root:
   ```
   DB_USERNAME=your_username
   DB_PASSWORD=your_password
   ```
   Use single quotes if credentials contain special characters.

4. **Execution:**
   - Update connection paths and JDBC driver location in notebook
   - Execute all notebook cells sequentially

## Future Development Roadmap

### Phase 1: Enhanced Validation
- Implement configurable validation rules via YAML configuration
- Add comprehensive field format validation (OrderID, ProductID, CustomerID patterns). For example, Product ID should begin with a 'P' followed by 2 integers. 
- Expand date validation (range checks, business day validation). For example, date is greater than 01/01/2023 but not greater than today's date.
- Standardise discount field handling (null vs 0.0 consistency)
- Check if the time_eol_unix does not indicate that the API is end-of-life (EOL). Ideally throw a warning when sufficent time out.

### Phase 2: Operational Excellence
- Implement external logging framework with database persistence
- Develop comprehensive archiving strategy for historical data management
- Enhance error handling for database loading operations
- Review and optimise indexing strategy for performance. Incorporate execution of the index in the main pipeline script (this is script CREATE_index.sql).
- Implement the caching strategy outlined above in technical decisions.
- When a product_ref file is loaded, instead of overwriting, ideally it would perform a upsert (MERGE).

### Phase 3: Advanced Features
- Implement slowly changing dimension tracking for product reference data
- Add support for foreign key constraints with merge operations
- Develop delta loading capabilities for incremental updates
- Create aggregated reporting tables for analytical use cases
- Adjust the logger to capture and better handle Spark information

### Phase 4: Production Hardening
- Implement comprehensive monitoring and alerting
- Add support for configuration-driven pipeline execution
- Enhance API integration with circuit breaker patterns
- Develop automated data quality reporting dashboard
- Executing the create table SQL statements via the Spark engine is limiting ability
to add primary key constraints.

## Known Limitations
- Foreign key constraints temporarily disabled during data loading (requires merge strategy implementation)
- DDL execution limitations through Spark: originally implemented IF NOT EXISTS... CREATE TABLE but this is not possible for Spark. Altered the implementation to what currently exists. The alternative option would have been to use the PyODBC library.
- Hard-coded validation rules require parameterisation
- Assert statements require kernel restart for proper function when the .env file is changed.
- The create tables SQL statements are being executed successfully as part of the setup pipeline but they are not showing in the database. Requires investigation.

## Technical Dependencies
- PySpark (distributed data processing)
- Azure SQL Database (data persistence)
- External Exchange Rate API (currency conversion)
- Python ecosystem (pandas, requests, etc.)

## Supporting Documentation
- Data dictionary which details the source data information and
proposed business rules (light touch currently)
- Target data moel (TDM) in multiple formats
- Screenshot showing the quarantined data being persisted in the
database