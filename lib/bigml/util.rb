require 'json'
 
module BigML
  class Util 
   class << self

     def is_url(urlString)
        if urlString =~ URI::regexp
           return true
	else
	   return false
	end
     end

     def resource_structure(code, resource_id, location, resource, error)
       #
       #Returns the corresponding JSON structure for a resource
       #
       return {'code' => code, 'resource' => resource_id, 'location' => location,
               'object' => resource, 'error' => error}

     end

     def maybe_save(resource_id, path, code=nil, location=nil, resource=nil, error=nil)
       # Builds the resource dict response and saves it if a path is provided.
       # The resource is saved in a local repo json file in the given path.
       #
       resource = resource_structure(code, resource_id, location, resource, error)

       if (!path.nil? and !resource_id.nil?)
          begin
            resource_json=JSON.parse(resource)
          rescue
             puts "The resource has an invalid JSON format"
          end

          begin
            resource_file_name = File.join(path, resource_id.gsub('/','_'))
            File.open(resource_file_name, "w:UTF-8") do |f|
               f.write resource_json
            end
          rescue IOError
             puts "Failed writing resource to " + resource_file_name
          end          
       end

       return resource

     end

     def get_exponential_wait(wait_time, retry_count)
       # Computes the exponential wait time used in next request using the
       # base values provided by the user:
       # wait_time: starting wait time
       # retries: total number of retries
       # retries_left: retries left

       delta = (retry_count ** 2) * wait_time / 2
       exp_factor = retry_count > 1 ? delta : 0
       return wait_time + ( Random.rand()*exp_factor).floor
     end

     def check_dir(path)
       #Creates a directory if it doesn't exist
       if File.exist?(path)
          if !File.directory?(path)
            raise ArgumentError, 'The given path is not a directory'
          end 
       elsif path.size > 0
          Dir.mkdir path
       end

       return path
     end
   end
  end
end  
