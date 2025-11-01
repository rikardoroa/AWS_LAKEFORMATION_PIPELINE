import json
from coinbase_stream import CoinBaseStream
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    AWS Lambda entrypoint for the Coinbase Kinesis streaming pipeline.

    This handler triggers the full ETL ingest step:
      - Fetch live crypto price data
      - Send records into Kinesis Data Stream
      - Validate downstream Glue table existence (post-crawler)

    Returns:
        dict: HTTP-style response. Includes success or failure status messages.
    """
    try:

        stream_data = CoinBaseStream()
        stream_data.send_coinbase_prices()
        
        return {
            'statusCode': 200,
            'body': json.dumps('data inserted!')
        }
    
    except Exception as e:
        logger.error(f'Lambda failed during execution:{e}')
        return {
            "statusCode": 500,
            "status": "FAILED",
            "error_message": f"Pipeline execution failed: {str(e)}"
        }
        
   