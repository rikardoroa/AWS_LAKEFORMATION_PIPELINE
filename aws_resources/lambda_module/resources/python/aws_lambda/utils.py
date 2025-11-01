import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DBUtils:
 

    def __init__(self):
        """
        Initializes Glue client and loads table + database names
        from environment variables injected by Lambda.
        """
        self.glue_client = boto3.client("glue")
        self.table_name = os.getenv("table")
        self.database_name = os.getenv("database")
    
    def verify_table_exists(self):
        """
        Verify if the target Glue table exists after the crawler execution.

        Returns:
            bool: True if the table exists in Glue Catalog,
                  False if the crawler has not created it yet or
                  an exception occurred.

        Logging side effects:
            - Logs table existence
            - Logs table location
            - Logs number of columns
            - Logs detected partition keys (if any)

        This function is usually executed after Lambda has already sent
        data to S3 + Kinesis Firehose has materialized at least one file
        inside the ingestion prefix. The Crawler is expected to run
        afterwards and generate the Glue table automatically.
        """
        try:
            response = self.glue_client.get_table(
                DatabaseName=self.database_name,
                Name=self.table_name
            )
            logger.info(f"Table {self.table_name} exists in database {self.database_name}")
            logger.info(f"Table location: {response['Table']['StorageDescriptor']['Location']}")
            logger.info(f"Table has {len(response['Table']['StorageDescriptor']['Columns'])} columns")
            
            if response['Table'].get('PartitionKeys'):
                partitions = [p['Name'] for p in response['Table']['PartitionKeys']]
                logger.info(f"Partition keys: {partitions}")
            
            return True
                
        except self.glue_client.exceptions.EntityNotFoundException:
            logger.warning(f"Table {self.table_name} not found yet - crawler needs to run")
            logger.info("Data is being sent to S3. Crawler will create table on next run.")
            return False
            
        except Exception as e:
            logger.error(f"Error checking table status: {str(e)}")
            return False