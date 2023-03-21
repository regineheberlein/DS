xquery version "3.0";
declare default element namespace "https://catalog.digital-scriptorium.org/wiki/";
declare namespace dcterms = "http://purl.org/dc/terms/";
declare namespace owl = "http://www.w3.org/2002/07/owl#";
declare namespace rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"; 
declare namespace rdfs = "http://www.w3.org/2000/01/rdf-schema#";
declare namespace skos = "http://www.w3.org/2004/02/skos/core#";
declare namespace vann = "http://purl.org/vocab/vann/";
declare namespace voaf = "http://purl.org/vocommons/voaf#";

declare variable $ontology as document-node()* := doc("file:/Users/heberleinr/Documents/Digital%20Scriptorium/ds-ontology.owl");

for $item in $ontology/rdf:RDF/*[not(self::owl:Ontology)]
let $domain := 
	<domain>{
	if ($item/rdfs:domain/@rdf:resource) 
	then $item/rdfs:domain/@rdf:resource/data()
	else for $i in $item/rdfs:domain/owl:Class/owl:unionOf/*
	return $i/@rdf:about || ";"
	}</domain>
let $range := 
	<range>{
	if ($item/rdfs:range/@rdf:resource) 
	then $item/rdfs:range/@rdf:resource/data()
	else for $i in $item/rdfs:range/owl:Class/owl:unionOf/*
	return $i/@rdf:about || ";"
	}</range>
	
return 
normalize-space(
	$item/name() || '^' ||
	$item/@* || '^' ||
	$item/rdfs:label || '^' ||
	$item/skos:definition || '^' ||
	$item/skos:scopeNote || '^' ||
	$domain || '^' ||
	$range
) || codepoints-to-string(10)
