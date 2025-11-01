import os
import boto3
import json
from coinbase_data import CoinBasePrice
from datetime import datetime
import uuid
import logging
import pandas as pd
from utils import DBUtils

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CURRENCIES = ['ETH-USD', 'BTC-USD', 'ADA-USD']
API_CALLS = 50


class CoinBaseStream:

    def __init__(self):
        """
        Initialize Kinesis client, Coinbase price handler and DBUtils helper.
        This constructor prepares all AWS service clients required for the pipeline.
        """
        self.kinesis_client = boto3.client('kinesis')
        self.coin_base_price = CoinBasePrice()
        self.utils = DBUtils()
   

    def coinbase_api_calls(self):
        """
        Generator that yields price information from Coinbase API across multiple currencies.
        Runs N API calls defined in API_CALLS constant and returns each record as a JSON dict.

        Yields:
            dict: cryptocurrency price payload returned from Coinbase API.
        """
        try:
            for call in range(API_CALLS):
                for currency in CURRENCIES:
                    prices = self.coin_base_price.get_price_base(currency)
                    yield prices
        except Exception as e:
            logger.error(f'can not implements api calls, verify if the token expired:{e}')

    def send_coinbase_prices(self):
        """
        Collects price data from API, enriches each record with metadata fields (timestamp, uuid, formatted date),
        then pushes each record into Kinesis using the configured stream.
        
        After pushing data, validates Glue table existence and Lake Formation permissions via DBUtils.
        """
        try:
            records_sent = 0
            for prices in self.coinbase_api_calls():
                prices['date'] = datetime.strftime(datetime.today(), '%Y-%m-%d %H:%M:%S')
                prices['currency_id'] = str(uuid.uuid1())
                prices['timestamp'] = int(datetime.now().timestamp())
                response = self.kinesis_client.put_record(
                    StreamName=os.getenv('stream_name'),
                    Data=json.dumps(prices) + '\n',
                    PartitionKey=prices['base']
                )
                records_sent += 1
                
                if response['ResponseMetadata']['HTTPStatusCode'] != 200:
                    logger.error(f"Failed to send record: {response}")
            
            logger.info(f"Successfully sent {records_sent} records to Kinesis")
            self.utils.verify_table_exists()
        except Exception as e:
            logger.error(f'can not generate the kinesis stream, please verify the configuration:{e}')
