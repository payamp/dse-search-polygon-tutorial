CREATE KEYSPACE IF NOT EXISTS geo WITH replication = {'class': 'SimpleStrategy', 'replication_factor' : 1};

CREATE TABLE IF NOT EXISTS geo.states (
	state text,
	fips int,
	pop  int,
	geo   text,
	PRIMARY KEY (state)
);
