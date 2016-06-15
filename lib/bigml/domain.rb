module BigML
  class Domain

     # Default domain and protocol
     DEFAULT_DOMAIN = 'bigml.io'
     DEFAULT_PROTOCOL = 'https'

     # Base Domain
     BIGML_DOMAIN = ENV['BIGML_DOMAIN'] ? ENV['BIGML_DOMAIN'] : DEFAULT_DOMAIN

     # Protocol for main server
     BIGML_PROTOCOL = ENV['BIGML_PROTOCOL'] ? ENV['BIGML_PROTOCOL'] :  DEFAULT_PROTOCOL

     # SSL Verification
     BIGML_SSL_VERIFY = ENV['BIGML_SSL_VERIFY']

     # Domain for prediction server
     BIGML_PREDICTION_DOMAIN = ENV['BIGML_PREDICTION_DOMAIN'] ? ENV['BIGML_PREDICTION_DOMAIN'] : BIGML_DOMAIN

     # Protocol for prediction server
     BIGML_PREDICTION_PROTOCOL = ENV['BIGML_PREDICTION_PROTOCOL'] ? ENV['BIGML_PREDICTION_PROTOCOL'] : DEFAULT_PROTOCOL

     # SSL Verification for prediction server
     BIGML_PREDICTION_SSL_VERIFY = ENV['BIGML_PREDICTION_SSL_VERIFY']

     attr_accessor :general_domain, :general_protocol, :prediction_domain, 
                   :prediction_protocol, :verify, :verify_prediction


     def initialize(domain: nil, prediction_domain: nil, prediction_protocol: nil, 
                    protocol: nil, verify: nil, prediction_verify: nil)

       # Base domain for remote resources
       @general_domain = domain.nil? ? BIGML_DOMAIN : domain
       @general_protocol= protocol.nil? ? BIGML_PROTOCOL : protocol
 
       # Usually, predictions are served from the same domain
       if prediction_domain.nil?
          unless domain.nil?
            @prediction_domain = domain
            @prediction_protocol = protocol
          else
            @prediction_domain = BIGML_PREDICTION_DOMAIN
            @prediction_protocol = BIGML_PREDICTION_PROTOCOL 
          end
       # If the domain for predictions is different from the general domain,
       # for instance in high-availability prediction servers
       else
          @prediction_domain = prediction_domain
          @prediction_protocol = prediction_protocol ? prediction_protocol : BIGML_PREDICTION_PROTOCOL 
       end 

       # Check SSL when comming from `bigml.io` subdomains or when forced
       # by the external BIGML_SSL_VERIFY environment variable or verify
       # arguments

       @verify = nil 
       @verify_prediction = nil
 
       if (@general_protocol == BIGML_PROTOCOL) and (!verify.nil? or !BIGML_SSL_VERIFY.nil?)
         @verify = !verify.nil? ? verify : BIGML_SSL_VERIFY.to_i == 1
       end
        
       if @verify.nil?
         @verify = @general_domain.downcase.end_with? DEFAULT_DOMAIN 
       end
  
       if (@prediction_protocol == BIGML_PROTOCOL) and (!prediction_verify.nil? or !BIGML_PREDICTION_SSL_VERIFY.nil?)
         @verify_prediction = !prediction_verify.nil? ? prediction_verify : BIGML_PREDICTION_SSL_VERIFY.to_i == 1
       end

       if @verify_prediction.nil?
         @verify_prediction = (@prediction_domain.downcase.end_with? DEFAULT_DOMAIN) and (@prediction_protocol == DEFAULT_PROTOCOL)
       end 

     end
  end
end  
