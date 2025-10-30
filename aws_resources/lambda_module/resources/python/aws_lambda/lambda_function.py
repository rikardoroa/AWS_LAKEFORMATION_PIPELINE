import json
from coinbase_stream import CoinBaseStream
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:

        stream_data = CoinBaseStream()
        stream_data.send_coinbase_prices()
        
        
        return {
            'statusCode': 200,
            'body': json.dumps('data inserted!')
        }
    
    except Exception as e:
        logger.error(f'can not execute the stream the data, please review the process:{e}')
        
   