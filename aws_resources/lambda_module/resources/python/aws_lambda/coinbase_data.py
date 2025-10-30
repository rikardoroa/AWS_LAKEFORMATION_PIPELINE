from coinbase.wallet.client import Client
import os
import logging
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)



class CoinBasePrice:

    def __init__(self):
        self.api_key = os.getenv('api_key')
        self.api_secret = os.getenv('secret_key')

    def get_price_base(self,currency):
        try:
            if not self.api_key or not self.api_secret:
                logger.error("API credentials not found in environment variables.")
            else:
                coinbase_client = Client(self.api_key, self.api_secret)
                bitcoin_currency_price = coinbase_client.get_buy_price(currency_pair=currency)
                return bitcoin_currency_price
        except Exception as e:
            logger.error(f'can not generate api call, please review the process:{e}, implementing additional calls now')
            self.get_exponential_backoff_api_calls(currency)


    
    def get_exponential_backoff_api_calls(self,currency):
        try:
            RETRY = 1
            MAX_RETRY = 5
            while RETRY <= MAX_RETRY:
                payload = self.get_price_base(currency)
                if payload:
                    return payload
                else:
                    time.sleep(2**RETRY)
                    RETRY+=1
            return f"Failed to retrieve price for {currency} after {MAX_RETRY} retries."               
        except Exception as e:
            logger.error(f'an error ocurred:{e}, please verify the process')
