CREATE TABLE lists (
  id serial PRIMARY KEY,
  name varchar(25) NOT NULL UNIQUE
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name varchar(40) NOT NULL,
  completed boolean NOT NULL DEFAULT FALSE,
  list_id integer NOT NULL REFERENCES lists(id)
);
