require 'test/unit'
require 'test/FbTestCases'
# require 'fb'
# require 'date'

# include Fb

class DataTypesTestCases < Test::Unit::TestCase
  include FbTestCases
  
  def gen_i(i)
    i
  end
  
  def gen_si(i)
    i
  end
  
  def gen_bi(i)
    i * 1000000000
  end
  
  def gen_f(i)
    i / 2
  end
  
  def gen_d(i)
    i * 3333 / 2
  end
  
  def gen_c(i)
    "%c" % (i + 64)
  end
  
  def gen_c10(i)
    gen_c(i) * 5
  end
  
  def gen_vc(i)
    gen_c(i)
  end
  
  def gen_vc10(i)
    gen_c(i) * i
  end
  
  def gen_vc10000(i)
    gen_c(i) * i * 1000
  end
  
  def gen_dt(i)
    Date.civil(2000, i+1, i+1)
  end
  
  def gen_tm(i)
    Time.utc(1990, 1, 1, 12, i, i)
  end
  
  def gen_ts(i)
    Time.local(2006, 1, 1, i, i, i)
  end

  def gen_n92(i)
    i * 100
  end

  def gen_d92(i)
    i * 100
  end

  def test_insert_basic_types
    sql_schema = <<-END
      create table TEST (
        I INTEGER,
        SI SMALLINT,
        BI BIGINT,
        F FLOAT, 
        D DOUBLE PRECISION,
        C CHAR,
        C10 CHAR(10),
        VC VARCHAR(1),
        VC10 VARCHAR(10),
        VC10000 VARCHAR(10000),
        DT DATE,
        TM TIME,
        TS TIMESTAMP,
        N92 NUMERIC(9,2),
        D92 DECIMAL(9,2));
      END
    sql_insert = <<-END
      insert into test 
        (I, SI, BI, F, D, C, C10, VC, VC10, VC10000, DT, TM, TS, N92, D92) 
        values
        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      END
    sql_select = "select * from TEST order by I"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      connection.transaction do
        10.times do |i|
          connection.execute(
            sql_insert, 
            gen_i(i), gen_si(i), gen_bi(i),
            gen_f(i), gen_d(i),
            gen_c(i), gen_c10(i), gen_vc(i), gen_vc10(i), gen_vc10000(i), 
            gen_dt(i), gen_tm(i), gen_ts(i),
            gen_n92(i), gen_d92(i))
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :hash do |row|
          assert_equal gen_i(i), row["I"], "INTEGER"
          assert_equal gen_si(i), row["SI"], "SMALLINT"
          assert_equal gen_bi(i), row["BI"], "BIGINT"
          assert_equal gen_f(i), row["F"], "FLOAT"
          assert_equal gen_d(i), row["D"], "DOUBLE PRECISION"
          assert_equal gen_c(i), row["C"], "CHAR"
          assert_equal gen_c10(i).ljust(10), row["C10"], "CHAR(10)"
          assert_equal gen_vc(i), row["VC"], "VARCHAR(1)"
          assert_equal gen_vc10(i), row["VC10"], "VARCHAR(10)"
          assert_equal gen_vc10000(i), row["VC10000"], "VARCHAR(10000)"
          assert_equal gen_dt(i), row["DT"], "DATE"
          #assert_equal gen_tm(i).strftime("%H%M%S"), row["TM"].utc.strftime("%H%M%S"), "TIME"
          assert_equal gen_ts(i), row["TS"], "TIMESTAMP"
          assert_equal gen_n92(i), row["N92"], "NUMERIC"
          assert_equal gen_d92(i), row["D92"], "DECIMAL"
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_blobs_text
    sql_schema = "create table test (id int, name varchar(20), memo blob sub_type text)"
    sql_insert = "insert into test (id, name, memo) values (?, ?, ?)"
    sql_select = "select * from test order by id"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      memo = IO.read("fb.c")
      assert memo.size > 50000
      connection.transaction do
        10.times do |i|
          connection.execute(sql_insert, i, i.to_s, memo);
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :hash do |row|
          assert_equal i, row["ID"]
          assert_equal i.to_s, row["NAME"]
          assert_equal memo, row["MEMO"]
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_blobs_binary
    sql_schema = "create table test (id int, name varchar(20), attachment blob segment size 1000)"
    sql_insert = "insert into test (id, name, attachment) values (?, ?, ?)"
    sql_select = "select * from test order by id"
    #filename = "data.dat"
    filename = "fb.c"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      attachment = File.open(filename,"rb") do |f|
        f.read * 3
      end
      assert((attachment.size > 150000), "Not expected size")
      connection.transaction do
        3.times do |i|
          connection.execute(sql_insert, i, i.to_s, attachment);
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :array do |row|
          assert_equal i, row[0], "ID's do not match"
          assert_equal i.to_s, row[1], "NAME's do not match"
          assert_equal attachment.size, row[2].size, "ATTACHMENT sizes do not match"
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_incorrect_types
    cols = %w{ I SI BI F D C C10 VC VC10 VC10000 DT TM TS }
    types = %w{ INTEGER SMALLINT BIGINT FLOAT DOUBLE\ PRECISION CHAR CHAR(10) VARCHAR(1) VARCHAR(10) VARCHAR(10000) DATE TIME TIMESTAMP }
    sql_schema = "";
    assert_equal cols.size, types.size
    cols.size.times do |i|
      sql_schema << "CREATE TABLE TEST_#{cols[i]} (VAL #{types[i]});\n"
    end
    Database.create(@parms) do |connection|
      connection.execute_script(sql_schema)
      cols.size.times do |i|
        sql_insert = "INSERT INTO TEST_#{cols[i]} (VAL) VALUES (?);"
        if cols[i] == 'I'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 5000000000)
          end
        elsif cols[i] == 'SI'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 100000)
          end
        elsif cols[i] == 'BI'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 184467440737095516160) # 2^64 * 10
          end
        elsif cols[i] == 'F'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 10 ** 39)
          end
        elsif cols[i] == 'D'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
        elsif cols[i] == 'VC'
          assert_raise RangeError do
            connection.execute(sql_insert, "too long")
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 1.0/3.0)
          end
        elsif cols[i] ==  'VC10'
          assert_raise RangeError do
            connection.execute(sql_insert, 1.0/3.0)
          end
        elsif cols[i].include?('VC10000')
          assert_raise RangeError do
            connection.execute(sql_insert, "X" * 10001)
          end
        elsif cols[i] == 'C'
          assert_raise RangeError do
            connection.execute(sql_insert, "too long")
          end
        elsif cols[i] == 'C10'
          assert_raise RangeError do
            connection.execute(sql_insert, Time.now)
          end
        elsif cols[i] == 'DT'
          assert_raise ArgumentError do
            connection.execute(sql_insert, Date)
          end
          assert_raise ArgumentError do
            connection.execute(sql_insert, 2006)
          end
        elsif cols[i] == 'TM'
          assert_raise TypeError do
            connection.execute(sql_insert, {:date => "2006/1/1"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, 10000)
          end
        elsif cols[i] ==  'TS'
          assert_raise TypeError do
            connection.execute(sql_insert, 5.5)
          end
          assert_raise TypeError do
            connection.execute(sql_insert, 10000)
          end
        elsif cols[i] ==  'N92'
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 5000000000)
          end
        elsif cols[i] ==  'D92' 
          assert_raise TypeError do
            connection.execute(sql_insert, {:five => "five"})
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 5000000000)
          end
        end
      end
      connection.drop
    end
  end

  def test_insert_correct_types
    cols = %w{ I SI BI F D C C10 VC VC10 VC10000 DT TM TS N92 D92 }
    types = %w{ INTEGER SMALLINT BIGINT FLOAT DOUBLE\ PRECISION CHAR CHAR(10) VARCHAR(1) VARCHAR(10) VARCHAR(10000) DATE TIME TIMESTAMP NUMERIC(9,2) DECIMAL(9,2) }
    sql_schema = "";
    assert_equal cols.size, types.size
    cols.size.times do |i|
      sql_schema << "CREATE TABLE TEST_#{cols[i]} (VAL #{types[i]});\n"
    end
    Database.create(@parms) do |connection|
      connection.execute_script(sql_schema)
      cols.size.times do |i|
        sql_insert = "INSERT INTO TEST_#{cols[i]} (VAL) VALUES (?);"
        sql_select = "SELECT * FROM TEST_#{cols[i]};"
        if cols[i] == 'I'
          connection.execute(sql_insert, 500_000)
          connection.execute(sql_insert, "500_000")
          vals = connection.query(sql_select)
          assert_equal 500_000, vals[0][0]
          assert_equal 500_000, vals[1][0]
        elsif cols[i] == 'SI'
          connection.execute(sql_insert, 32_123)
          connection.execute(sql_insert, "32_123")
          vals = connection.query(sql_select)
          assert_equal 32_123, vals[0][0]
          assert_equal 32_123, vals[1][0]
        elsif cols[i] == 'BI'
          connection.execute(sql_insert, 5_000_000_000)
          connection.execute(sql_insert, "5_000_000_000")
          vals = connection.query(sql_select)
          assert_equal 5_000_000_000, vals[0][0]
          assert_equal 5_000_000_000, vals[1][0]
        elsif cols[i] == 'F'
          connection.execute(sql_insert, 5.75)
          connection.execute(sql_insert, "5.75")
          vals = connection.query(sql_select)
          assert_equal 5.75, vals[0][0]
          assert_equal 5.75, vals[1][0]
        elsif cols[i] == 'D'
          connection.execute(sql_insert, 12345.12345)
          connection.execute(sql_insert, "12345.12345")
          vals = connection.query(sql_select)
          assert_equal 12345.12345, vals[0][0]
          assert_equal 12345.12345, vals[1][0]
        elsif cols[i] == 'VC'
          connection.execute(sql_insert, "5")
          connection.execute(sql_insert, 5)
          vals = connection.query(sql_select)
          assert_equal "5", vals[0][0]
          assert_equal "5", vals[1][0]
        elsif cols[i] ==  'VC10'
          connection.execute(sql_insert, "1234567890")
          connection.execute(sql_insert, 1234567890)
          vals = connection.query(sql_select)
          assert_equal "1234567890", vals[0][0]
          assert_equal "1234567890", vals[1][0]
        elsif cols[i].include?('VC10000')
          connection.execute(sql_insert, "1" * 100)
          connection.execute(sql_insert, ("1" * 100).to_i)
          vals = connection.query(sql_select)
          assert_equal "1" * 100, vals[0][0]
          assert_equal "1" * 100, vals[1][0]
        elsif cols[i] == 'C'
          connection.execute(sql_insert, "5")
          connection.execute(sql_insert, 5)
          vals = connection.query(sql_select)
          assert_equal "5", vals[0][0]
          assert_equal "5", vals[1][0]
        elsif cols[i] == 'C10'
          connection.execute(sql_insert, "1234567890")
          connection.execute(sql_insert, 1234567890)
          vals = connection.query(sql_select)
          assert_equal "1234567890", vals[0][0]
          assert_equal "1234567890", vals[1][0]
        elsif cols[i] == 'DT'
          connection.execute(sql_insert, Date.civil(2000,2,2))
          connection.execute(sql_insert, "2000/2/2")
          connection.execute(sql_insert, "2000-2-2")
          vals = connection.query(sql_select)
          assert_equal Date.civil(2000,2,2), vals[0][0]
          assert_equal Date.civil(2000,2,2), vals[1][0]
        elsif cols[i] == 'TM'
          connection.execute(sql_insert, Time.utc(2000,1,1,2,22,22))
          connection.execute(sql_insert, "2000/1/1 2:22:22")
          connection.execute(sql_insert, "2000-1-1 2:22:22")
          vals = connection.query(sql_select)
          assert_equal Time.utc(2000,1,1,2,22,22), vals[0][0]
          assert_equal Time.utc(2000,1,1,2,22,22), vals[1][0]
        elsif cols[i] ==  'TS'
          connection.execute(sql_insert, Time.local(2006,6,6,3,33,33))
          connection.execute(sql_insert, "2006/6/6 3:33:33")
          connection.execute(sql_insert, "2006-6-6 3:33:33")
          vals = connection.query(sql_select)
          assert_equal Time.local(2006,6,6,3,33,33), vals[0][0]
          assert_equal Time.local(2006,6,6,3,33,33), vals[1][0]
          assert_equal Time.local(2006,6,6,3,33,33), vals[2][0]
        elsif cols[i] == 'N92'
          connection.execute(sql_insert, 12345.12)
          connection.execute(sql_insert, "12345.12")
          vals = connection.query(sql_select)
          # puts vals.inspect
          assert_equal 12345.12, vals[0][0], "NUMERIC (decimal)"
          assert_equal 12345.12, vals[1][0], "NUMERIC (string)"
        elsif cols[i] == 'D92'
          connection.execute(sql_insert, 12345.12)
          connection.execute(sql_insert, "12345.12")
          vals = connection.query(sql_select)
          # puts vals.inspect
          assert_equal 12345.12, vals[0][0], "DECIMAL (decimal)"
          assert_equal 12345.12, vals[1][0], "DECIMAL (string)"
        end
      end
      connection.drop
    end
  end
end
