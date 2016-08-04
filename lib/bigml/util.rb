require 'json'
require 'active_support'

module BigML
  class Util 
   PREDICTIONS_FILE_SUFFIX = '_predictions.csv'
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
            resource_json=JSON.generate(resource)
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
          if  ((fields[key]['optype'] == 'numeric' and
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
                 raise ArgumentError "Mismatch input data type in 
                                        field %s for value %s. " % [fields[key]['name'], value]
              end

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

   end
  end
end  
