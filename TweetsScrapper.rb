require 'selenium-webdriver'
require 'io/console'
require 'csv'

def webdriver_instance
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--ignore-certificate-errors')
  options.add_argument('--disable-popup-blocking')
  options.add_argument('--disable-translate')
  options.add_option("detach", true)
  Selenium::WebDriver.for :chrome, options: options
end

def get_tweet_data(card)
  begin
    user = card.find_element(:xpath, './/span').text
  rescue Selenium::WebDriver::Error::NoSuchElementError
    user = ""
  end

  begin
    twitter_user = card.find_element(:xpath, './/span[contains(text(), "@")]').text
  rescue Selenium::WebDriver::Error::NoSuchElementError
    twitter_user = ""
  end

  begin
    date = card.find_element(:xpath, './/time').attribute("datetime")
  rescue Selenium::WebDriver::Error::NoSuchElementError
    date = ""
  end

  begin
  comment = card.find_element(:xpath, './/div[2]/div[2]/div[1]').text
  responding = card.find_element(:xpath, './/div[2]/div[2]/div[2]').text
  post_text = comment + responding
  rescue Selenium::WebDriver::Error::NoSuchElementError
    post_text = ""
  end

  begin
    reply_count = card.find_element(:xpath, './/div[@data-testid="reply"]').text
    if reply_count == ""
      reply_count = '0'
    end
  rescue Selenium::WebDriver::Error::NoSuchElementError
    reply_count = ""
  end

  begin
    retweet_count = card.find_element(:xpath, './/div[@data-testid="retweet"]').text
    if retweet_count == ""
      retweet_count = '0'
    end
  rescue Selenium::WebDriver::Error::NoSuchElementError
    retweet_count = ""
  end

  begin
    likes_count = card.find_element(:xpath, './/div[@data-testid="like"]').text
    if likes_count == ""
      likes_count = '0'
    end
  rescue Selenium::WebDriver::Error::NoSuchElementError
    likes_count = ""
  end
  {user: user, twitter_user: twitter_user, date: date, post_text: post_text, reply_count:reply_count, retweet_count:retweet_count, likes_count:likes_count}
end

def twitter_handling(driver, twitter_username, twitter_password, input_to_search, kind_of_search, max_tweets_to_scrap)

  driver.manage.window.maximize
  driver.get('https://twitter.com/login')
  wait = Selenium::WebDriver::Wait.new(:timeout => 10)

  wait.until {driver.find_element(:xpath, '//input[@name="session[username_or_email]"]')}
  username = driver.find_element(:xpath, '//input[@name="session[username_or_email]"]')
  username.send_keys(twitter_username)

  wait.until {driver.find_element(:xpath, '//input[@name="session[password]"]')}
  password = driver.find_element(:xpath, '//input[@name="session[password]"]')
  password.send_keys(twitter_password, :return)

  wait.until {driver.find_element(:xpath, '//input[@data-testid="SearchBox_Search_Input"]')}
  search_input = driver.find_element(:xpath, '//input[@data-testid="SearchBox_Search_Input"]')
  search_input.send_keys(input_to_search, :return)

  wait.until {driver.find_element(:link_text, kind_of_search)}
  latest = driver.find_element(:link_text, kind_of_search)
  latest.click

  data = []
  last_position = driver.execute_script("return window.pageYOffset;")
  page_scrolling_available = true
  sleep 2

  while page_scrolling_available
    scrolling_limit = 15
    cards = driver.find_elements(:xpath, '//div[@data-testid="tweet"]')

    if cards.length <= scrolling_limit
      cards
    else
      cards.last(scrolling_limit)
    end

    begin
      cards.each do |card|
        if max_tweets_to_scrap == 'all'
        elsif data.size >= max_tweets_to_scrap.to_i
          return data.uniq
        end
        data.append(get_tweet_data(card))
        # puts data.size
      end
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      next
    end

    scroll_attempt = 0
    while true
      driver.execute_script('window.scrollTo(0, document.body.scrollHeight);')
      sleep 1
      current_position = driver.execute_script("return window.pageYOffset;")
      if last_position == current_position
        scroll_attempt += 1
        if scroll_attempt >= 3
          page_scrolling_available = false
          break
        end
      else
        last_position = current_position
        break
      end
    end
  end
  data.uniq
end

def write_to_csv(final_arr)
  headers = ['Username', 'Twitter Username', 'Date', 'Tweet text', 'Reply count', 'Retweet count', 'Likes count']
  puts "Loop is done, saving data to tweets.csv"
  CSV.open('tweets.csv', 'w') do |csv|
    csv << headers
    final_arr.each { |tweet|
      csv << tweet.values
    }
  end
end

def main
  puts "Enter your twitter name (not e-mail, you'll be warned after few attempts of scrapping to give your nickname): "
  twitter_username = gets.chomp

  puts "Enter Password:"
  twitter_password = twitter_password = IO::console.getpass

  puts "Enter hashtag you'd like to search: "
  input_to_search = gets.chomp

  puts "Enter a type of tweets; Top - enter 0, Latest - enter 1: "
  picked_type_of_search = gets.chomp
  case picked_type_of_search
  when '0'
    kind_of_search = 'Top'
    puts "You've picked the top results"
  when '1'
    kind_of_search = 'Latest'
    puts "You've picked the latest results"
  else
    puts "You picked the wrong number"
    return
  end

  puts "Enter maximum amount of tweets to scrap, then the loop breaks, number = amount of tweets, all = scrap it all"
  max_amount_of_tweets_to_scrap = gets.chomp

  driver = webdriver_instance
  data = twitter_handling(driver, twitter_username, twitter_password, input_to_search, kind_of_search, max_amount_of_tweets_to_scrap)
  driver.quit
  write_to_csv(data)
end

main

