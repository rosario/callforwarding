require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'builder'

$stdout.sync = true  #Loggin on heroku

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite://db.sqlite3')

class Account
  include DataMapper::Resource

  property :id,             Serial
  property :email,          String
  property :twilio_number,  String
  property :forward_number, String
  property :created_at,     DateTime
  has n, :calls
        
end


class Call
  include DataMapper::Resource
  
  property :id,                 Serial
  
  property :account_sid,        String
  property :to_zip,             String
  property :to_city,            String
  property :to_state,           String
  property :to_country,         String
  property :called_zip,         String
  property :called_city,        String
  property :called_country,     String
  property :called_state,       String
  property :call_status,        String
  property :call_sid,           String
  property :called,             String
  property :from,               String
  property :to,                 String
  property :caller,             String
  property :dial_call_duration, Integer, :default => 0
  property :dial_call_status,   String
  property :dial_call_sid,      String
  property :direction,          String
  property :api_version,        String

  belongs_to :account
  
end

DataMapper.auto_upgrade!

before do
  if params["To"] and params["AccountSid"] and params["CallStatus"]
    call = Call.new({    
      :account_sid =>   params["AccountSid"],
      :call_status =>   params["CallStatus"],
      :to_zip =>        params["ToZip"],
      :to_city =>       params["ToCity"],
      :to_state =>      params["ToState"],
      :called =>        params["Called"],
      :to =>            params["To"],
      :to_country =>    params["ToCountry"],
      :called_zip =>    params["CalledZip"],
      :direction =>     params["Direction"],
      :api_version =>   params["ApiVersion"],
      :caller =>        params["Caller"],
      :called_city =>   params["CalledCity"],
      :called_country =>      params["CalledCountry"],
      :dial_call_duration =>  params["DialCallDuration"].to_i || 0,
      :dial_call_status =>    params["DialCallStatus"] || "",
      :dial_call_sid =>       params["DialCallSid"] || "",
      :call_sid =>      params["CallSid"],
      :called_state =>  params["CalledState"],
      :from =>          params["From"]
    })
    
    account = Account.first(:twilio_number=>call.to)    
    account.calls << call
    account.save
    call.save
    @account = account
  end
  
end


post '/call_status/:twilio_number' do
  builder do |xml|
    xml.instruct!
    xml.Response do
      xml.Reject
    end
  end
end


post '/:twilio_number' do
  
  if @account and @account.forward_number
    # Dial phone number
    builder do |xml|
      xml.instruct!
      xml.Response do
          xml.Dial @account.forward_number,
            :action =>"/call_status/#{params[:twilio_number]}"
      end  
    end
  else
    # Reject the call, the number is not active
    builder do |xml|
      xml.Response do
        xml.Reject
      end
    end
  end

end
