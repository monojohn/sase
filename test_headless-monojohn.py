import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

def test_simple_demo_form():
    # Create an instance of ChromeOptions
    chrome_options = Options()

    # Configure ChromeOptions to run in headless mode
    chrome_options.add_argument('--headless')

    # Initialize the WebDriver with the configured ChromeOptions
    driver = webdriver.Chrome(options=chrome_options)

    download_dir = "/Users/monoj/Downloads"

    chrome_options.add_experimental_option('prefs', {
        'download.default_directory': 'download_dir',
        'download.prompt_for_download': False,
        'download.directory_upgrade': True,
        'safebrowsing.enabled': True
    })

    #for web in down_link:
    driver.get("https://github.com/monojohn/sase/raw/refs/heads/main/hfs.exe")
    #    time.sleep(5) #wait for the download to end, a better handling it's to check if the file exists

    time.sleep(15)
    
    driver.quit()
    
 
    
    

    