#!/usr/bin/env ruby

require 'pg'

def connect()
    puts ">>>> Connecting to YugabyteDB!\n";

    conn = PG.connect(
        host: '127.0.0.1',
        port: '5433',
        dbname: 'yugabyte',
        user: 'yugabyte',
        password: 'yugabyte',
        sslmode: 'disable',
        sslrootcert: ''
        );

    puts ">>>> Successfully connected to YugabyteDB!\n";

    return conn
end

def create_database(conn)
    conn.exec("DROP TABLE IF EXISTS DemoAccount");

    conn.exec("CREATE TABLE DemoAccount ( \
                id int PRIMARY KEY, \
                name varchar, \
                age int, \
                country varchar, \
                balance int)");
    
    conn.exec("INSERT INTO DemoAccount VALUES \
                (1, 'Jessica', 28, 'USA', 10000), \
                (2, 'John', 28, 'Canada', 9000)");

    puts ">>>> Successfully created table DemoAccount.\n";
end

def select_accounts(conn)
    begin
        puts ">>>> Selecting accounts:\n";

        rs = conn.exec("SELECT name, age, country, balance FROM DemoAccount");

        rs.each do |row|
            puts "name=%s, age=%s, country=%s, balance=%s\n" % [row['name'], row['age'], row['country'], row['balance']];
        end

    ensure
        rs.clear if rs
    end
end

def transfer_money_between_accounts(conn, amount)
    begin
        conn.transaction do |txn|
            txn.exec_params("UPDATE DemoAccount SET balance = balance - $1 WHERE name = \'Jessica\'", [amount]);
            txn.exec_params("UPDATE DemoAccount SET balance = balance + $1 WHERE name = \'John\'", [amount]);
        end

        puts ">>>> Transferred %s between accounts.\n" % [amount];

    rescue PG::TRSerializationFailure => e
        puts "The operation is aborted due to a concurrent transaction that is modifying the same set of rows. \
              Consider adding retry logic or using the pessimistic locking.";
        raise
    end
end

begin
    # Output a table of current connections to the DB
    conn = connect();
  
    create_database(conn);
    select_accounts(conn);
    transfer_money_between_accounts(conn, 800);
    select_accounts(conn);
  
rescue PG::Error => e
    puts e.message
ensure
    conn.close if conn
end
