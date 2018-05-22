require 'json'
require 'active_support'
require 'parsr'
require_relative 'constants'

module BigML
  class Util 
   PREDICTIONS_FILE_SUFFIX = '_predictions.csv'
   
   PROGRESS_BAR_WIDTH = 50

   HTTP_INTERNAL_SERVER_ERROR = 500

   PRECISION = 5
   
   DFT_STORAGE = "./storage"
   
   DFT_STORAGE_FILE = File.join(DFT_STORAGE, "BigML_%s.json")
   
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
     
     def empty_resource()
       #Creates an empty resource JSON structure
       #
       return resource_structure(HTTP_INTERNAL_SERVER_ERROR, 
                                 nil, 
                                 nil, 
                                 nil,
                                 {"status": {"code": HTTP_INTERNAL_SERVER_ERROR,
                                             "message": "The resource couldn't be created"}})
     end

     def get_status(resource)
       #Extracts status info if present or sets the default if public
       if !resource.is_a?(Hash)
         raise ArgumentError, "We need a complete resource to extract its status"
       end

       if resource.key?('object')
         if resource['object'].nil?
            raise ArgumentError, "The resource has no status info %s" % resource
         end
         resource = resource["object"]
       end

       if !resource.fetch("private", true) or resource.fetch("status", nil).nil?
         status = {"code" => BigML::FINISHED}
       else
         status = resource["status"]
       end

       return status

     end

     def maybe_save(resource_id, path, code=nil, location=nil, resource=nil, error=nil)
       # Builds the resource dict response and saves it if a path is provided.
       # The resource is saved in a local repo json file in the given path.
       # Only final resources are stored. Final resources should be FINISHED or
       # FAILED
       resource = resource_structure(code, resource_id, location, resource, error)
  
       if !resource_id.nil? && !path.nil? && is_status_final(resource)
         resource_file_name = File.join(path, resource_id.gsub('/','_'))
         save_json(resource, resource_file_name)
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

     def sort_fields(fields)
       #
       # Sort fields by their column_number but put children after parents.
       #
       fathers = fields.to_a.sort_by{|k,v| v['column_number']}.select {|k,val| !val.key?('auto_generated')}
       children = fields.to_a.sort_by{|k,v| v['column_number']}.select {|k,val| val.key?('auto_generated') }.reverse
  
       fathers_keys = fathers.collect {|father| father[0]}

       children.each do |child|
         begin
           index = fathers_keys.index(child[1]['parent_ids'][0])
         rescue Exception
            index = -1
         end
        
         if index >= 0
           fathers.insert(index+1, child)
         else
           fathers << child
         end
       end

       return fathers

     end

     def strip_affixes(value, field)
        # Strips prefixes and suffixes if present
        #
        if field.include?('prefix')  and value.start_with?(field['prefix'])
            value = value[field['prefix'].size..-1]
        end

        if field.include?('suffix') and value.end_with?(field['suffix'])
            value = value[0..-(field['suffix'].size-1)]
        end

        return value

     end

     def cast(input_data, fields)
       #
       # Checks expected type in input data values, strips affixes and casts
       #
       input_data.each do |key,value|

          if (!!value == value and fields[key]['optype'] == 'categorical' and
               fields[key]['summary']['categories'].size == 2)
 
             begin
               booleans = {}
               categories = [] 
               fields[key]['summary']['categories'].each do |category, _|
                 categories << category
               end
               # checking which string represents the boolean
               categories.each do |category|
                 bool_key = Parsr.literal_eval(category) ? 'true' : 'false'
                 booleans[bool_key] = category
               end
               # converting boolean to the corresponding string
	       #
               input_data[key] = booleans[value.to_s]
             rescue Exception
	        raise ArgumentError.new("Mismatch input data type in 
		                         field \"%s\" for value %s.
					  String expected" % [fields[key]['name'], value])
             end

          elsif  ((fields[key]['optype'] == 'numeric' and
              value.is_a?(String)) or (fields[key]['optype'] != 'numeric') and 
              !value.is_a?(String))
              begin
                 if fields[key]['optype'] == 'numeric'
                   value = strip_affixes(value, fields[key])
                   input_data[key] = value.to_f
                 else
                   input_data[key] = value.to_s
                 end
 
              rescue Exception
                 raise ArgumentError.new("Mismatch input data type in 
                                         field %s for value %s. " % [fields[key]['name'], value])
              end
          elsif (fields[key]['optype'] == 'numeric' and !!value == value)
             raise ArgumentError.new("Mismatch input data type in field
                                     %s for value %s. Numeric expected." % [fields[key]['name'], value])
          end

       end

     end

     def get_predictions_file_name(model, path)
       #
       # Returns the file name for a multimodel predictions file
       #
       if model.is_a?(Hash) and model.key?('resource')
         model = model['resource']
       end
       return File.join(path, "%s_%s" % [model.gsub("/", "_"), PREDICTIONS_FILE_SUFFIX])
     end

     def slugify(name, reserved_keywords=nil, prefix='')
       #  Translates a field name into a variable name.
       name = name.downcase
       name = ActiveSupport::Multibyte::Chars.new(name).normalize(:kd).gsub(/[^\x00-\x7F]/, '').to_s
       name = name.gsub(/(\W+)/, '_')

       if !(/\A\d+\z/.match(name[0])).nil?
          name = "field_" + name
       end

       if !reserved_keywords.nil? and !reserved_keywords.empty?
          if reserved_keywords.include?(name)
             name = prefix + name
          end
       end

       return name
     end

     def plural(text, num)
       # Pluralizer: adds "s" at the end of a string if a given number is > 1
       return "%s%s" % [text, num > 1 ? "s" : ""]
     end
     
     def localize(number)
      #Localizes `number` to show commas appropriately.
      return  number.to_s.reverse.gsub(/(\d{3})/,"\\1,").chomp(",").reverse
     end
     
     def split(children)
       # Returns the field that is used by the node to make a decision.
       field = children.collect{|child| child.predicate.field }.uniq
       if field.size == 1
         return field[0]
       end
     end
     
     def find_locale(data_locale="UTF-8", verbose=false)
        begin
          encoding = Encoding.find(data_locale)
          if encoding.nil? and !encoding.index(".").nil?
             encoding = Encoding.find(data_locale.split(".")[-1])
             if encoding.nil?
                encoding = Encoding.find("UTF-8")
             end
             Encoding.default_external = encoding
          end
        rescue Exception
          puts "Error find Locale"
        end
 
     end
     
     def is_status_final(resource)
       # Try whether a resource is in a final state
       begin
         status = get_status(resource)
       rescue
         status['code'] = nil
       end  
       
       return [BigML::FINISHED, BigML::FAULTY].include?(status['code'])
     end 
     
     def save_json(resource, path)
       # Stores the resource in the user-given path in a JSON format
       # 
       begin
         resource_json = JSON.generate(resource)
         return save(resource_json, path)
       rescue IOError
         puts "Failed writing resource to %s" % path
       rescue ArgumentError
         puts "The resource has an invalid JSON format"
       end 
     end 
     
     def save(resource, path)
       # Stores the resource in the user-given path in a JSON format
       # 
       if path.nil?
         datestamp = Time.now.strftime("%a%b%d%y_%H%M%S")
         path = BigML::Util::DFT_STORAGE_FILE % datestamp
       end 
       
       check_dir(File.dirname(path))
       
       File.open(path, "w:UTF-8") do |resource_file|
         resource_file.write resource
       end
       
       return path
     end 
     
     # markdown_cleanup
     # prefix_as_comment
     # clear_console_line
     # reset_console_line
     # console_log
     # get_csv_delimiter

   end
  end
end  
