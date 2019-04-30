require 'sqlite3'

module Selection
    def find(*ids)
      #questions about these stars
      raise ArgumentError, 'Bro, what are you trying to do to us, chill...' unless id.is_a?(Integer) && id >= 0
      if ids.length == 1
        find_one(ids.first)
      else
        rows = connection.execute <<-SQL
          SELECT #{columns.join ","} FROM #{table}
          WHERE id IN (#{ids.join(",")});
        SQL

        rows_to_array(rows)
      end
    end

  def find_one(id)
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE id = #{id};
    SQL

    init_object_from_row(row)
  end


  def find_by(attribute, value)
    raise ArgumentError, "`#{attribute}` cant be found here." unless columns.include?(attribute)

    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{attribute} = #{BlocRecord::Utility.sql_strings(value)};
    SQL

    rows_to_array(rows)
  end


  def find_each(start=0,batch=start)

    size = start

    while size > 0
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY #{id}
        LIMIT #{start.abs} OFFSET #{(start-size).abs};
      SQL

      rows_to_array(rows)

      rows.each do |row|
        yield(row)
      end

      size -= batch
    end
  end

  def find_in_batches(start=0, batch=start)
    size = start
    while size > 0
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY #{id}
        LIMIT #{start.abs} OFFSET #{(start-size).abs};
      SQL
      rows_to_array(rows)
      yield(row)
      size -= batch
    end
  end

  def take(num=1)
    raise ArgumentError, 'Has to be an Integer.' unless num.is_a?(Integer)
    if num > 1
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY random()
        LIMIT #{num};
      SQL

      rows_to_array(rows)
    else
      take_one
    end
  end

  def take_one
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY random()
      LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def first
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id ASC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def last
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id DESC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def all
  rows = connection.execute <<-SQL
    SELECT #{columns.join ","} FROM #{table};
  SQL

  rows_to_array(rows)
end

def method_missing(method, *args)
  attribute = method.to_s
  attribute.slice!("find_by_")
  find_by(attribute, args[0])
end

def where(*args)
  if args.count > 1
    expression = args.shift
    params = args
  else
    case args.first
    when String
      expression = args.first
    when Hash
      expression_hash = BlocRecord::Utility.convert_keys(args.first)
      expression = expression_hash.map {|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}"}.join(" and ")
    end
  end

  sql = <<-SQL
    SELECT #{columns.join ","} FROM #{table}
    WHERE #{expression};
  SQL

  rows = connection.execute(sql, params)
  rows_to_array(rows)
end

def order(*args)
  arr = []
  args.each do |arg|
    case arg
    when String
      arr << arg
    when Symbol
      arr << arg.to_s
    when Hash
      arr << arg.map{|key, value| "#{key} #{value}"}
    end
  end
  order = arr.join(",")

  rows = connection.execute <<-SQL
    SELECT * FROM #{table}
    ORDER BY #{order};
  SQL
  rows_to_array(rows)
end


def join(*args)
  if args.count > 1
    joins = args.map { |arg| "INNER JOIN #{arg} ON #{arg}.#{table}_id = #{table}.id"}.join(" ")
    rows = connection.execute <<-SQL
      SELECT * FROM #{table} #{joins}
    SQL
  else
    case args.first
    when String
      rows = connection.execute <<-SQL
        SELECT * FROM #{table} #{BlocRecord::Utility.sql_strings(args.first)};
      SQL
    when Symbol
      rows = connection.execute <<-SQL
        SELECT * FROM #{table}
        INNER JOIN #{args.first} ON #{args.first}.#{table}_id = #{table}.id
      SQL
    when Hash
      assoc = args.shift
      rows = connection.execute <<-SQL
        SELECT * FROM #{table}
        INNER JOIN #{assoc.first} ON #{assoc.first}.#{table}_id = #{table}.id
        INNER JOIN #{assoc.last} ON #{assoc.last}.#{assoc.first}_id = #{assoc.first}.id
      SQL
    end
  end
  rows_to_array(rows)
end

  private
    def init_object_from_row(row)
      if row
        data = Hash[columns.zip(row)]
        new(data)
        #what is this
      end
    end

  def rows_to_array(rows)
    rows.map { |row| new(Hash[columns.zip(row)]) }
  end
end
