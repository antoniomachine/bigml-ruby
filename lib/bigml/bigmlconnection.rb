# encoding: utf-8
#
# Copyright 2014-2016 BigML
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
require 'fileutils'
require 'net/http'
require 'json'
require 'rest-client'
require 'open-uri'

require_relative 'domain'
require_relative 'util'

# TODO logger

module BigML
  # Base URL
  BIGML_URL = 'PROTOCOL://DOMAIN/andromeda/'
  # Development Mode URL
  BIGML_DEV_URL = 'PROTOCOL://DOMAIN/dev/andromeda/'

  # HTTP Status Codes from https://bigml.com/developers/status_codes
  HTTP_OK = 200
  HTTP_CREATED = 201
  HTTP_ACCEPTED = 202
  HTTP_NO_CONTENT = 204
  HTTP_BAD_REQUEST = 400
  HTTP_UNAUTHORIZED = 401
  HTTP_PAYMENT_REQUIRED = 402
  HTTP_FORBIDDEN = 403
  HTTP_NOT_FOUND = 404
  HTTP_METHOD_NOT_ALLOWED = 405
  HTTP_TOO_MANY_REQUESTS = 429
  HTTP_LENGTH_REQUIRED = 411
  HTTP_INTERNAL_SERVER_ERROR = 500

  # Headers
  CONTENT_TYPE = 'application/json'
  CHARSET ='utf-8'
  DOWNLOAD_DIR = '/download'

  class BigMLConnection

     def initialize(username = nil, api_key = nil, dev_mode = false, 
                    debug = false, set_locale = false, storage = nil, domain = nil)

       username = username.nil? ? ENV['BIGML_USERNAME'] : username
       api_key = api_key.nil? ? ENV['BIGML_API_KEY'] : api_key

       if username.nil?
         raise ArgumentError, 'Cannot find BIGML_USERNAME in your environment'
       end

       if api_key.nil?
         raise ArgumentError, 'Cannot find BIGML_API_KEY in your environment' 
       end 

       @auth = "?username=#{username};api_key=#{api_key};"
       @dev_mode = dev_mode
       @general_domain = nil
       @general_protocol = nil
       @prediction_domain = nil
       @prediction_protocol = nil
       @verify = nil
       @verify_prediction = nil
       @url = nil
       @prediction_url = nil
       @storage=nil

       self._set_api_urls(dev_mode, domain)
    
       unless storage.nil?
          if Dir.exists?(storage)
             unless File.directory(storage)
                raise ArgumentError, 'The given path is not a directory'
             end
          else
             FileUtils.mkdir_p(storage) 
          end
          @storage=storage
       end

     end

     def _set_api_urls(dev_mode=false, domain=nil)
       # 
       # Sets the urls that point to the REST api methods for each resource
       #
       if domain.nil?
          domain = BigML::Domain.new
       elsif domain.is_a? String 
          domain = BigML::Domain.new(domain)
       elsif !domain.is_a? BigML::Domain 
          raise ArgumentError, 'The domain must be set using a Domain object'
       end
       # Setting the general and prediction domain options
       @general_domain = domain.general_domain
       @general_protocol = domain.general_protocol
       @prediction_domain = domain.prediction_domain
       @prediction_protocol = domain.prediction_protocol
       @verify = domain.verify
       @verify_prediction = domain.verify_prediction
      
       if dev_mode
         @url = BIGML_DEV_URL.gsub("PROTOCOL", @general_protocol).gsub("DOMAIN", @general_domain)
         @prediction_url = BIGML_DEV_URL.gsub("PROTOCOL", @general_protocol).gsub("DOMAIN", @general_domain)
       else
         # Using a different prediction domain and protocol only in 
         #  production mode. Dev-mode uses the general values.
          @url = BIGML_URL.gsub("PROTOCOL", BigML::Domain::BIGML_PROTOCOL).gsub("DOMAIN", @general_domain)
          @prediction_url = BIGML_URL.gsub("PROTOCOL", @prediction_protocol).gsub("DOMAIN", @prediction_domain)
       end
 
     end

     def _create(url, body)
       #Creates a new remote resource.

       #Posts `body` in JSON to `url` to create a new remote resource.

       #Returns a BigML resource wrapped in a dictionary that includes:
       #     code: HTTP status code
       #     resource: The resource/id
       #     location: Remote location of the resource
       #     object: The resource itself
       #     error: An error code and message

       code = HTTP_INTERNAL_SERVER_ERROR
       resource_id = nil 
       location = nil
       resource = nil 
       error = {"status" => {"code" => code, "message" => "The resource couldn't be created"}}

       # If a prediction server is in use, the first prediction request might
       # return a HTTP_ACCEPTED (202) while the model or ensemble is being
       # downloaded.
       code = HTTP_ACCEPTED
       while (code == HTTP_ACCEPTED) do
          begin
            response = RestClient.post url+@auth, body, {:content_type => :json, :accept => :json, :charset => "utf-8"}
          rescue RestClient::RequestTimeout
             raise 'Request Timeout'
          rescue RestClient::Exception => response
             code = response.http_code
             if [HTTP_BAD_REQUEST, HTTP_UNAUTHORIZED, HTTP_PAYMENT_REQUIRED, HTTP_FORBIDDEN, HTTP_NOT_FOUND, HTTP_TOO_MANY_REQUESTS].include?(code)
               error = JSON.parse(response.http_body)
             else
               code = HTTP_INTERNAL_SERVER_ERROR
             end
 
             return BigML::Util::maybe_save(resource_id, @storage, code,
                                            location, resource, error)
          end

          begin
            code = response.code
            if [HTTP_CREATED, HTTP_OK].include?(code)
               location = response.headers.fetch('location', "")
               resource = JSON.parse(response.to_str)
               resource_id = resource["resource"]
               error = nil
            elsif [HTTP_BAD_REQUEST, HTTP_UNAUTHORIZED, HTTP_PAYMENT_REQUIRED, HTTP_FORBIDDEN, HTTP_NOT_FOUND, HTTP_TOO_MANY_REQUESTS].include?(code)
               error = JSON.parse(response.to_str)
            else
               code = HTTP_INTERNAL_SERVER_ERROR
            end

          rescue StandardError => e
             code=HTTP_INTERNAL_SERVER_ERROR
          end

          return BigML::Util::maybe_save(resource_id, @storage, code, location, resource, error)
 
       end
     end

     def _get(url, query_string='', shared_username=nil, shared_api_key=nil)
        # Retrieves a remote resource.
        # Uses HTTP GET to retrieve a BigML `url`.

        # Returns a BigML resource wrapped in a dictionary that includes:
        #    code: HTTP status code
        #    resource: The resource/id
        #    location: Remote location of the resource
        #    object: The resource itself
        #    error: An error code and message

        code = HTTP_INTERNAL_SERVER_ERROR
        resource_id = nil 
        location = url
        resource = nil 
        error = {"status" => {"code" => HTTP_INTERNAL_SERVER_ERROR,
                "message" => "The resource couldn't be retrieved"}}
        auth = shared_username.nil? ? @auth : "?username=#{@shared_username};api_key=#{@shared_api_key}"

        query_string = query_string.nil? ? '' : query_string
        begin
           response = RestClient.get url+auth+query_string, :accept => "application/json;charset=utf-8"
        rescue RestClient::RequestTimeout
           raise 'Request Timeout'
        rescue RestClient::Exception => e
           code = HTTP_INTERNAL_SERVER_ERROR
           return BigML::Util::maybe_save(resource_id, @storage, code,
                                          location, resource, error)
        end

        begin
           code = response.code
           if code == HTTP_OK
             resource = JSON.parse(response.to_str)
             resource_id = resource['resource']
             error = nil
           elsif [HTTP_BAD_REQUEST, HTTP_UNAUTHORIZED, HTTP_NOT_FOUND, HTTP_TOO_MANY_REQUESTS].include?(code)
              error = JSON.parse(response.to_str)
           else
              code=HTTP_INTERNAL_SERVER_ERROR
           end
        rescue StandardError => e
          code=HTTP_INTERNAL_SERVER_ERROR
        end
     
        return BigML::Util::maybe_save(resource_id, @storage, code, location, resource, error)
     end

     def _list(url, query_string='')
       #Lists all existing remote resources.

       # Resources in listings can be filterd using `query_string` formatted
       # according to the syntax and fields labeled as filterable in the BigML
       # documentation for each resource.

       # Sufixes:
       #     __lt: less than
       #     __lte: less than or equal to
       #     __gt: greater than
       #     __gte: greater than or equal to

       # For example:

       #     'size__gt=1024'

       # Resources can also be sortened including a sort_by statement within
       # the `query_sting`. For example:

       #     'order_by=size'

       code = HTTP_INTERNAL_SERVER_ERROR
       meta = nil 
       resources = nil 
       error = {"status" => {"code" => code, "message" => "The resource couldn't be listed"}}

       begin
         response = RestClient.get url+@auth+query_string, :accept => "application/json;charset=utf-8"
       rescue RestClient::RequestTimeout
         raise 'Request Timeout'
       rescue RestClient::Exception => e
         code = HTTP_INTERNAL_SERVER_ERROR
         return maybe_save(resource_id, @storage, code,
                           location, resource, error)
       end
      
       begin
           code = response.code
           if code == HTTP_OK
             resource = JSON.parse(response.to_str)
             meta = resource['meta']
             resources = resource['objects']
             error = nil
           elsif [HTTP_BAD_REQUEST, HTTP_UNAUTHORIZED, HTTP_NOT_FOUND, HTTP_TOO_MANY_REQUESTS].include?(code)
              error = JSON.parse(response.to_str)
           else
              code=HTTP_INTERNAL_SERVER_ERROR
           end
       rescue StandardError => e
          code=HTTP_INTERNAL_SERVER_ERROR
       end
 
       return {'code' => code, 'meta' => meta, 'objects' => resources,'error' => error}

     end

     def _update(url, body)
       # Updates a remote resource.
       # Uses PUT to update a BigML resource. Only the new fields that
       #  are going to be updated need to be included in the `body`.

       #  Returns a resource wrapped in a dictionary:
       #     code: HTTP_ACCEPTED if the update has been OK or an error
       #           code otherwise.
       #     resource: Resource/id
       #     location: Remote location of the resource.
       #     object: The new updated resource
       #     error: Error code if any. None otherwise
   
       code = HTTP_INTERNAL_SERVER_ERROR
       resource_id = nil
       location=url
       resource=nil
       error = {"status" => {"code" => code, "message" => "The resource couldn't be updated"}}

       begin
         response = RestClient.put url+@auth, body, :content_type => "application/json;charset=utf-8"
       rescue RestClient::RequestTimeout
         raise 'Request Timeout'
       rescue RestClient::Exception => e
         code = HTTP_INTERNAL_SERVER_ERROR
         return maybe_save(resource_id, @storage, code,
                           location, resource, error)
       end

       begin
           code = response.code
           if code == HTTP_ACCEPTED
             resource = JSON.parse(response.to_str)
             resource_id = resource['resource']
             error = nil
           elsif [HTTP_UNAUTHORIZED, HTTP_PAYMENT_REQUIRED, HTTP_METHOD_NOT_ALLOWED, HTTP_TOO_MANY_REQUESTS].include?(code)
             error = JSON.parse(response.to_str)
           else
             code=HTTP_INTERNAL_SERVER_ERROR 
           end
       rescue StandardError => e
          code=HTTP_INTERNAL_SERVER_ERROR
       end

       return BigML::Util::maybe_save(resource_id, @storage, code, location, resource, error)

     end

     def _delete(url)
       #Permanently deletes a remote resource.

       # If the request is successful the status `code` will be HTTP_NO_CONTENT
       # and `error` will be None. Otherwise, the `code` will be an error code
       # and `error` will be provide a specific code and explanation.
  
       code = HTTP_INTERNAL_SERVER_ERROR
       error = {"status" => {"code" => code, "message" => "The resource couldn't be deleted"}}

       begin
         response = RestClient.delete url+@auth
       rescue RestClient::RequestTimeout
         raise 'Request Timeout'
       rescue RestClient::Exception => e
         code = HTTP_INTERNAL_SERVER_ERROR
         return maybe_save(resource_id, @storage, code,
                           location, resource, error)
       end

       begin
           code = response.code
           if code == HTTP_NO_CONTENT
             error = nil
           elsif [HTTP_BAD_REQUEST, HTTP_UNAUTHORIZED, HTTP_NOT_FOUND, HTTP_TOO_MANY_REQUESTS].include?(code)
              error = JSON.parse(response.to_str)
           else
              code=HTTP_INTERNAL_SERVER_ERROR
           end
       rescue StandardError => e
          code=HTTP_INTERNAL_SERVER_ERROR
       end

       return {'code' => code, 'error' => error}
 
     end
  
     def _download(url, filename=nil, wait_time=10, retries=10, counter=0)
       #Retrieves a remote file.
       # Uses HTTP GET to download a file object with a BigML `url`.
       code = HTTP_INTERNAL_SERVER_ERROR
       file_object = nil

       if counter > (2 * retries)
         return file_object
       end

       response ={"content_type" => nil, "code" => nil, "content-length" => nil} 

       begin
          open(url+@auth) do |f|
             response["code"] = f.status
             response["content_type"] =  f.content_type
             response["content-length"] = f.meta["content-length"]
             file_object = f.read
          end
       rescue StandardError => e
          return file_object
       end   
       code = response["code"][0].to_i

       begin
          if code == HTTP_OK
             if response["content_type"] == CONTENT_TYPE
                begin
                   if counter < retries 
                      download_status = JSON.parse(file_object)
                      if !download_status.nil? and download_status.is_a?(Hash)
                         if download_status['status']['code'] != 5
                            sleep(BigML::Util::get_exponential_wait(wait_time, counter))
                            counter += 1
                            return _download(url, filename, wait_time, retries, counter)
                         else
                            return _download(url, filename, wait_time, retries, retries+1)
                         end                          
                      end

                   elsif counter == retries
                      puts "The maximum number of retries for the download has been exceeded. You can retry your command again in a while. " 
                      return nil
                   end
                rescue StandardError => e
                   puts "Failed getting a valid JSON structure."
                end 
             else

               unless filename.nil?
	          file_size = stream_copy(file_object, filename)
                  if response["content-length"].nil? or (response["content-length"].to_i < file_object.size)
                      puts "Error downloading: total size= "+response["content-length"] + " "+ file_object.size + " downloaded" 
                      sleep(BigML::Util::get_exponential_wait(wait_time, counter))
                      return _download(url, filename, wait_time, retries, counter+1)
		  end
               end 

             end
          elsif [HTTP_BAD_REQUEST,  HTTP_UNAUTHORIZED, HTTP_NOT_FOUND,HTTP_TOO_MANY_REQUESTS].include?(code)
             error = file_object
          else
	     puts "INTERNAL PUS"
             code = HTTP_INTERNAL_SERVER_ERROR
          end

       #rescue StandardError => e
       end
 
       return file_object

     end
   
     def error_message(resource, resource_type='resource', method=nil)
       #Error message for each type of resource
       error = nil
       error_info = nil
       
       if resource.is_a?(Hash)
          
          if resource.key?('error')
             error_info = resource['error']
          elsif resource.key?('code') and resource.key?('status')
             error_info = resource
          end
       end

       if (!error_info.nil? and error_info.key?('code'))
          code = error_info['code']

          if error_info.key?('status') and error_info.key?('status')
             error = error_info['status']['message']
             extra = error_info['status'].fetch("extra", nil)
             unless extra.nil
                error=error + ": "+extra 
             end
          end 

          if code == HTTP_NOT_FOUND and method == 'get'
            alternate_message = ''
            if @general_domain != BigML::Domain::DEFAULT_DOMAIN
               alternate_message = "- The "+resource_type +" was not created in "+ @general_domain +".\n" 
            end
 
            error += "\nCouldn\'t find a "+resource_type +" matching the given"
            error += " id. The most probable causes are:\n\n"+alternate_message
            error += "- A typo in the "+resource_type+"\'s id.\n'"
            error += "- The "+resource_type+" id cannot be accessed with your credentials.\n"
            error += "- The resource was created in a mode (development or production) that is not the one set in the"
            error += " BigML connection object by the corresponding flag.\n"
            error += "\nDouble-check your "+resource_type+" and"
            error += " credentials info and retry."

            return error
          end
 
          if code == HTTP_UNAUTHORIZED
             error +='\nDouble-check your credentials, please.'
             return error   
          end
  
          if code == HTTP_BAD_REQUEST
            error += '\nDouble-check the arguments for the call, please.'
            return error
          end

          if code == HTTP_TOO_MANY_REQUESTS
             error += '\nToo many requests. Please stop equests for a while before resuming.'
             return error
          elsif code == HTTP_PAYMENT_REQUIRED
            error += '\nYou\'ll need to buy some more credits to perform the chosen action'
            return error
          end

       end

       return "Invalid " + resource_type + " structure:\n\n" + resource
 
     end

     private
 
     def stream_copy(response, filename)
       #Copies the contents of a response stream to a local file.
       file_size = 0
       path = File.dirname(filename)
       BigML::Util::check_dir(path)
       begin
         File.open(filename, "w") do |file_handle|
             file_handle.write response 
         end         
       rescue IOError
         return file_size=0
       end
    
       return file_size
     end

  end
end  
