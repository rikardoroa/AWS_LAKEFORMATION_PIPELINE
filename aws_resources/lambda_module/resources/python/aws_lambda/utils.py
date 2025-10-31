import boto3
import logging
import os


logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DBUtils:
    """
    Utility class to manage AWS Glue Catalog table creation and Lake Formation permissions.
    """

    def __init__(self):
        self.glue_client = boto3.client("glue")
        self.lf = boto3.client("lakeformation")
        self.role = os.getenv("role")
        self.table_name = os.getenv("table")
        self.database_name = os.getenv("database")
        self.bucket = os.getenv("bucket")

    def create_data_catalog_table(self, df):
        """
        Create or update a Glue Catalog table dynamically based on a Pandas DataFrame schema.
        Also ensures proper Lake Formation permissions.
        """
        try:
            data_types = {
                "float64": "double",
                "object": "string",
                "datetime64[ns]": "timestamp",
                "float32": "double",
                "datetime32[ns]": "timestamp",
            }

            # Dynamically build columns from DataFrame schema
            columns = [
                {"Name": col, "Type": data_types.get(df[col].dtype.name, "string")}
                for col in df.columns
            ]

            table_input = {
                "Name": self.table_name,
                "StorageDescriptor": {
                    "Columns": columns,
                    "Location": f"s3://{self.bucket}/coinbase/ingest/",
                    "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
                    "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
                    "SerdeInfo": {
                        "SerializationLibrary": "org.openx.data.jsonserde.JsonSerDe"
                    },
                },
                "TableType": "EXTERNAL_TABLE",
                "Parameters": {
                    "classification": "json"
                },
            }

            # Apply Lake Formation permissions
            self.create_table_permissions(columns)

            # Create or update Glue Catalog table
            self.create_or_update_table(table_input)

        except Exception as e:
            logger.error(f"Failed to create or update Glue table: {e}")

    def create_table_permissions(self, columns):
        """
        Ensure the required Lake Formation permissions exist for the table and its columns.
        """
        try:
            required_table_permissions = {"SELECT", "DESCRIBE"}
            required_column_permissions = {"SELECT"}

            existing = self.lf.list_permissions(ResourceType="TABLE")

            existing_table_permissions = set()
            existing_column_permissions = set()

            for perm in existing.get("PrincipalResourcePermissions", []):
                res = perm.get("Resource", {})

                # Table-level permissions
                if "Table" in res:
                    tbl = res["Table"]
                    if (
                        tbl.get("Name") == self.table_name
                        and tbl.get("DatabaseName") == self.database_name
                    ):
                        existing_table_permissions.update(perm.get("Permissions", []))

                # Column-level permissions
                elif "TableWithColumns" in res:
                    tbl = res["TableWithColumns"]
                    if (
                        tbl.get("Name") == self.table_name
                        and tbl.get("DatabaseName") == self.database_name
                    ):
                        existing_column_permissions.update(perm.get("Permissions", []))

            # Identify missing permissions
            missing_table_permissions = (required_table_permissions - existing_table_permissions)
            missing_column_permissions = (required_column_permissions - existing_column_permissions)

            # Apply missing table permissions
            if missing_table_permissions:
                logger.info(f"Granting missing table permissions: {missing_table_permissions}")
                self.lf.grant_permissions(
                    Principal={"DataLakePrincipalIdentifier": self.role},
                    Resource={
                        "Table": {
                            "DatabaseName": self.database_name,
                            "Name": self.table_name,
                        }
                    },
                    Permissions=list(missing_table_permissions),
                )
            else:
                logger.info(f" Table permissions already granted for {self.table_name}.")

            # Apply missing column permissions
            if missing_column_permissions:
                logger.info(f"Granting missing column permissions: {missing_column_permissions}")
                self.lf.grant_permissions(
                    Principal={"DataLakePrincipalIdentifier": self.role},
                    Resource={
                        "TableWithColumns": {
                            "DatabaseName": self.database_name,
                            "Name": self.table_name,
                            "ColumnNames": [col["Name"] for col in columns],
                        }
                    },
                    Permissions=list(missing_column_permissions),
                )
            else:
                logger.info(f"Column permissions already granted for {self.table_name}.")

        except Exception as e:
            logger.error(f"Failed to apply Lake Formation permissions: {e}")

    def create_or_update_table(self, table_input):
        """
        Create or update a Glue Catalog table safely.
        If the table exists, update it. Otherwise, create a new one.
        """
        try:
            self.glue_client.update_table(
                DatabaseName=self.database_name, TableInput=table_input
            )
            logger.info(f"Table {table_input['Name']} updated successfully.")
        except self.glue_client.exceptions.EntityNotFoundException:
            self.glue_client.create_table(
                DatabaseName=self.database_name, TableInput=table_input
            )
            logger.info(f"Table {table_input['Name']} created successfully.")
        except Exception as e:
            logger.error(f"Error in create_or_update_table: {e}")
