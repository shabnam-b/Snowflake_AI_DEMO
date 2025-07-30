


    -- ========================================================================
    -- Snowflake AI Demo - Complete Setup Script
    -- This script creates the database, schema, tables, and loads all data
    -- Repository: https://github.com/NickAkincilar/Snowflake_AI_DEMO.git
    -- ========================================================================

    

    -- Switch to accountadmin role to create warehouse
    USE ROLE accountadmin;

    create or replace role SF_Intelligence_Demo;


    SET current_user_name = CURRENT_USER();
    
    -- Step 2: Use the variable to grant the role
    GRANT ROLE SF_Intelligence_Demo TO USER IDENTIFIER($current_user_name);
    GRANT CREATE DATABASE ON ACCOUNT TO ROLE SF_Intelligence_Demo;
    
    -- Create a dedicated warehouse for the demo with auto-suspend/resume
    CREATE OR REPLACE WAREHOUSE Snow_Intelligence_demo_wh 
        WITH WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 300
        AUTO_RESUME = TRUE;


    -- Grant usage on warehouse to admin role
    GRANT USAGE ON WAREHOUSE SNOW_INTELLIGENCE_DEMO_WH TO ROLE SF_Intelligence_Demo;


   -- Alter current user's default role and warehouse to the ones used here
    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SF_Intelligence_Demo;
    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = Snow_Intelligence_demo_wh;
    

    -- Switch to accuntadmin role to create demo objects
    use role SF_Intelligence_Demo;
   
    -- Create database and schema
    CREATE DATABASE IF NOT EXISTS SF_AI_DEMO;
    USE DATABASE SF_AI_DEMO;

    CREATE SCHEMA IF NOT EXISTS DEMO_SCHEMA;
    USE SCHEMA DEMO_SCHEMA;

    -- Create file format for CSV files
    CREATE OR REPLACE FILE FORMAT CSV_FORMAT
        TYPE = 'CSV'
        FIELD_DELIMITER = ','
        RECORD_DELIMITER = '\n'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        TRIM_SPACE = TRUE
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        ESCAPE = 'NONE'
        ESCAPE_UNENCLOSED_FIELD = '\134'
        DATE_FORMAT = 'YYYY-MM-DD'
        TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
        NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');


use role accountadmin;
    -- Create API Integration for GitHub (public repository access)
    CREATE OR REPLACE API INTEGRATION git_api_integration
        API_PROVIDER = git_https_api
        API_ALLOWED_PREFIXES = ('https://github.com/NickAkincilar/')
        ENABLED = TRUE;


GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SF_Intelligence_Demo;


use role SF_Intelligence_Demo;
    -- Create Git repository integration for the public demo repository
    CREATE OR REPLACE GIT REPOSITORY SF_AI_DEMO_REPO
        API_INTEGRATION = git_api_integration
        ORIGIN = 'https://github.com/NickAkincilar/Snowflake_AI_DEMO.git';

    -- Create internal stage for copied data files
    CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
        FILE_FORMAT = CSV_FORMAT
        COMMENT = 'Internal stage for copied demo data files'
        DIRECTORY = ( ENABLE = TRUE)
        ENCRYPTION = (   TYPE = 'SNOWFLAKE_SSE');

    ALTER GIT REPOSITORY SF_AI_DEMO_REPO FETCH;

    -- ========================================================================
    -- COPY DATA FROM GIT TO INTERNAL STAGE
    -- ========================================================================

    -- Copy all CSV files from Git repository demo_data folder to internal stage
    COPY FILES
    INTO @INTERNAL_DATA_STAGE/demo_data/
    FROM @SF_AI_DEMO_REPO/branches/main/demo_data/;


    COPY FILES
    INTO @INTERNAL_DATA_STAGE/unstructured_docs/
    FROM @SF_AI_DEMO_REPO/branches/main/unstructured_docs/;

    -- Verify files were copied
    LS @INTERNAL_DATA_STAGE;

    ALTER STAGE INTERNAL_DATA_STAGE refresh;

  

    -- ========================================================================
    -- DIMENSION TABLES
    -- ========================================================================

    -- Product Category Dimension
    CREATE OR REPLACE TABLE product_category_dim (
        category_key INT PRIMARY KEY,
        category_name VARCHAR(100) NOT NULL,
        vertical VARCHAR(50) NOT NULL
    );

    -- Product Dimension
    CREATE OR REPLACE TABLE product_dim (
        product_key INT PRIMARY KEY,
        product_name VARCHAR(200) NOT NULL,
        category_key INT NOT NULL,
        category_name VARCHAR(100),
        vertical VARCHAR(50)
    );

    -- Vendor Dimension
    CREATE OR REPLACE TABLE vendor_dim (
        vendor_key INT PRIMARY KEY,
        vendor_name VARCHAR(200) NOT NULL,
        vertical VARCHAR(50) NOT NULL,
        address VARCHAR(200),
        city VARCHAR(100),
        state VARCHAR(10),
        zip VARCHAR(20)
    );

    -- Customer Dimension
    CREATE OR REPLACE TABLE customer_dim (
        customer_key INT PRIMARY KEY,
        customer_name VARCHAR(200) NOT NULL,
        industry VARCHAR(100),
        vertical VARCHAR(50),
        address VARCHAR(200),
        city VARCHAR(100),
        state VARCHAR(10),
        zip VARCHAR(20)
    );

    -- Account Dimension (Finance)
    CREATE OR REPLACE TABLE account_dim (
        account_key INT PRIMARY KEY,
        account_name VARCHAR(100) NOT NULL,
        account_type VARCHAR(50)
    );

    -- Department Dimension
    CREATE OR REPLACE TABLE department_dim (
        department_key INT PRIMARY KEY,
        department_name VARCHAR(100) NOT NULL
    );

    -- Region Dimension
    CREATE OR REPLACE TABLE region_dim (
        region_key INT PRIMARY KEY,
        region_name VARCHAR(100) NOT NULL
    );

    -- Sales Rep Dimension
    CREATE OR REPLACE TABLE sales_rep_dim (
        sales_rep_key INT PRIMARY KEY,
        rep_name VARCHAR(200) NOT NULL,
        hire_date DATE
    );

    -- Campaign Dimension (Marketing)
    CREATE OR REPLACE TABLE campaign_dim (
        campaign_key INT PRIMARY KEY,
        campaign_name VARCHAR(300) NOT NULL,
        objective VARCHAR(100)
    );

    -- Channel Dimension (Marketing)
    CREATE OR REPLACE TABLE channel_dim (
        channel_key INT PRIMARY KEY,
        channel_name VARCHAR(100) NOT NULL
    );

    -- Employee Dimension (HR)
    CREATE OR REPLACE TABLE employee_dim (
        employee_key INT PRIMARY KEY,
        employee_name VARCHAR(200) NOT NULL,
        gender VARCHAR(1),
        hire_date DATE
    );

    -- Job Dimension (HR)
    CREATE OR REPLACE TABLE job_dim (
        job_key INT PRIMARY KEY,
        job_title VARCHAR(100) NOT NULL,
        job_level INT
    );

    -- Location Dimension (HR)
    CREATE OR REPLACE TABLE location_dim (
        location_key INT PRIMARY KEY,
        location_name VARCHAR(200) NOT NULL
    );

    -- ========================================================================
    -- FACT TABLES
    -- ========================================================================

    -- Sales Fact Table
    CREATE OR REPLACE TABLE sales_fact (
        sale_id INT PRIMARY KEY,
        date DATE NOT NULL,
        customer_key INT NOT NULL,
        product_key INT NOT NULL,
        sales_rep_key INT NOT NULL,
        region_key INT NOT NULL,
        vendor_key INT NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        units INT NOT NULL
    );

    -- Finance Transactions Fact Table
    CREATE OR REPLACE TABLE finance_transactions (
        transaction_id INT PRIMARY KEY,
        date DATE NOT NULL,
        account_key INT NOT NULL,
        department_key INT NOT NULL,
        vendor_key INT NOT NULL,
        product_key INT NOT NULL,
        customer_key INT NOT NULL,
        amount DECIMAL(12,2) NOT NULL
    );

    -- Marketing Campaign Fact Table
    CREATE OR REPLACE TABLE marketing_campaign_fact (
        campaign_fact_id INT PRIMARY KEY,
        date DATE NOT NULL,
        campaign_key INT NOT NULL,
        product_key INT NOT NULL,
        channel_key INT NOT NULL,
        region_key INT NOT NULL,
        spend DECIMAL(10,2) NOT NULL,
        leads_generated INT NOT NULL,
        impressions INT NOT NULL
    );

    -- HR Employee Fact Table
    CREATE OR REPLACE TABLE hr_employee_fact (
        hr_fact_id INT PRIMARY KEY,
        date DATE NOT NULL,
        employee_key INT NOT NULL,
        department_key INT NOT NULL,
        job_key INT NOT NULL,
        location_key INT NOT NULL,
        salary DECIMAL(10,2) NOT NULL,
        attrition_flag INT NOT NULL
    );

    -- ========================================================================
    -- LOAD DIMENSION DATA FROM INTERNAL STAGE
    -- ========================================================================

    -- Load Product Category Dimension
    COPY INTO product_category_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/product_category_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Product Dimension
    COPY INTO product_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/product_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Vendor Dimension
    COPY INTO vendor_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/vendor_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Customer Dimension
    COPY INTO customer_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/customer_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Account Dimension
    COPY INTO account_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/account_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Department Dimension
    COPY INTO department_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/department_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Region Dimension
    COPY INTO region_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/region_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Sales Rep Dimension
    COPY INTO sales_rep_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/sales_rep_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Campaign Dimension
    COPY INTO campaign_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/campaign_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Channel Dimension
    COPY INTO channel_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/channel_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Employee Dimension
    COPY INTO employee_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/employee_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Job Dimension
    COPY INTO job_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/job_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Location Dimension
    COPY INTO location_dim
    FROM @INTERNAL_DATA_STAGE/demo_data/location_dim.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- ========================================================================
    -- LOAD FACT DATA FROM INTERNAL STAGE
    -- ========================================================================

    -- Load Sales Fact
    COPY INTO sales_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/sales_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Finance Transactions
    COPY INTO finance_transactions
    FROM @INTERNAL_DATA_STAGE/demo_data/finance_transactions.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load Marketing Campaign Fact
    COPY INTO marketing_campaign_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/marketing_campaign_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- Load HR Employee Fact
    COPY INTO hr_employee_fact
    FROM @INTERNAL_DATA_STAGE/demo_data/hr_employee_fact.csv
    FILE_FORMAT = CSV_FORMAT
    ON_ERROR = 'CONTINUE';

    -- ========================================================================
    -- VERIFICATION
    -- ========================================================================

    -- Verify Git integration and file copy
    SHOW GIT REPOSITORIES;
   -- SELECT 'Internal Stage Files' as stage_type, COUNT(*) as file_count FROM (LS @INTERNAL_DATA_STAGE);

    -- Verify data loads
    SELECT 'DIMENSION TABLES' as category, '' as table_name, NULL as row_count
    UNION ALL
    SELECT '', 'product_category_dim', COUNT(*) FROM product_category_dim
    UNION ALL
    SELECT '', 'product_dim', COUNT(*) FROM product_dim
    UNION ALL
    SELECT '', 'vendor_dim', COUNT(*) FROM vendor_dim
    UNION ALL
    SELECT '', 'customer_dim', COUNT(*) FROM customer_dim
    UNION ALL
    SELECT '', 'account_dim', COUNT(*) FROM account_dim
    UNION ALL
    SELECT '', 'department_dim', COUNT(*) FROM department_dim
    UNION ALL
    SELECT '', 'region_dim', COUNT(*) FROM region_dim
    UNION ALL
    SELECT '', 'sales_rep_dim', COUNT(*) FROM sales_rep_dim
    UNION ALL
    SELECT '', 'campaign_dim', COUNT(*) FROM campaign_dim
    UNION ALL
    SELECT '', 'channel_dim', COUNT(*) FROM channel_dim
    UNION ALL
    SELECT '', 'employee_dim', COUNT(*) FROM employee_dim
    UNION ALL
    SELECT '', 'job_dim', COUNT(*) FROM job_dim
    UNION ALL
    SELECT '', 'location_dim', COUNT(*) FROM location_dim
    UNION ALL
    SELECT '', '', NULL
    UNION ALL
    SELECT 'FACT TABLES', '', NULL
    UNION ALL
    SELECT '', 'sales_fact', COUNT(*) FROM sales_fact
    UNION ALL
    SELECT '', 'finance_transactions', COUNT(*) FROM finance_transactions
    UNION ALL
    SELECT '', 'marketing_campaign_fact', COUNT(*) FROM marketing_campaign_fact
    UNION ALL
    SELECT '', 'hr_employee_fact', COUNT(*) FROM hr_employee_fact;

    -- Show all tables
    SHOW TABLES IN SCHEMA DEMO_SCHEMA; 




  -- ========================================================================
  -- Snowflake AI Demo - Semantic Views for Cortex Analyst
  -- Creates business unit-specific semantic views for natural language queries
  -- Based on: https://docs.snowflake.com/en/user-guide/views-semantic/sql
  -- ========================================================================
  USE ROLE SF_Intelligence_Demo;
  USE DATABASE SF_AI_DEMO;
  USE SCHEMA DEMO_SCHEMA;

  -- ========================================================================
  -- FINANCE SEMANTIC VIEW
  -- ========================================================================

 create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.FINANCE_SEMANTIC_VIEW
	tables (
		TRANSACTIONS as FINANCE_TRANSACTIONS primary key (TRANSACTION_ID) with synonyms=('finance transactions','financial data') comment='All financial transactions across departments',
		ACCOUNTS as ACCOUNT_DIM primary key (ACCOUNT_KEY) with synonyms=('chart of accounts','account types') comment='Account dimension for financial categorization',
		DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('business units','departments') comment='Department dimension for cost center analysis',
		VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for spend analysis',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for transaction analysis',
		CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers') comment='Customer dimension for revenue analysis'
	)
	relationships (
		TRANSACTIONS_TO_ACCOUNTS as TRANSACTIONS(ACCOUNT_KEY) references ACCOUNTS(ACCOUNT_KEY),
		TRANSACTIONS_TO_DEPARTMENTS as TRANSACTIONS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
		TRANSACTIONS_TO_VENDORS as TRANSACTIONS(VENDOR_KEY) references VENDORS(VENDOR_KEY),
		TRANSACTIONS_TO_PRODUCTS as TRANSACTIONS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		TRANSACTIONS_TO_CUSTOMERS as TRANSACTIONS(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY)
	)
	facts (
		TRANSACTIONS.TRANSACTION_AMOUNT as amount comment='Transaction amount in dollars',
		TRANSACTIONS.TRANSACTION_RECORD as 1 comment='Count of transactions'
	)
	dimensions (
		TRANSACTIONS.TRANSACTION_DATE as date with synonyms=('date','transaction date') comment='Date of the financial transaction',
		TRANSACTIONS.TRANSACTION_MONTH as MONTH(date) comment='Month of the transaction',
		TRANSACTIONS.TRANSACTION_YEAR as YEAR(date) comment='Year of the transaction',
		ACCOUNTS.ACCOUNT_NAME as account_name with synonyms=('account','account type') comment='Name of the account',
		ACCOUNTS.ACCOUNT_TYPE as account_type with synonyms=('type','category') comment='Type of account (Income/Expense)',
		DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','business unit') comment='Name of the department',
		VENDORS.VENDOR_NAME as vendor_name with synonyms=('vendor','supplier') comment='Name of the vendor',
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item') comment='Name of the product',
		CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','client') comment='Name of the customer'
	)
	metrics (
		TRANSACTIONS.AVERAGE_AMOUNT as AVG(transactions.amount) comment='Average transaction amount',
		TRANSACTIONS.TOTAL_AMOUNT as SUM(transactions.amount) comment='Total transaction amount',
		TRANSACTIONS.TOTAL_TRANSACTIONS as COUNT(transactions.transaction_record) comment='Total number of transactions'
	)
	comment='Semantic view for financial analysis and reporting';



  -- ========================================================================
  -- SALES SEMANTIC VIEW
  -- ========================================================================

create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.SALES_SEMANTIC_VIEW
	tables (
		CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers','accounts') comment='Customer information for sales analysis',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items','SKUs') comment='Product catalog for sales analysis',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','areas') comment='Regional information for territory analysis',
		SALES as SALES_FACT primary key (SALE_ID) with synonyms=('sales transactions','sales data') comment='All sales transactions and deals',
		SALES_REPS as SALES_REP_DIM primary key (SALES_REP_KEY) with synonyms=('sales representatives','reps','salespeople') comment='Sales representative information',
		VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for supply chain analysis',
		PRODUCT_CATEGORY_DIM primary key (CATEGORY_KEY)
	)
	relationships (
		PRODUCT_TO_CATEGORY as PRODUCTS(CATEGORY_KEY) references PRODUCT_CATEGORY_DIM(CATEGORY_KEY),
		SALES_TO_CUSTOMERS as SALES(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY),
		SALES_TO_PRODUCTS as SALES(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		SALES_TO_REGIONS as SALES(REGION_KEY) references REGIONS(REGION_KEY),
		SALES_TO_REPS as SALES(SALES_REP_KEY) references SALES_REPS(SALES_REP_KEY),
		SALES_TO_VENDORS as SALES(VENDOR_KEY) references VENDORS(VENDOR_KEY)
	)
	facts (
		SALES.SALE_AMOUNT as amount comment='Sale amount in dollars',
		SALES.SALE_RECORD as 1 comment='Count of sales transactions',
		SALES.UNITS_SOLD as units comment='Number of units sold'
	)
	dimensions (
		CUSTOMERS.CUSTOMER_KEY as CUSTOMER_KEY,
		CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','client','account') comment='Name of the customer',
		CUSTOMERS.INDUSTRY as 'customer_industry' with synonyms=('industry','customer type') comment='Customer industry',
		PRODUCTS.CATEGORY_KEY as CATEGORY_KEY with synonyms=('category_id','product_category','category_code','classification_key','group_key','product_group_id') comment='Unique identifier for the product category.',
		PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item') comment='Name of the product',
		REGIONS.REGION_KEY as REGION_KEY,
		REGIONS.REGION_NAME as region_name with synonyms=('region','territory','area') comment='Name of the region',
		SALES.CUSTOMER_KEY as CUSTOMER_KEY,
		SALES.PRODUCT_KEY as PRODUCT_KEY,
		SALES.REGION_KEY as REGION_KEY,
		SALES.SALES_REP_KEY as SALES_REP_KEY,
		SALES.SALE_DATE as date with synonyms=('date','sale date','transaction date') comment='Date of the sale',
		SALES.SALE_ID as SALE_ID,
		SALES.SALE_MONTH as MONTH(date) comment='Month of the sale',
		SALES.SALE_YEAR as YEAR(date) comment='Year of the sale',
		SALES.VENDOR_KEY as VENDOR_KEY,
		SALES_REPS.SALES_REP_KEY as SALES_REP_KEY,
		SALES_REPS.SALES_REP_NAME as REP_NAME with synonyms=('sales rep','representative','salesperson') comment='Name of the sales representative',
		VENDORS.VENDOR_KEY as VENDOR_KEY,
		VENDORS.VENDOR_NAME as vendor_name with synonyms=('vendor','supplier','provider') comment='Name of the vendor',
		PRODUCT_CATEGORY_DIM.CATEGORY_KEY as CATEGORY_KEY with synonyms=('category_id','category_code','product_category_number','category_identifier','classification_key') comment='Unique identifier for a product category.',
		PRODUCT_CATEGORY_DIM.CATEGORY_NAME as CATEGORY_NAME with synonyms=('category_title','product_group','classification_name','category_label','product_category_description') comment='The category to which a product belongs, such as electronics, clothing, or software as a service.',
		PRODUCT_CATEGORY_DIM.VERTICAL as VERTICAL with synonyms=('industry','sector','market','category_group','business_area','domain') comment='The industry or sector in which a product is categorized, such as retail, technology, or manufacturing.'
	)
	metrics (
		SALES.AVERAGE_DEAL_SIZE as AVG(sales.amount) comment='Average deal size',
		SALES.AVERAGE_UNITS_PER_SALE as AVG(sales.units) comment='Average units per sale',
		SALES.TOTAL_DEALS as COUNT(sales.sale_record) comment='Total number of deals',
		SALES.TOTAL_REVENUE as SUM(sales.amount) comment='Total sales revenue',
		SALES.TOTAL_UNITS as SUM(sales.units) comment='Total units sold'
	)
	comment='Semantic view for sales analysis and performance tracking'
	with extension (CA='{"tables":[{"name":"CUSTOMERS","dimensions":[{"name":"CUSTOMER_KEY"},{"name":"CUSTOMER_NAME"},{"name":"INDUSTRY"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME"},{"name":"CATEGORY_KEY","unique":false}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME"}]},{"name":"SALES","dimensions":[{"name":"CUSTOMER_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"},{"name":"SALES_REP_KEY"},{"name":"SALE_DATE"},{"name":"SALE_ID"},{"name":"SALE_MONTH"},{"name":"SALE_YEAR"},{"name":"VENDOR_KEY"}],"facts":[{"name":"SALE_AMOUNT"},{"name":"SALE_RECORD"},{"name":"UNITS_SOLD"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"AVERAGE_UNITS_PER_SALE"},{"name":"TOTAL_DEALS"},{"name":"TOTAL_REVENUE"},{"name":"TOTAL_UNITS"}]},{"name":"SALES_REPS","dimensions":[{"name":"SALES_REP_KEY"},{"name":"SALES_REP_NAME"}]},{"name":"VENDORS","dimensions":[{"name":"VENDOR_KEY"},{"name":"VENDOR_NAME"}]},{"name":"PRODUCT_CATEGORY_DIM","dimensions":[{"name":"CATEGORY_NAME","sample_values":["Electronics","Apparel","SaaS"]},{"name":"VERTICAL","sample_values":["Retail","Tech","Manufacturing"]},{"name":"CATEGORY_KEY","sample_values":["1","2","3"]}]}],"relationships":[{"name":"SALES_TO_CUSTOMERS","relationship_type":"many_to_one"},{"name":"SALES_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"SALES_TO_REGIONS","relationship_type":"many_to_one"},{"name":"SALES_TO_REPS","relationship_type":"many_to_one"},{"name":"SALES_TO_VENDORS","relationship_type":"many_to_one"},{"name":"PRODUCT_TO_CATEGORY"}]}');




  -- ========================================================================
  -- MARKETING SEMANTIC VIEW
  -- ========================================================================

    create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.MARKETING_SEMANTIC_VIEW
	tables (
		CAMPAIGNS as MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('marketing campaigns','campaign data') comment='Marketing campaign performance data',
		CAMPAIGN_DETAILS as CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign details') comment='Campaign dimension with objectives and names',
		CHANNELS as CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('marketing channels','channels') comment='Marketing channel information',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','markets') comment='Regional information for campaign analysis',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for campaign-specific analysis'
	)
	relationships (
		CAMPAIGNS_TO_DETAILS as CAMPAIGNS(CAMPAIGN_KEY) references CAMPAIGN_DETAILS(CAMPAIGN_KEY),
		CAMPAIGNS_TO_CHANNELS as CAMPAIGNS(CHANNEL_KEY) references CHANNELS(CHANNEL_KEY),
		CAMPAIGNS_TO_REGIONS as CAMPAIGNS(REGION_KEY) references REGIONS(REGION_KEY),
		CAMPAIGNS_TO_PRODUCTS as CAMPAIGNS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY)
	)
	facts (
		CAMPAIGNS.CAMPAIGN_RECORD as 1 comment='Count of campaign activities',
		CAMPAIGNS.CAMPAIGN_SPEND as spend comment='Marketing spend in dollars',
		CAMPAIGNS.IMPRESSIONS as impressions comment='Number of impressions',
		CAMPAIGNS.LEADS_GENERATED as leads_generated comment='Number of leads generated'
	)
	dimensions (
		CAMPAIGNS.CAMPAIGN_DATE as date with synonyms=('date','campaign date') comment='Date of the campaign activity',
		CAMPAIGNS.CAMPAIGN_MONTH as MONTH(date) comment='Month of the campaign',
		CAMPAIGNS.CAMPAIGN_YEAR as YEAR(date) comment='Year of the campaign',
		CAMPAIGNS.PRODUCT_KEY as product_key with synonyms=('product_id','product identifier') comment='Product identifier for campaign targeting',
		CAMPAIGN_DETAILS.CAMPAIGN_NAME as campaign_name with synonyms=('campaign','campaign title') comment='Name of the marketing campaign',
		CAMPAIGN_DETAILS.OBJECTIVE as 'campaign_objective' with synonyms=('objective','goal','purpose') comment='Campaign objective',
		CHANNELS.CHANNEL_NAME as channel_name with synonyms=('channel','marketing channel') comment='Name of the marketing channel',
		REGIONS.REGION_NAME as region_name with synonyms=('region','market','territory') comment='Name of the region',
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item','product title') comment='Name of the product being promoted',
		PRODUCTS.PRODUCT_CATEGORY as category_name with synonyms=('category','product category') comment='Category of the product',
		PRODUCTS.PRODUCT_VERTICAL as vertical with synonyms=('vertical','industry') comment='Business vertical of the product'
	)
	metrics (
		CAMPAIGNS.AVERAGE_SPEND as AVG(campaigns.spend) comment='Average campaign spend',
		CAMPAIGNS.TOTAL_CAMPAIGNS as COUNT(campaigns.campaign_record) comment='Total number of campaign activities',
		CAMPAIGNS.TOTAL_IMPRESSIONS as SUM(campaigns.impressions) comment='Total impressions',
		CAMPAIGNS.TOTAL_LEADS as SUM(campaigns.leads_generated) comment='Total leads generated',
		CAMPAIGNS.TOTAL_SPEND as SUM(campaigns.spend) comment='Total marketing spend'
	)
	comment='Semantic view for marketing campaign analysis and ROI tracking with product-specific insights';

  -- ========================================================================
  -- HR SEMANTIC VIEW
  -- ========================================================================
create or replace semantic view SF_AI_DEMO.DEMO_SCHEMA.HR_SEMANTIC_VIEW
	tables (
		DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('departments','business units') comment='Department dimension for organizational analysis',
		EMPLOYEES as EMPLOYEE_DIM primary key (EMPLOYEE_KEY) with synonyms=('employees','staff','workforce') comment='Employee dimension with personal information',
		HR_RECORDS as HR_EMPLOYEE_FACT primary key (HR_FACT_ID) with synonyms=('hr data','employee records') comment='HR employee fact data for workforce analysis',
		JOBS as JOB_DIM primary key (JOB_KEY) with synonyms=('job titles','positions','roles') comment='Job dimension with titles and levels',
		LOCATIONS as LOCATION_DIM primary key (LOCATION_KEY) with synonyms=('locations','offices','sites') comment='Location dimension for geographic analysis'
	)
	relationships (
		HR_TO_DEPARTMENTS as HR_RECORDS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
		HR_TO_EMPLOYEES as HR_RECORDS(EMPLOYEE_KEY) references EMPLOYEES(EMPLOYEE_KEY),
		HR_TO_JOBS as HR_RECORDS(JOB_KEY) references JOBS(JOB_KEY),
		HR_TO_LOCATIONS as HR_RECORDS(LOCATION_KEY) references LOCATIONS(LOCATION_KEY)
	)
	facts (
		HR_RECORDS.ATTRITION_FLAG as attrition_flag with synonyms=('turnover_indicator','employee_departure_flag','separation_flag','employee_retention_status','churn_status','employee_exit_indicator') comment='Attrition flag. value is 0 if employee is currently active. 1 if employee quit & left the company. Always filter by 0 to show active employees unless specified otherwise',
		HR_RECORDS.EMPLOYEE_RECORD as 1 comment='Count of employee records',
		HR_RECORDS.EMPLOYEE_SALARY as salary comment='Employee salary in dollars'
	)
	dimensions (
		DEPARTMENTS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','business unit','division') comment='Name of the department',
		EMPLOYEES.EMPLOYEE_KEY as EMPLOYEE_KEY,
		EMPLOYEES.EMPLOYEE_NAME as employee_name with synonyms=('employee','staff member','person','sales rep','manager','director','executive') comment='Name of the employee',
		EMPLOYEES.GENDER as gender with synonyms=('gender','sex') comment='Employee gender',
		EMPLOYEES.HIRE_DATE as hire_date with synonyms=('hire date','start date') comment='Date when employee was hired',
		HR_RECORDS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		HR_RECORDS.EMPLOYEE_KEY as EMPLOYEE_KEY,
		HR_RECORDS.HR_FACT_ID as HR_FACT_ID,
		HR_RECORDS.JOB_KEY as JOB_KEY,
		HR_RECORDS.LOCATION_KEY as LOCATION_KEY,
		HR_RECORDS.RECORD_DATE as date with synonyms=('date','record date') comment='Date of the HR record',
		HR_RECORDS.RECORD_MONTH as MONTH(date) comment='Month of the HR record',
		HR_RECORDS.RECORD_YEAR as YEAR(date) comment='Year of the HR record',
		JOBS.JOB_KEY as JOB_KEY,
		JOBS.JOB_LEVEL as job_level with synonyms=('level','grade','seniority') comment='Job level or grade',
		JOBS.JOB_TITLE as job_title with synonyms=('job title','position','role') comment='Employee job title',
		LOCATIONS.LOCATION_KEY as LOCATION_KEY,
		LOCATIONS.LOCATION_NAME as location_name with synonyms=('location','office','site') comment='Work location'
	)
	metrics (
		HR_RECORDS.ATTRITION_COUNT as SUM(hr_records.attrition_flag) comment='Number of employees who left',
		HR_RECORDS.AVG_SALARY as AVG(hr_records.employee_salary) comment='average employee salary',
		HR_RECORDS.TOTAL_EMPLOYEES as COUNT(hr_records.employee_record) comment='Total number of employees',
		HR_RECORDS.TOTAL_SALARY_COST as SUM(hr_records.EMPLOYEE_SALARY) comment='Total salary cost'
	)
	comment='Semantic view for HR analytics and workforce management'
	with extension (CA='{"tables":[{"name":"DEPARTMENTS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"DEPARTMENT_NAME"}]},{"name":"EMPLOYEES","dimensions":[{"name":"EMPLOYEE_KEY"},{"name":"EMPLOYEE_NAME"},{"name":"GENDER"},{"name":"HIRE_DATE"}]},{"name":"HR_RECORDS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"EMPLOYEE_KEY"},{"name":"HR_FACT_ID"},{"name":"JOB_KEY"},{"name":"LOCATION_KEY"},{"name":"RECORD_DATE"},{"name":"RECORD_MONTH"},{"name":"RECORD_YEAR"}],"facts":[{"name":"ATTRITION_FLAG","sample_values":["0","1"]},{"name":"EMPLOYEE_RECORD"},{"name":"EMPLOYEE_SALARY"}],"metrics":[{"name":"ATTRITION_COUNT"},{"name":"AVG_SALARY"},{"name":"TOTAL_EMPLOYEES"},{"name":"TOTAL_SALARY_COST"}]},{"name":"JOBS","dimensions":[{"name":"JOB_KEY"},{"name":"JOB_LEVEL"},{"name":"JOB_TITLE"}]},{"name":"LOCATIONS","dimensions":[{"name":"LOCATION_KEY"},{"name":"LOCATION_NAME"}]}],"relationships":[{"name":"HR_TO_DEPARTMENTS","relationship_type":"many_to_one"},{"name":"HR_TO_EMPLOYEES","relationship_type":"many_to_one"},{"name":"HR_TO_JOBS","relationship_type":"many_to_one"},{"name":"HR_TO_LOCATIONS","relationship_type":"many_to_one"}],"verified_queries":[{"name":"List of all active employees","question":"List of all active employees","sql":"select\\n  h.employee_key,\\n  e.employee_name,\\nfrom\\n  employees e\\n  left join hr_records h on e.employee_key = h.employee_key\\ngroup by\\n  all\\nhaving\\n  sum(h.attrition_flag) = 0;","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846263},{"name":"List of all inactive employees","question":"List of all inactive employees","sql":"SELECT\\n  h.employee_key,\\n  e.employee_name\\nFROM\\n  employees AS e\\n  LEFT JOIN hr_records AS h ON e.employee_key = h.employee_key\\nGROUP BY\\n  ALL\\nHAVING\\n  SUM(h.attrition_flag) > 0","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846300}],"custom_instructions":"- Each employee can have multiple hr_employee_fact records. \\n- Only one hr_employee_fact record per employee is valid and that is the one which has the highest date value."}');

  -- ========================================================================
  -- VERIFICATION
  -- ========================================================================

  -- Show all semantic views
  SHOW SEMANTIC VIEWS;

  -- Show dimensions for each semantic view
  SHOW SEMANTIC DIMENSIONS;

  -- Show metrics for each semantic view
  SHOW SEMANTIC METRICS; 







    -- ========================================================================
    -- UNSTRUCTURED DATA
    -- ========================================================================
create or replace table parsed_content as 
select 
   
    relative_path, 
    BUILD_STAGE_FILE_URL('@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE', relative_path) as file_url,
     TO_File(BUILD_STAGE_FILE_URL('@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE', relative_path) ) file_object,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                                    @SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE,
                                    relative_path,
                                    {'mode':'LAYOUT'}
                                    )::varchar as Content
    from directory(@SF_AI_DEMO.DEMO_SCHEMA.INTERNAL_DATA_STAGE) 
where relative_path ilike 'unstructured_docs/%.pdf' ;




select * from parsed_content;
    -- Switch to admin role for remaining operations
    USE ROLE SF_Intelligence_Demo;

    -- Create search service for finance documents
    -- This enables semantic search over finance-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_finance_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title, -- Extract filename as title
                content
            FROM parsed_content
            WHERE relative_path ilike '%/finance/%'
        );
    
    -- Create search service for HR documents
    -- This enables semantic search over HR-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_hr_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/hr/%'
        );

    -- Create search service for marketing documents
    -- This enables semantic search over marketing-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_marketing_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/marketing/%'
        );

    -- Create search service for sales documents
    -- This enables semantic search over sales-related content
    CREATE OR REPLACE CORTEX SEARCH SERVICE Search_sales_docs
        ON content
        ATTRIBUTES relative_path, file_url, title
        WAREHOUSE = SNOW_INTELLIGENCE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT
                relative_path,
                file_url,
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%/sales/%'
        );









use role accountadmin;


GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SF_Intelligence_Demo;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;

use role SF_Intelligence_Demo;
-- CREATES A SNOWFLAKE INTELLIGENCE AGENT WITH MULTIPLE TOOLS

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.Company_Chatbot_Agent_Retail
WITH PROFILE='{ "display_name": "Company Chatbot Agent - Retail" }'
    COMMENT=$$ This is an agent that can answer questions about company specific Sales, Marketing, HR & Finance questions. $$
FROM SPECIFICATION $$
{
    "models": { "orchestration": "auto" },
    "instructions": {
        "response": "You are a data analyst who has access to sales, finance, marketing & HR datamarts.  If user does not specify a date range assume it for year 2025. Leverage data from all domains to analyse & answer user questions. Provide visualizations if possible. Trendlines should default to linecharts, Categories Barchart.",
        
        "orchestration": "Use cortex search for known entities and pass the results to cortex analyst for detailed analysis. 
        
                        If answering sales related question from datamart, Always make sure to include the product_dim table & filter product VERTICAL by 'Retail' for all questions but don't show this fact while explaining thinking steps.",
        
        "sample_questions": [
            { "question": "What are our monthly sales last 12 months?" }
        ]
    },
    "tools": [
        {
            "tool_spec": {
            "name": "Search Internal Documents: Finance",
            "type": "cortex_search"
            }
        },

        {
            "tool_spec": {
            "name": "Search Internal Documents: HR",
            "type": "cortex_search"
            }
        },

        {
            "tool_spec": {
            "name": "Search Internal Documents: Sales",
            "type": "cortex_search"
            }
        },

        {
            "tool_spec": {
            "name": "Search Internal Documents: Marketing",
            "type": "cortex_search"
            }
        },
        
        {
            "tool_spec": {
            "description": "Allows users to query finance data for a company in terms of revenue & expenses.",
            "name": "Query Finance Datamart",
            "type": "cortex_analyst_text_to_sql"
        
            }
        },
        
        {
            "tool_spec": {
            "description": "Allows users to query Sales data for a company in terms of Sales data such as products, sales reps & etc. ",
            "name": "Query Sales Datamart",
            "type": "cortex_analyst_text_to_sql"
            }
        },
        
        {
            "tool_spec": {
            "description": "Allows users to query HR data for a company in terms of HR related employee data. 
                            employee_name column also contains names of sales_reps.",
            "name": "Query HR Datamart",
            "type": "cortex_analyst_text_to_sql"
            }
        },
        
        {
            "tool_spec": {
            "description": "Allows users to query Marketing data in terms of campaigns, channels, impressions, spend & etc.",
            "name": "Query Marketing Datamart",
            "type": "cortex_analyst_text_to_sql"
            }
        }
    ],
    "tool_resources": {
        "Search Internal Documents: Finance": {
            "id_column": "FILE_URL",
            "title_column": "TITLE",
            "max_results": 5,
            "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_FINANCE_DOCS"
        },

        "Search Internal Documents: HR": {
            "id_column": "FILE_URL",
            "title_column": "TITLE",
            "max_results": 5,
            "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_HR_DOCS"
        },

        "Search Internal Documents: Marketing": {
            "id_column": "FILE_URL",
            "title_column": "TITLE",
            "max_results": 5,
            "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_MARKETING_DOCS"
        },

        "Search Internal Documents: Sales": {
            "id_column": "FILE_URL",
            "title_column": "TITLE",
            "max_results": 5,
            "name": "SF_AI_DEMO.DEMO_SCHEMA.SEARCH_SALES_DOCS"
        },


        
        "Query Finance Datamart": {
            "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.FINANCE_SEMANTIC_VIEW"
        },
        
        "Query Sales Datamart": {
            "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.SALES_SEMANTIC_VIEW"
        },
        
        "Query HR Datamart": {
            "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.HR_SEMANTIC_VIEW"
        },
        
        "Query Marketing Datamart": {
            "semantic_view": "SF_AI_DEMO.DEMO_SCHEMA.MARKETING_SEMANTIC_VIEW"
        }
        }
}
$$;

