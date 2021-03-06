# frozen_string_literal: true

# Copyright (c) 2020 Konstantin Ermolchev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class Misete::SchemaParser
  def initialize(schema_path, params = {})
    @schema = init_hash
    @current_table = nil
    @table_names = params[:tables]
    @schema_path = schema_path
  end

  def parse
    file.each_line { |line| process_line(line) }
    @schema
  end

  def self.parse(filename, params={})
    new(filename, params).parse
  end

  private

  def file
    File.open(@schema_path)
  end

  def process_line(line)
    if table?
      process_columns(line)
    else
      process_table_name(line)
      process_table_options(line) if table?
    end
  end

  def process_columns(line)
    add_column(extract_column(line))
    end_table if line.strip == 'end'
  end

  def extract_column(line)
    column, options = line.split(',', 2)
    column_type, column_name = column.match(/t.(?<type>\w+) "(?<name>\S+)"/).to_a.last(2)

    return {} unless column_name

    {}.tap do |hash|
      hash[column_name] = { type: column_type.strip }
      hash[column_name].merge!({ params: options.strip }) if options
    end
  end

  def add_column(column)
    @schema[:tables][@current_table][:columns] ||= {}
    @schema[:tables][@current_table][:columns].merge!(column)
  end

  def process_table_name(line)
    table_name = extract_table_name(line)
    return if @table_names && !@table_names.include?(table_name)

    begin_table(table_name) if table_name
  end

  def extract_table_name(line)
    matches = line.match(/create_table "(?<table_name>\S+)",/)
    matches[:table_name].strip if matches
  end

  def process_table_options(line)
    params = extract_options(line)
    @schema[:tables][@current_table].merge!(params: params) if params
  end

  def extract_options(line)
    matches = line.match(/create_table "(?<table_name>\S+)", (?<options>.*:.*?) .(?:(?!do).)/)

    return unless matches && matches[:options]

    pairs = matches[:options].gsub(':', '').split(',').map { |pairs| pairs.split(' ', 2) }
    Hash[pairs]
  end

  def begin_table(table_name)
    @current_table = table_name
    @schema[:tables][table_name] = {}
  end

  def end_table
    @current_table = nil
  end

  def table?
    @current_table
  end

  def init_hash
    Hash.new { |k,v| k[v] = {} }
  end
end
