## DSE Spatial Search 

Built using DSE 5.0.3

This tutorial is intended to show how to index geospatial shapes such as Polygons and MultiPolygons in Datastax Enterprise Search and subsequently query them. I am using data about States in the United States because it is a smaller data set which will make it easier to understand the effects of the geospatial predicates described below.

At a high level, the geospatial data is stored in Cassandra as **text** in [WKT (Well Known Text)] (https://en.wikipedia.org/wiki/Well-known_text) format. We configure the Search Schema to set the field to be of **solr.SpatialRecursivePrefixTreeFieldType** type which supports Polygons  and MultiPolygons. It supports other types as well, but in the provided example data, most states are describable as Polygons, and others such as Hawaii, Alaska, need a MultiPolygon to describe their geometric shape. 

By the end of this, I will be demonstrating how to do a Polygonal Search using the following geospatial predicates:

* Intersects
	* If the search geometry **overlaps any part** of the indexed/document geometry it is considered a match

* IsWithin
	* If the search geometry **completely encapsulates** the indexed/document geometry it is considered a match

* IsDisjointTo
	* Opposite of Intersects



## Step 1 (Load JTS library)

[JTS Topology Suite](http://tsusiatsoftware.net/jts/main.html) enables the indexing and search of non point based shapes. 
You need to download the jts library and save it in the solr lib directory. The default Solr library path depends on the type of installation.

[Refer to the Datastax documentation ](https://docs.datastax.com/en/latest-dse/datastax_enterprise/srch/queriesSpatial.html) to see the solr lib path based on your installation.

```
cd /path/to/solr/lib
curl -O 'http://central.maven.org/maven2/com/vividsolutions/jts/1.13/jts-1.13.jar'
```

**Important:** You will need to restart dse for the jts library to be loaded `service dse restart`






---
## Step 2 (copy files & create keyspace and table)

Copy all of the files  in the **files** directory of the project to any directory on the DSE instance. 

SSH into the instance, and cd into the directory with said files. 

### Important!
**Using SimpleStrategy with a Replication Factor of 1 is *NOT* recommended for production. Just using it to simplify a tutorial you can run on a laptop or single node.**



```
cqlsh -f create_geo_table.cql
```
###contents of `create_geo_table.cql`

```
CREATE KEYSPACE IF NOT EXISTS geo WITH replication = {'class': 'SimpleStrategy', 'replication_factor' : 1};

CREATE TABLE IF NOT EXISTS geo.states (
	state text,
	fips int,
	pop  int,
	geo   text,
	PRIMARY KEY (state)
);
```

As mentioned before, notice the **geo** column is of type **text** in Cassandra


-----
## Step 3 (configure search schema)


from the same **files** directory, run:

```
dsetool create_core -schema=./geo_states_schema.xml -solrconfig=./geo_states_solrconfig.xml
```

The key takeaway from the solr schema is that we are setting the **geo** to be of type **location_rpt** which is a **solr.SpatialRecursivePrefixTreeFieldType**

```
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<schema name="autoSolrSchema" version="1.5">
<types>

  <!--
    Note: make sure to copy the JTS.jar into the solr lib directory for this to work
  -->
  <fieldType name="location_rpt"   class="solr.SpatialRecursivePrefixTreeFieldType"
    spatialContextFactory="com.spatial4j.core.context.jts.JtsSpatialContextFactory"
    distErrPct="0.025"
    maxDistErr="0.000009"
    units="degrees"
    />

  <fieldType class="org.apache.solr.schema.TrieIntField" name="TrieIntField"/>
  <fieldType class="org.apache.solr.schema.StrField" name="StrField"/>
</types>

<fields>
<field indexed="true" multiValued="false" name="geo" stored="true" type="location_rpt"/>
<field indexed="true" multiValued="false" name="pop" stored="true" type="TrieIntField"/>
<field indexed="true" multiValued="false" name="state" stored="true" type="StrField"/>
<field indexed="true" multiValued="false" name="fips" stored="true" type="TrieIntField"/>
</fields>
<uniqueKey>state</uniqueKey>
</schema>

```
-----

## Step 4 (load the sample data)

From the same directory start **cqlsh** and run:

```
cqlsh> COPY geo.states (state, fips, geo, pop) FROM 'states.csv';
```


## solr_query examples

[Using this site](https://arthur-e.github.io/Wicket/sandbox-gmaps3.html) to create the WKT polygon (directly below) to use with the three predicates (Intersects, IsWithin, and IsDisjointTo).

I am using the following POLYGON for all 3 predicates below:
```
POLYGON((-125.419921875 49.98478613540782,-116.279296875 49.35912268752875,-115.927734375 42.72078596277834,-113.291015625 42.429538632268276,-112.8515625 37.06175259706908,-113.5546875 31.92186141844726,-123.22265625 30.946991356457197,-127.265625 38.93163900447185,-125.419921875 49.98478613540782))
```


![screen shot](https://www.dropbox.com/s/0xu972axwcs3g75/west_coast_polygon.png?dl=1).

##Intersects: 
```
SELECT state, fips, pop FROM geo.states where 
solr_query='{"q":"*:*","fq":"geo:\"Intersects(POLYGON((-125.419921875 49.98478613540782,-116.279296875 49.35912268752875,-115.927734375 42.72078596277834,-113.291015625 42.429538632268276,-112.8515625 37.06175259706908,-113.5546875 31.92186141844726,-123.22265625 30.946991356457197,-127.265625 38.93163900447185,-125.419921875 49.98478613540782)))\""}';
```
###Results:
![intersects results screenshot](https://www.dropbox.com/s/oolyucdadk5yv19/intersects_query_results.png?dl=1)

##IsWithin:


```
SELECT state, fips, pop FROM geo.states where 
solr_query='{"q":"*:*","fq":"geo:\"IsWithin(POLYGON((-125.419921875 49.98478613540782,-116.279296875 49.35912268752875,-115.927734375 42.72078596277834,-113.291015625 42.429538632268276,-112.8515625 37.06175259706908,-113.5546875 31.92186141844726,-123.22265625 30.946991356457197,-127.265625 38.93163900447185,-125.419921875 49.98478613540782)))\""}';
```

###Results:

![IsWithin Results](https://www.dropbox.com/s/w92cz6zfv9yr084/IsWithin_results.png?dl=1)


## IsDisjointTo
```
SELECT state, fips, pop FROM geo.states where 
solr_query='{"q":"*:*","fq":"geo:\"IsDisjointTo(POLYGON((-125.419921875 49.98478613540782,-116.279296875 49.35912268752875,-115.927734375 42.72078596277834,-113.291015625 42.429538632268276,-112.8515625 37.06175259706908,-113.5546875 31.92186141844726,-123.22265625 30.946991356457197,-127.265625 38.93163900447185,-125.419921875 49.98478613540782)))\""}';
```

###Results:

![IsDisjointTo results](https://www.dropbox.com/s/sxfnvxg03yg9ur9/IsDisjointTo_results.png?dl=1)

## Gotchas:

###**Intersecting Polygons** will not work

If you are building a UI, it would be good to check for intersecting polygons before performing the query, and give the appropriate feedback to the user as to why the search did not execute. 

### Visual definition of an Intersecting Polygon. 

![intersecting polygon](https://www.dropbox.com/s/vylkrn785y6yt1g/intersecting_polygon.png?dl=1)


###Results in:

```
cqlsh> SELECT state, fips, pop FROM geo.states where 
   ... solr_query='{"q":"*:*","fq":"geo:\"IsWithin(POLYGON((-107.7978515625 42.50754004948742,-102.7001953125 42.53992763032448,-108.2373046875 38.84291652482239,-102.6123046875 38.91133881927711,-107.7978515625 42.50754004948742)))\""}';
   
ServerError: Couldn't parse shape 'POLYGON((-107.7978515625 42.50754004948742,-102.7001953125 42.53992763032448,-108.2373046875 38.84291652482239,-102.6123046875 38.91133881927711,-107.7978515625 42.50754004948742))' because: com.spatial4j.core.exception.InvalidShapeException: Self-intersection at or near point (-105.32117619482763, 40.78995399371487, NaN)
```


