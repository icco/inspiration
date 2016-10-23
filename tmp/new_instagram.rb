require "openssl"
require "base64"
require "json"
require "httpclient"

http = HTTPClient.new(agent_name: useragent)
key = "" # The Private key
login_info = { guid: "00000000-0000-0000-0000-000000000000",
               password: "PASSWORD",
               username: "USERNAME",
               device_id: "android-0000000000000000",
               _csrftoken: "missing" }.to_json
signed_body = "#{Digest::HMAC.hexdigest(login_info, key, Digest::SHA256)}.#{login_info}"
post_data = { signed_body: signed_body, ig_sig_key_version: 4 }
result = http.post("https://instagram.com/api/v1/accounts/login/", post_data, "Content-Type" => "application/json")
p result.body
