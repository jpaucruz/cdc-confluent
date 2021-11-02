create schema confluent;
alter schema confluent owner to admin;

create table confluent.customers
(
  id serial not null constraint customers_pk primary key,
  first_name varchar not null,
  last_name varchar not null,
  email varchar not null
);

ALTER TABLE confluent.customers REPLICA IDENTITY FULL;
INSERT INTO confluent.customers (first_name, last_name, email) VALUES ('Sally', 'Thomas', 'sally.thomas@acme.com');
INSERT INTO confluent.customers (first_name, last_name, email) VALUES ('George', 'Bailey', 'gbailey@foobar.com');
INSERT INTO confluent.customers (first_name, last_name, email) VALUES ('Edward', 'Walker', 'ed@walker.com');
INSERT INTO confluent.customers (first_name, last_name, email) VALUES ('Anne', 'Kretchmar', 'annek@noanswer.org');
