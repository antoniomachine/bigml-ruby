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

#
#  Item object for the Association resource.
#  This module defines each item in an Association resource.
#

module BigML
  
   class Item
      # 
      #  Object encapsulating an Association resource item as described in
      #  https://bigml.com/developers/associations
      #
      #
      attr_accessor :name, :field_id, :complement, :complement_index,
                    :count, :description, :field_info, :bin_end,
		    :bin_start, :index

      def initialize(index, item_info, fields)

         @index = index     
         @complement = item_info.fetch('complement', false)
         @complement_index = item_info.fetch('complement_index', nil)
         @count = item_info.fetch('count', nil)
         @description = item_info.fetch('description', nil)
         @field_id = item_info.fetch('field_id', nil)
         @field_info = fields[@field_id]
         @name = item_info.fetch('name', nil)
         @bin_end = item_info.fetch('bin_end', nil)
         @bin_start = item_info.fetch('bin_start', nil)
        
      end

      def out_format(language="JSON")
        #
        # Transforming the item structure to a string in the required format
        #
        if SUPPORTED_LANGUAGES.include?(language)
           return self.send("to_%s" % language.lower())
        end
      end

      def to_csv()
        #
        # Transforming the item to CSV formats
        #
        output = [@complement, @complement_index, @count,
                  @description, @field_info['name'], @name,
                  @bin_end, @bin_start]
        return output
      end

      def to_json()
        #
        # Transforming the item relevant information to JSON
        #
        item_dict = {}
        self.instance_variables.each {|var| item_dict[var.to_s.delete("@")] = self.instance_variable_get(var) }

        item_dict.delete("field_info")
        item_dict.delete("complement_index")
        item_dict.delete("index")

        return item_dict
      end

      def describe()
        #
        # Human-readable description of a item_dict
        # 
        
        description = ""
        if @name.nil?
            return "%s is %smissing" % [ 
                @field_info['name'], @complement ? "not " : ""]
        end

        field_name = @field_info['name']
        field_type = @field_info['optype']

        if field_type == "numeric"
            start = @complement ? @bin_end : @bin_start 
            _end = @complement ? @bin_start : @bin_end
 
            if !start.nil? and !_end.nil?
                if start < _end
                    description = "%s < %s <= %s" % [start,
                                                     field_name,
                                                     _end]
                else
                    description = "%s > %s or <= %s" % [field_name,
                                                        start,
                                                        _end]
                end
            elsif !start.nil?
                description = "%s > %s" % [field_name, start]
            else
                description = "%s <= %s" % [field_name, _end]
            end
        elsif field_type == "categorical"
            operator = @complement ? "!=" : "="
            description = "%s %s %s" % [field_name, operator, @name]

        elsif ["text", "items"].include?(field_type)
            operator = @complement ? "excludes" : "includes"
            description = "%s %s %s" % [field_name, operator, @name]
        else
            description = @name
        end

        return description

      end

      def matches(value)
        #
        # Checks whether the value is in a range for numeric fields or
        # matches a category for categorical fields.
        #

        field_type = @field_info['optype']
        if value.nil?
            return @name.nil?
        end

        if field_type == "numeric" and (
                !@bin_end.nil?  or !@bin_start.nil?)
            if !@bin_start.nil? and !@bin_end.nil?
                result = @bin_start <= value <= @bin_end
            elsif !@bin_end.nil?
                result = value <= @bin_end
            else
                result = value >= @bin_start
            end
        elsif field_type == 'categorical'
            result = @name == value
        elsif field_type == 'text'
            # for text fields, the item.name or the related term_forms should
            # be in the considered value
            all_forms = @field_info['summary'].fetch('term_forms', {})
            term_forms = all_forms.get(@name, [])
            terms = [@name]
            terms.concat(term_forms)
            options = @field_info['term_analysis']
            result = term_matches(value, terms, options) > 0
        elsif field_type == 'items'
            # for item fields, the item.name should be in the considered value
            # surrounded by separators or regexp
            options = @field_info['item_analysis']
            result = item_matches(value, @name, options) > 0
        end

        if @complement
            result = !result
        end
        return result

      end
 
   end

end

