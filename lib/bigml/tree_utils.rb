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

# Tree utilities
# This module stores auxiliar functions used in tree traversal and
# code generators for the body of the local model plugins
#

module BigML

  #DEFAULT_LOCALE = 'en_US.UTF-8'
  #TM_TOKENS = 'tokens_only'
  #TM_FULL_TERM = 'full_terms_only'
  #TM_ALL = 'all'
  TERM_OPTIONS = ["case_sensitive", "token_mode"]
  ITEM_OPTIONS = ["separator", "separator_regexp"]
  COMPOSED_FIELDS = ["text", "items"]
  NUMERIC_VALUE_FIELDS = ["text", "items", "numeric"]

  MAX_ARGS_LENGTH = 10

  INDENT = '    '

  RUBY_OPERATOR = {
    "<" => :<,
    "<=" => :<=,
    "=" => :==,
    "!=" => :!=,
    "/=" => :!=,
    ">=" =>  :>=,
    ">" => :>,
  }

  # reserved keywords

  CS_KEYWORDS = [
    "abstract", "as", "base", "bool", "break", "byte", "case",
    "catch", "char", "checked", "class", "const", "continue", "decimal",
    "default", "delegate", "do", "double", "else", "enum", "event", "explicit",
    "extern", "false", "finally", "fixed", "float", "for", "foreach", "goto",
    "if", "implicit", "in", "int", "interface", "internal", "is", "lock", "long",
    "namespace", "new", "null", "object", "operador", "out", "override",
    "params", "private", "protected", "public", "readonly", "ref", "return",
    "sbyte", "sealed", "short", "sizeof", "stackalloc", "static", "string",
    "struct", "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong",
    "unchecked", "unsafe", "ushort", "using", "virtual", "void", "volatile",
    "while", "group", "set", "value"]

  VB_KEYWORDS = [
    'addhandler', 'addressof', 'alias', 'and', 'andalso', 'as',
    'boolean', 'byref', 'byte', 'byval', 'call', 'case', 'catch', 'cbool',
    'cbyte', 'cchar', 'cdate', 'cdec', 'cdbl', 'char', 'cint', 'class', 'clng',
    'cobj', 'const', 'continue', 'csbyte', 'cshort', 'csng', 'cstr',
    'ctype', 'cuint', 'culng', 'cushort', 'date', 'decimal', 'declare',
    'default', 'delegate', 'dim', 'directcast', 'do', 'double', 'each',
    'else', 'elseif', 'end', 'endif', 'enum', 'erase', 'error', 'event',
    'exit', 'false', 'finally', 'for', 'friend', 'function', 'get',
    'gettype', 'getxmlnamespace', 'global', 'gosub', 'goto', 'handles',
    'if', 'implements', 'imports ', 'in', 'inherits', 'integer', 'interface',
    'is', 'isnot', 'let', 'lib', 'like', 'long', 'loop', 'me', 'mod', 'module',
    'mustinherit', 'mustoverride', 'mybase', 'myclass', 'namespace',
    'narrowing', 'new', 'next', 'not', 'nothing', 'notinheritable',
    'notoverridable', 'object', 'of', 'on', 'operator', 'option',
    'optional', 'or', 'orelse', 'overloads', 'overridable', 'overrides',
    'paramarray', 'partial', 'private', 'property', 'protected',
    'public', 'raiseevent', 'readonly', 'redim', 'rem', 'removehandler',
    'resume', 'return', 'sbyte', 'select', 'set', 'shadows', 'shared',
    'short', 'single', 'static', 'step', 'stop', 'string', 'structure',
    'sub', 'synclock', 'then', 'throw', 'to', 'true', 'try',
    'trycast', 'typeof', 'variant', 'wend', 'uinteger', 'ulong',
    'ushort', 'using', 'when', 'while', 'widening', 'with', 'withevents',
    'writeonly', 'xor', '#const', '#else', '#elseif', '#end', '#if'
  ]

  JAVA_KEYWORDS = [
    "abstract", "continue", "for", "new", "switch", "assert", "default",
    "goto", "package", "synchronized", "boolean", "do", "if", "private",
    "this", "break", "double", "implements", "protected", "throw",
    "byte", "else", "import", "public", "throws", "case", "enum",
    "instanceof", "return", "transient", "catch", "extends", "int",
    "short", "try", "char", "final", "interface", "static", "void",
    "class", "finally", "long", "strictfp", "volatile", "const",
    "float", "native", "super", "while"
  ]

  OBJC_KEYWORDS = [
    "auto", "BOOL", "break", "Class", "case", "bycopy", "char", "byref",
    "const", "id", "continue", "IMP", "default", "in", "do", "inout",
    "double", "nil", "else", "NO", "enum", "NULL", "extern", "oneway",
    "float", "out", "for", "Protocol", "goto", "SEL", "if", "self",
    "inline", "super", "int", "YES", "long", "@interface", "register",
    "@end", "restrict", "@implementation", "return", "@protocol",
    "short", "@class", "signed", "@public", "sizeof", "@protected",
    "static", "@private", "struct", "@property", "switch", "@try",
    "typedef", "@throw", "union", "@catch()", "unsigned", "@finally",
    "void", "@synthesize", "volatile", "@dynamic", "while", "@selector",
    "_Bool", "atomic", "_Complex", "nonatomic", "_Imaginery", "retain"
  ]

  JS_KEYWORDS = [
    "break", "case", "catch", "continue", "debugger", "default", "delete",
    "do", "else", "finally", "for", "function", "if", "in", "instanceof",
    "new", "return", "switch", "this", "throw", "try", "typeof", "var",
    "void", "while", "with", "class", "enum", "export", "extends",
    "import", "super", "implements", "interface", "let", "package",
    "private", "protected", "public", "static", "yield", "null",
    "true", "const", "false"
  ]


  PYTHON_KEYWORDS = [
    "and", "assert", "break", "class", "continue", "def", "del", "elif",
    "else", "except", "exec", "finally", "for", "from", "global", "if",
    "import", "in", "is", "lambda", "not", "or", "pass", "print", "raise",
    "return", "try", "while ", "Data", "Float", "Int", "Numeric", "Oxphys",
    "array", "close", "float", "int", "input", "open", "range", "type",
    "write", "zeros", "acos", "asin", "atan", "cos", "e", "exp", "fabs",
    "floor", "log", "log10", "pi", "sin", "sqrt", "tan"
  ]

  def java_string(text)
    # Transforms string output for java, cs, and objective-c code
    text = "%s" % text
    return text.gsub("&quot;", "\"").gsub("\"", "\\\"")
  end

  def python_string(text)
    # Transforms string output for python code
    return text.gsub("&#39;", "\'").inspect
  end

  def ruby_string(text)
    # Transforms string output for ruby code
    out = python_string(text)
    if text.is_a?(String) and text.encoding.to_s == "UTF-8"
      return out[1..-1]
    end
    return out
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
   
   def self.filter_nodes(nodes_list, ids=nil, subtree=true)
     # Filters the contents of a nodes_list. If any of the nodes is in the
     #   ids list, the rest of nodes are removed. If none is in the ids list
     #   we include or exclude the nodes depending on the subtree flag.
     #
     if nodes_list.empty?
        return nil 
     end

     nodes = nodes_list.clone

     if !ids.nil?
         nodes.each do |node|
            if ids.include?(node["id"])
               nodes = [node]
               return nodes
            end
         end 
     end

     if !subtree
        nodes = []
     end

     return nodes

   end

   def self.missing_branch(children)
     # "Checks if the missing values are assigned to a special branch
     return children.any?{|child| child.predicate.missing }
   end

   def self.none_value(children)
     # Checks if the predicate has a nil value
     return children.any?{|child| child.predicate.value.nil?}
   end

   def self.one_branch(children, input_data)
     # Check if there's only one branch to be followed
     missing = input_data.include?(BigML::Util::split(children))
     return (missing or missing_branch(children) or none_value(children))
   end
   
   def self.tableau_string(text)
     # Transforms to a string representation in Tableau
     value = text
     
     if text.is_a?(String)
        return value[1..-1]
     end    
     
     return value
   end     
 
end
