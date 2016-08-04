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
module BigML

  EXTENDED = 0
  BRIEF = 1
  NUMERIC = 'numeric'
  CATEGORICAL = 'categorical'
  TEXT = 'text'
  DATETIME = 'datetime'
  ITEMS = 'items'

  REVERSE_OP = {'<' => '>', '>' => '<'}


  def self.reverse(operator)
    # Reverses the unequality operators
    return "%s%s" % [REVERSE_OP[operator[0]], operator[1..-1]]
  end

  def self.merge_rules(list_of_predicates, fields, label='name')
    #Summarizes the predicates referring to the same field

    if !list_of_predicates.nil? and !list_of_predicates.empty?
        field_id = list_of_predicates[0].field
        field_type = fields[field_id]['optype']
        missing_flag = nil 
        name = fields[field_id][label]
        last_predicate = list_of_predicates[-1]
        # if the last predicate is "is missing" forget about the rest
        if last_predicate.operator == "=" and last_predicate.value.nil?
            return "%s is missing" % [name]
        end
        # if the last predicate is "is not missing"
        if ["!", "/"].include?(last_predicate.operator[0]) and last_predicate.value.nil?
            if list_of_predicates.size == 1
                # if there's only one predicate, then write "is not missing"
                return "%s is not missing" % [name]
            end

            list_of_predicates = list_of_predicates[0..-2]
            missing_flag = false
        end

        if last_predicate.missing
            missing_flag = true
        end

        if field_type == NUMERIC
            return merge_numeric_rules(list_of_predicates, fields, label, missing_flag)
        end

        if field_type == TEXT
            return merge_text_rules(list_of_predicates, fields, label=label)
        end

        if field_type == CATEGORICAL
           return merge_categorical_rules(list_of_predicates, fields, label, missing_flag)
        end

        return list_of_predicates.collect {|predicate| predicate.to_rule(fields, label) }.join(" and ")
    end

  end

  def self.merge_numeric_rules(list_of_predicates, fields, label='name',
                        missing_flag=nil)
    # Summarizes the numeric predicates for the same field
    
    minor = [nil, -Float::INFINITY]
    major = [nil, Float::INFINITY]
    equal = nil

    list_of_predicates.each do |predicate|
      if (predicate.operator.start_with?('>') and
           predicate.value > minor[1])
           minor = [predicate, predicate.value]
      end

      if (predicate.operator.start_with?('<') and
           predicate.value < major[1])
           major = [predicate, predicate.value]
      end

      if ['!', '=', '/', 'i'].include?(predicate.operator[0])
         equal = predicate
         break
      end
    end

    if !equal.nil?
      return equal.to_rule(fields, label, missing_flag)
    end

    rule = ''
    field_id = list_of_predicates[0].field
    name = fields[field_id][label]

    if !minor[0].nil? and !major[0].nil?
        predicate = minor[0]
        value = minor[1]

        rule = "%s %s " % [value, reverse(predicate.operator)]
        rule += name
        predicate = major[0]
        value = major[1]

        rule += " %s %s " % [predicate.operator, value]
        if missing_flag
            rule += " or missing"
        end
    else
        predicate = minor[0].nil? ? major[0] : minor[0]
        rule = predicate.to_rule(fields, label, missing_flag)
    end

    return rule

  end

  def self.merge_text_rules(list_of_predicates, fields, label='name')
    #
    # Summarizes the text predicates for the same field
    #
    _contains = []
    not_contains = []
    list_of_predicates.each do |predicate|
       if ((predicate.operator == '<' and predicate.value <= 1) or
             (predicate.operator == '<=' and predicate.value == 0))
          not_contains << predicate
       else
          _contains << predicate
       end
    end 

    rules = []
    rules_not = []

    if !_contains.empty?
        rules << contains[0].to_rule(fields, label).strip
  
        _contains[1..-1].each do |predicate|
          if !rules.include?(predicate.term)
            rules << predicate.term
          end
        end
    end

    rule = rules.join(" and ")
    if !not_contains.empty?
        if rules.nil? or rules.empty?
            rules_not <<  not_contains[0].to_rule(fields, label).strip
        else
            rules_not << " and %s " % [ not_contains[0].to_rule(fields, label).strip]
        end

        not_contains[1..-1].each do |predicate|
           if !rules_not.include?(predicate.term)
              rules_not << predicate.term
           end
        end
    end

    rule += rules_not.join(" or ")
    return rule
  end
  
  def self.merge_categorical_rules(list_of_predicates,
                              fields, label='name', missing_flag=nil)
    # Summarizes the categorical predicates for the same field

    equal = []
    not_equal = []

    list_of_predicates.each do |predicate|
      if predicate.operator.start_with?("!")
        not_equal << predicate
      else
        equal << predicate
      end
 
    end

    rules = []
    rules_not = []

    if !equal.empty?
        rules << equal[0].to_rule(fields, label, false).strip
        equal[1..-1].each do |predicate|
            if !rules.include?(predicate.value)
               rules << predicate.value
            end
        end
    end

    rule = rules.join(" and ")

    if !not_equal.empty? and rules.empty?
        rules_not << not_equal[0].to_rule(fields, label, false).strip

        not_equal[1..-1].each do |predicate| 
           if !rules_not.include?(predicate.value)
              rules_not << predicate.value
           end
        end
 
    end

    if !rules_not.empty?
        connector =  rule.empty? ? "" : " and "
        rule += connector +  rules_not.join(" or ")
    end

    if missing_flag
        rule += " or missing"
    end

    return rule

  end

  class Path
     attr_accessor :predicates

     def initialize(predicates=nil)
       #  Path instance constructor accepts only lists of Predicate objects
       if predicates.nil? or predicates.empty?
            @predicates = []
       elsif predicates.is_a?(Array) and predicates[0].is_a?(Predicate) 
            @predicates = predicates
       else
            raise ArgumentError, "The Path constructor accepts a list of Predicate objects. Please check the arguments for the constructor"
       end
     end
  
     def to_rules(fields, label='name', format=EXTENDED)
        # Builds rules string from a list lf predicates in different formats

        if format == EXTENDED
            return to_extended_rules(fields, label)
        elsif format == BRIEF
            return to_brief_rules(fields, label)
        else
            raise ArgumentError , "Invalid format. The list of valid formats are 0 (extended) or 1 (brief)"
        end
     end

     def to_extended_rules(fields, label='name')
        # Builds rules string in ordered and extended format
        list_of_rules = []
      
        @predicates.each do |predicate|
           list_of_rules << predicate.to_rule(fields, label).strip
        end
 
        return list_of_rules.join(" and ")
     end

     def to_brief_rules(fields, label='name')
        # Builds rules string in brief format (grouped and unordered)
        groups_of_rules = {}
        list_of_fields = []
 
        @predicates.each do |predicate|
           if !groups_of_rules.include?(predicate.field)
              groups_of_rules[predicate.field] = [] 
              list_of_fields << predicate.field
           end
 
           groups_of_rules[predicate.field] << predicate

        end

        lines = []

        list_of_fields.each do |field|
            lines << BigML::merge_rules(groups_of_rules[field], fields, label)
        end

        return lines.join(" and ")

     end
  
     def append(predicate)
        # Adds new predicate to the path
        @predicates << predicate
     end
  end

end  
