# 🌐 Coinbase AWS Data Lake Formation Pipeline

## 🧭 Overview

This project builds a **production-grade AWS data lakehouse architecture** for real-time cryptocurrency price ingestion and analytics using **Coinbase API → Lambda → Kinesis → S3 → Glue → Lake Formation → Athena → DataZone**.  

All infrastructure is defined and deployed using **Terraform**, featuring **KMS encryption**, **CloudWatch monitoring**, **EventBridge scheduling**, and **automated data cataloging** with AWS Glue.

---

## 🧰 Prerequisites

### 1️⃣ AWS CLI Installation

The **AWS CLI** is essential for managing credentials and configuring your environment. Follow these steps for installation:

**macOS Installation:**
```bash
brew install awscli
```

**Verify Installation:**
```bash
aws --version
```

**Windows Installation:**  
For Windows users, refer to the official [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

---

### 2️⃣ Verify AWS Identity

Before proceeding, verify which AWS user or role will execute Terraform:

```bash
aws sts get-caller-identity
```

**Important:** The returned user ARN must be declared in the `terraform_user` variable within the `glue_catalog_module/variables.tf` file. This ensures proper Lake Formation permissions.

---

### 3️⃣ Terraform Environment Configuration

**Check if the S3 Bucket Exists:**
```bash
aws s3api head-bucket --bucket your_bucket
```

**Create DynamoDB Table for Terraform State Locking:**
```bash
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region your_region
```

**Create S3 Bucket for Terraform State:**
```bash
aws s3api create-bucket \
  --bucket your_bucket \
  --region your_region \
  --create-bucket-configuration LocationConstraint=your_region
```

**Apply Bucket Policies:**
```bash
aws s3api put-public-access-block \
  --bucket your_bucket \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

---

### 4️⃣ Backend Configuration for Terraform State

Create or update the `backend.hcl` file with your Terraform backend configuration:

```hcl
bucket = "your-bucket"
```

---

### 5️⃣ Terraform Deployment

#### Manual Deployment

If deploying manually from your local machine, execute Terraform in the following order:

```bash
# Initialize Terraform with remote backend
terraform init -backend-config=backend.hcl --reconfigure

# Plan infrastructure changes
terraform plan -out=tfplan

# Apply with Lake Formation admin permissions first
terraform apply -target=module.glue_catalog_utils.aws_lakeformation_data_lake_settings.admins -auto-approve tfplan

# Apply remaining infrastructure
terraform apply -auto-approve tfplan
```

> **Note:** The targeted apply for Lake Formation admins is critical to establish proper permissions before creating other resources.

#### Automated Deployment (GitHub Actions)

The project includes two GitHub Actions workflows for automated infrastructure management:

**📄 `.github/workflows/AWS_CREATION_PIPELINE.yml`**
- **Trigger:** Automatically runs on push to `main` branch
- **Purpose:** Deploys all AWS infrastructure with proper Lake Formation permissions
- **Key Steps:**
  1. Checks out repository code
  2. Sets up Terraform 1.9.8
  3. Configures AWS credentials from GitHub secrets
  4. Initializes Terraform with remote backend (`backend.hcl`)
  5. Generates execution plan with environment variables (`TF_VAR_api_key`, `TF_VAR_secret_key`)
  6. Applies infrastructure with targeted Lake Formation admin setup:
     ```bash
     terraform apply -target=module.glue_catalog_utils.aws_lakeformation_data_lake_settings.admins -auto-approve tfplan
     ```
- **Required Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `API_KEY`, `API_SECRET`

**📄 `.github/workflows/AWS_DESTROY_RESOURCES_AWS.yml`**
- **Trigger:** Manual execution via `workflow_dispatch` (GitHub UI)
- **Purpose:** Complete teardown of all AWS resources for cost management and cleanup
- **Key Steps:**
  1. Checks out repository code
  2. Sets up Terraform 1.9.8
  3. Configures AWS credentials from GitHub secrets
  4. Initializes Terraform with remote backend
  5. Generates destruction plan
  6. Executes `terraform destroy -auto-approve` to remove all infrastructure
- **Required Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `API_KEY`, `SECRET_KEY`
- **Use Case:** Run this workflow when you want to delete all resources to avoid AWS charges

> **⚠️ Important:** Both workflows reference environment variables as `TF_VAR_*` to pass secrets securely to Terraform. Ensure all required secrets are configured in your GitHub repository settings before running the pipelines.

---

## ⚙️ Required Environment Variables

Before running Terraform or executing GitHub Actions pipelines, configure the following **environment variables**.  
If they are missing, the **pipeline will fail** during deployment.

| Variable | Description |
|----------|-------------|
| `API_KEY` | Coinbase API key for cryptocurrency price data access |
| `API_SECRET` | Coinbase API secret key for authentication |
| `AWS_ACCESS_KEY_ID` | AWS access key ID for authentication |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key associated with the account |
| `AWS_ROOT_ROLE` | role to execute the entire workflow |

**These variables must be configured under:**  
👉 `Settings → Secrets and variables → Actions → Repository secrets`  

The GitHub Actions workflow automatically loads these variables at runtime to authenticate and provision AWS resources.

---

## ⚙️ Architecture

### 📊 Data Flow

```
Coinbase API → Lambda (EventBridge Trigger) 
       ↓
   Kinesis Data Stream
       ↓
   Kinesis Firehose
       ↓
   S3 Bucket (JSON partitioned by date)
       ↓
   Glue Crawler (automated schema detection)
       ↓
   Glue Data Catalog + Lake Formation
       ↓
   Athena (SQL queries) + DataZone (data governance)
```

### 🔹 Key Components

- **Coinbase API**  
  Real-time cryptocurrency price data source (BTC-USD, ETH-USD, ADA-USD).

- **AWS Lambda**  
  Scheduled by EventBridge (every 5 minutes) to:
  - Fetch live crypto prices from Coinbase API
  - Send records to Kinesis Data Stream
  - Validate Glue table existence post-ingestion

- **Amazon Kinesis**  
  - **Data Stream**: Real-time ingestion buffer
  - **Firehose**: Automatic delivery to S3 with partitioning by date

- **Amazon S3**  
  Centralized data lake with:
  - KMS encryption at rest
  - Prefix-based partitioning: `coinbase/coinbase_currency_prices/partition_date=YYYY-MM-DD/`

- **AWS Glue**  
  - **Crawler**: Runs every 10 minutes to discover new data and update schema
  - **Data Catalog**: Centralized metadata repository
  - **Lake Formation**: Fine-grained access control and data governance

- **Amazon Athena**  
  Serverless SQL engine for querying the data lake with support for:
  - Partitioned queries
  - KMS-encrypted result storage

- **AWS DataZone**  
  Data governance layer providing:
  - Data cataloging and discovery
  - Access management for analytics teams
  - Integration with Glue Catalog

- **Amazon EventBridge**  
  Triggers Lambda function every 5 minutes for continuous data ingestion.

- **CloudWatch & SNS**  
  Logs all Lambda executions and sends alerts on failures.

---

## 🧱 Repository Structure

```
aws_resources/
├── bucket_module/               # S3 bucket + KMS encryption + Athena workgroup
├── kinesis_module/              # Kinesis Data Stream + Firehose delivery
├── lambda_module/               # Lambda function, IAM, Docker build, alerts
│   ├── iam.tf
│   ├── lambda.tf
│   └── resources/
│       ├── DockerFile           # Lambda container definition
│       ├── requirements.txt     # Python dependencies
│       └── python/aws_lambda/
│           ├── lambda_function.py      # Lambda handler entry point
│           ├── coinbase_data.py        # Coinbase API client with retry logic
│           ├── coinbase_stream.py      # Kinesis producer
│           └── utils.py                # Glue table verification utilities
├── eventbridge_module/          # EventBridge scheduler for Lambda invocation
├── glue_catalog_module/         # Glue Crawler, Catalog, Lake Formation
├── datazone_module/             # DataZone domain and project configuration
├── main.tf                      # Root module orchestration
├── providers.tf                 # AWS provider and backend configuration
├── variables.tf                 # Root-level variables
└── backend.hcl                  # Remote backend configuration (S3 + DynamoDB)

.github/workflows/
├── AWS_CREATION_PIPELINE.yml    # CI/CD for infrastructure deployment
└── AWS_DESTROY_PIPELINES.yml    # Infrastructure teardown workflow
```

---

## 🔄 Data Flow Details

### 1️⃣ Ingestion (Lambda → Kinesis)

Every 5 minutes, EventBridge triggers the Lambda function:
- Lambda calls Coinbase API for BTC, ETH, and ADA prices (50 API calls total)
- Each price record is enriched with:
  - `currency_id`: UUID for tracking
  - `timestamp`: Unix timestamp
  - `date`: ISO formatted datetime
- Records are sent to Kinesis Data Stream

### 2️⃣ Delivery (Kinesis → S3)

Kinesis Firehose:
- Buffers records (60 seconds or 5 MB)
- Writes JSON files to S3 with date-based partitioning
- Compresses data (optional)
- Encrypts with KMS

### 3️⃣ Cataloging (Glue Crawler → Catalog)

Glue Crawler runs every 10 minutes:
- Discovers new files in S3
- Infers schema from JSON structure
- Updates Glue Data Catalog
- Registers partitions automatically

### 4️⃣ Governance (Lake Formation)

Lake Formation provides:
- Data location registration
- Role-based access control
- Integration with Glue Catalog
- Audit trail for data access

### 5️⃣ Analytics (Athena + DataZone)

- **Athena**: SQL queries against partitioned data
- **DataZone**: Data discovery portal for analytics teams

---

## 🚀 Deployment & Automation

### 🤖 GitHub Actions CI/CD

Located in `.github/workflows/`:

#### `AWS_CREATION_PIPELINE.yml`
Automated deployment pipeline that:
- Runs on push to `main` branch
- Executes Terraform validation
- Deploys infrastructure with proper Lake Formation permissions:
  ```bash
  terraform apply -target=module.glue_catalog_utils.aws_lakeformation_data_lake_settings.admins -auto-approve tfplan
  ```
- Requires `API_KEY`, `API_SECRET`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` secrets

#### `AWS_DESTROY_PIPELINES.yml`
Manual cleanup workflow for complete teardown:
- Triggered via `workflow_dispatch` (manual execution)
- Destroys all AWS resources
- Useful for cost management and environment cleanup

---

## 🔒 Security & Monitoring

| Component | Description |
|-----------|-------------|
| **KMS Encryption** | All S3 objects and Kinesis streams encrypted at rest with customer-managed keys |
| **IAM Roles** | Least-privilege access policies for Lambda, Glue, Firehose, and EventBridge |
| **Lake Formation** | Fine-grained table and column-level access control |
| **CloudWatch Logs** | Tracks Lambda execution logs and Glue crawler runs |
| **CloudWatch Alarms** | Monitors Lambda errors with threshold-based alerting |
| **SNS Notifications** | Sends email/SMS alerts for pipeline failures |
| **S3 Bucket Policies** | Blocks all public access with explicit deny rules |
| **VPC Integration** | (Optional) Lambda and Glue can run in private subnets |

---

## 🧠 Best Practices Implemented

- ✅ **Infrastructure as Code**: Full Terraform automation
- ✅ **Modular Architecture**: Reusable modules for each AWS service
- ✅ **Exponential Backoff**: API retry logic with exponential delay
- ✅ **Automated Schema Evolution**: Glue Crawler handles schema changes
- ✅ **Partitioned Storage**: Date-based S3 prefixes for query optimization
- ✅ **CI/CD Enforcement**: GitHub Actions for consistent deployments
- ✅ **Observability**: CloudWatch logging and SNS alerting
- ✅ **Security First**: KMS encryption, IAM policies, Lake Formation ACLs
- ✅ **Cost Optimization**: S3 lifecycle policies, Kinesis provisioned throughput
- ✅ **Data Governance**: DataZone integration for enterprise compliance

---

## 🛠️ Troubleshooting

| Issue | Possible Cause | Fix |
|-------|----------------|-----|
| Lambda not triggered | EventBridge schedule inactive | Check `aws_scheduler_schedule` resource state |
| Kinesis write errors | Invalid stream name or IAM permissions | Verify `stream_name` environment variable and Lambda role |
| Glue table not created | Crawler hasn't run yet or S3 path incorrect | Wait 10 minutes or manually trigger crawler |
| Lake Formation access denied | Admin permissions not set | Run targeted Terraform apply for `aws_lakeformation_data_lake_settings.admins` |
| Athena query fails | Table not registered or wrong partition format | Check Glue Catalog and S3 prefix structure |
| Docker build fails | ECR authentication expired | Re-run `aws ecr get-login-password` and retry |

---

## 📊 Current Status

| Module | Status | Description |
|--------|--------|-------------|
| **S3 + KMS** | ✅ | Data lake with encryption operational |
| **Lambda** | ✅ | Scheduled ingestion with retry logic |
| **Kinesis** | ✅ | Real-time streaming pipeline |
| **Glue** | ✅ | Automated cataloging every 10 minutes |
| **Lake Formation** | ✅ | Data governance active |
| **Athena** | ✅ | SQL query interface ready |
| **DataZone** | ✅ | Data discovery portal live |
| **CI/CD** | ✅ | GitHub Actions automated workflows |
| **Monitoring** | ✅ | CloudWatch + SNS alerts configured |

---

## 📖 Additional Resources

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lake Formation Permissions Model](https://docs.aws.amazon.com/lake-formation/latest/dg/how-it-works.html)
- [Glue Crawler Configuration](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## 👥 Contributors

**Project Owner:** Ricardo Roa  
**Purpose:** AWS Data Lake Formation & Real-Time Analytics Pipeline

---

## 📝 License

This project is part of a technical challenge and is intended for educational and demonstration purposes.