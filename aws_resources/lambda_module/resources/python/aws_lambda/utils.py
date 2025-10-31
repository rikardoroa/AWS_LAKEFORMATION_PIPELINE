import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DBUtils:
    """
    Manage Lake Formation permissions for existing Glue tables.
    """

    def __init__(self):
        self.glue_client = boto3.client("glue")
        self.lf = boto3.client("lakeformation")
        self.role = os.getenv("role")
        self.table_name = os.getenv("table")
        self.database_name = os.getenv("database")
        self.bucket = os.getenv("bucket")

    import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DBUtils:
    """
    Utility class simplified - only checks if table exists.
    Lake Formation permissions are now handled entirely by Terraform.
    """

    def __init__(self):
        self.glue_client = boto3.client("glue")
        self.table_name = os.getenv("table")
        self.database_name = os.getenv("database")

    def ensure_permissions_on_existing_table(self):
        """
        Simply verify if the table exists. Permissions are handled by Terraform.
        """
        try:
            # Check if table exists
            try:
                response = self.glue_client.get_table(
                    DatabaseName=self.database_name,
                    Name=self.table_name
                )
                logger.info(f"✅ Table {self.table_name} exists in database {self.database_name}")
                logger.info(f"Table location: {response['Table']['StorageDescriptor']['Location']}")
                logger.info(f"Table has {len(response['Table']['StorageDescriptor']['Columns'])} columns")
                
                # Log partition keys if any
                if response['Table'].get('PartitionKeys'):
                    partitions = [p['Name'] for p in response['Table']['PartitionKeys']]
                    logger.info(f"Partition keys: {partitions}")
                    
            except self.glue_client.exceptions.EntityNotFoundException:
                logger.warning(f"⚠️ Table {self.table_name} not found in database {self.database_name}")
                logger.info("The Glue crawler needs to run first to create the table")
                logger.info("Data is still being sent to Kinesis/S3 successfully")
                
        except Exception as e:
            logger.error(f"Error checking table status: {str(e)}")
            # Don't fail the Lambda - data is still flowing to S3
            logger.info("Continuing execution - data pipeline is operational")
