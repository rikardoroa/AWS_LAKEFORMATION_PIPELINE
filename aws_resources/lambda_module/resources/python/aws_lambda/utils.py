# import boto3
# import logging
# import os


# logger = logging.getLogger()
# logger.setLevel(logging.INFO)


# class DBUtils:
#     """
#     Utility class to manage AWS Glue Catalog operations.
#     NOTE: Table creation is now handled by Glue Crawler automatically.
#     This class only ensures Lake Formation permissions are set correctly.
#     """

#     def __init__(self):
#         self.glue_client = boto3.client("glue")
#         self.lf = boto3.client("lakeformation")
#         self.role = os.getenv("role")
#         self.table_name = os.getenv("table")
#         self.database_name = os.getenv("database")
#         self.bucket = os.getenv("bucket")
    
#     def create_data_catalog_table(self):
#         """
#         Creates or updates a Glue Catalog table manually (without crawler),
#         fully compatible with Lake Formation and dynamic partitions.
#         """
#         try:
#             table_input = {
#                 "Name": self.table_name,
#                 "Description": "Automatically generated Glue table from Lambda (Coinbase Prices)",
#                 "StorageDescriptor": {
#                     "Columns": [
#                         {"Name": "amount", "Type": "string"},
#                         {"Name": "base", "Type": "string"},
#                         {"Name": "currency", "Type": "string"},
#                         {"Name": "date", "Type": "string"},
#                         {"Name": "currency_id", "Type": "string"},
#                         {"Name": "timestamp", "Type": "bigint"},
#                     ],
#                     "Location": f"s3://{self.bucket}/coinbase/ingest/",
#                     "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
#                     "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
#                     "SerdeInfo": {
#                         "SerializationLibrary": "org.openx.data.jsonserde.JsonSerDe",
#                         "Parameters": {"serialization.format": "1"},
#                     },
#                     "Compressed": True,
#                 },
#                 "PartitionKeys": [
#                     {"Name": "partition_date", "Type": "string"}
#                 ],
#                 "TableType": "EXTERNAL_TABLE",
#                 "Parameters": {"classification": "json"},
#             }

#             # Check if the table already exists
#             try:
#                 self.glue_client.create_table(DatabaseName=self.database_name, TableInput=table_input)
#                 logger.info(f"Table {self.table_name} created successfully.")
#             except self.glue_client.exceptions.AlreadyExistsException:
#                 logger.info(f"Table {self.table_name} already exists, attempting to update.")
#                 self.glue_client.update_table(DatabaseName=self.database_name, TableInput=table_input)
#                 self.ensure_permissions_on_existing_table()

#         except Exception as e:
#             logger.error(f"Failed to create Glue table: {e}")


#     def ensure_permissions_on_existing_table(self):
#         """
#         Ensures Lake Formation permissions exist for the table created by Crawler.
#         This should be called AFTER the crawler has run at least once.
#         """
#         try:
#             # Check if table exists first
#             try:
#                 self.glue_client.get_table(
#                     DatabaseName=self.database_name,
#                     Name=self.table_name
#                 )
#                 logger.info(f"Table {self.table_name} exists. Checking permissions...")
#             except self.glue_client.exceptions.EntityNotFoundException:
#                 logger.warning(f"Table {self.table_name} not found yet. Crawler may not have run.")
#                 return

#             # Get table schema to apply column permissions
#             table_response = self.glue_client.get_table(
#                 DatabaseName=self.database_name,
#                 Name=self.table_name
#             )
            
#             columns = table_response['Table']['StorageDescriptor']['Columns']
            
#             # Apply permissions
#             self.create_table_permissions(columns)
            
#             logger.info(f"Permissions verified for table {self.table_name}")

#         except Exception as e:
#             logger.error(f"Failed to ensure permissions on table: {e}")

#     def create_table_permissions(self, columns):
#         """
#         Ensure the required Lake Formation permissions exist for the table and its columns.
#         """
#         try:
#             required_table_permissions = {"SELECT", "DESCRIBE"}
#             required_column_permissions = {"SELECT"}

#             existing = self.lf.list_permissions(ResourceType="TABLE")

#             existing_table_permissions = set()
#             existing_column_permissions = set()

#             for perm in existing.get("PrincipalResourcePermissions", []):
#                 res = perm.get("Resource", {})

#                 # Table-level permissions
#                 if "Table" in res:
#                     tbl = res["Table"]
#                     if (
#                         tbl.get("Name") == self.table_name
#                         and tbl.get("DatabaseName") == self.database_name
#                     ):
#                         existing_table_permissions.update(perm.get("Permissions", []))

#                 # Column-level permissions
#                 elif "TableWithColumns" in res:
#                     tbl = res["TableWithColumns"]
#                     if (
#                         tbl.get("Name") == self.table_name
#                         and tbl.get("DatabaseName") == self.database_name
#                     ):
#                         existing_column_permissions.update(perm.get("Permissions", []))

#             # Identify missing permissions
#             missing_table_permissions = (required_table_permissions - existing_table_permissions)
#             missing_column_permissions = (required_column_permissions - existing_column_permissions)

#             # Apply missing table permissions
#             if missing_table_permissions:
#                 logger.info(f"Granting missing table permissions: {missing_table_permissions}")
#                 self.lf.grant_permissions(
#                     Principal={"DataLakePrincipalIdentifier": self.role},
#                     Resource={
#                         "Table": {
#                             "DatabaseName": self.database_name,
#                             "Name": self.table_name,
#                         }
#                     },
#                     Permissions=list(missing_table_permissions),
#                 )
#             else:
#                 logger.info(f"Table permissions already granted for {self.table_name}.")

#             # Apply missing column permissions
#             if missing_column_permissions:
#                 logger.info(f"Granting missing column permissions: {missing_column_permissions}")
#                 self.lf.grant_permissions(
#                     Principal={"DataLakePrincipalIdentifier": self.role},
#                     Resource={
#                         "TableWithColumns": {
#                             "DatabaseName": self.database_name,
#                             "Name": self.table_name,
#                             "ColumnNames": [col["Name"] for col in columns],
#                         }
#                     },
#                     Permissions=list(missing_column_permissions),
#                 )
#             else:
#                 logger.info(f"Column permissions already granted for {self.table_name}.")

#         except Exception as e:
#             logger.error(f"Failed to apply Lake Formation permissions: {e}")


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

    def ensure_permissions_on_existing_table(self):
        """
        Ensure Lake Formation permissions exist for the table already discovered by the crawler.
        """
        try:
            # Verify table exists
            try:
                self.glue_client.get_table(
                    DatabaseName=self.database_name,
                    Name=self.table_name
                )
                logger.info(f"Table {self.table_name} exists. Ensuring permissions...")
            except self.glue_client.exceptions.EntityNotFoundException:
                logger.warning(f"Table {self.table_name} not found. Run the Glue crawler first.")
                return

            # Grant DESCRIBE to database
            self.lf.grant_permissions(
                Principal={"DataLakePrincipalIdentifier": self.role},
                Resource={"Database": {"Name": self.database_name}},
                Permissions=["DESCRIBE"],
            )

            # Grant DESCRIBE + SELECT on table
            self.lf.grant_permissions(
                Principal={"DataLakePrincipalIdentifier": self.role},
                Resource={
                    "Table": {
                        "DatabaseName": self.database_name,
                        "Name": self.table_name
                    }
                },
                Permissions=["DESCRIBE", "SELECT"],
            )

            logger.info(f"Lake Formation permissions granted for table {self.table_name}")

        except Exception as e:
            logger.error(f"Failed to apply Lake Formation permissions: {e}")
