xquery version "3.0";
declare default element namespace "urn:isbn:1-931666-22-9";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace saxon="http://saxon.sf.net/";
declare boundary-space strip;
import module namespace functx = "http://www.functx.com" at "https://www.datypic.com/xq/functx-1.0.1-doc.xq";
declare option saxon:output "omit-xml-declaration=yes";


(:
README
1. this transformation assumes ASpace data serialized as EAD2002
2. it extracts records for each component with the level set to "item"
3. it assumes use of marc relator codes
4. field-specific notes:
	- EAD has no structured field that is equivalent to "dated?" (per my understanding: an explicit date recorded on the mss by the/a creator.
	  It would inform the unitdate if present, but the presence of a unitdate does not mean it is based on a colophon.
	  So the only certainty we have is that if no unitdate was recorded, then there was no colophon with a date.
	- Should the first genreform be excluded from Subjects, since we are pulling it into genre_as_recorded?
	- Do we ever expect a corpname or famname in artist_as_recorded (or for that matter any of the associated names? E.g. a workshop?
	- Should we look up if no language is given for the component? The disadvantage is, we may get multiple languages.
	- I added labels to the physical description elements
	- I truncated the note to 400 characters
	- NB acknowledgments is mapped to sponsor, which only exists at the collection level
:)

declare function local:format-for-csv($input) {
  for $i in $input
  return normalize-space('"' || replace($i, '"', '""') || '"')
};

declare variable $ead as document-node()+ := doc("file:/Users/heberleinr/Documents/Digital_Scriptorium/ead2csv/C0776_20241216_214730_UTC__ead.xml");
let $manuscripts := $ead//c[@level = "item"]
let $csv := 
<csv>{
	('"dummy_column","ds_id","date_added","date_last_updated","source_type","cataloging_convention","holding_institution_ds_qid","holding_institution_as_recorded","holding_institution_id_number","holding_institution_shelfmark","link_to_holding_institution_record","iiif_manifest","production_place_as_recorded","production_place_ds_qid","production_date_as_recorded","production_date","century","century_aat","dated","title_as_recorded","title_as_recorded_agr","uniform_title_as_recorded","uniform_title_agr","standard_title_ds_qid","genre_as_recorded","genre_ds_qid","subject_as_recorded","subject_ds_qid","author_as_recorded","author_as_recorded_agr","author_ds_qid","artist_as_recorded","artist_as_recorded_agr","artist_ds_qid","scribe_as_recorded","scribe_as_recorded_agr","scribe_ds_qid","associated_agent_as_recorded","associated_agent_as_recorded_agr","associated_agent_ds_qid","former_owner_as_recorded","former_owner_as_recorded_agr","former_owner_ds_qid","language_as_recorded","language_ds_qid","material_as_recorded","material_ds_qid","physical_description","note","acknowledgments","data_processed_at","data_source_modified","source_file"') || codepoints-to-string(10),
	for $mss in $manuscripts
	let $blank := ""
	let $ds_id := ""
	let $date_added := string(current-date())
	let $date_last_updated := ""
	let $source_type := "ead-xml"
	(:hardcoding this because descrules is discursive, so this may not always be true? :)
	let $cataloging-convention := "dacs"
	let $holding_institution_ds_qid := ""
	let $holding_institution_as_recorded := ""
(:		if ($mss/ancestor::archdesc/did/origination/corpname[@role = "col"])
		then $mss/ancestor::archdesc/did/origination/corpname[@role = "col"]/text()
		else "":)
	let $holding_institution_id_number := $mss/data(@id)
(:keeping this around for now in case we want it later:)
(:		if ($mss/did/unitid[not(@type = "aspace_uri")][count(.) = 1])
		then
			$mss/did/unitid[not(@type = "aspace_uri")]/text()
		else
			if ($mss/did/unitid[not(@type = "aspace_uri")][count(.) > 1])
			then
				error(xs:QName('local:unitid_conflict'), "more than one unitid associated with this item, please pick one")
			else
				if ($mss/@id)
				then
					$mss/data(@id)
				else
					$mss/ancestor::ead//eadid/text() || "_" || functx:index-of-node($mss/ancestor::dsc//c[@level = "item"], $mss)
:)	let $holding_institution_shelfmark := tokenize($mss/did/unittitle/text(), ":")[1]
(:keeping this around for now in case we want it later:)
(:		if ($mss/did/container)
		then
			(for $container in $mss/did/container[1]
			return
				($container/@label || "_" || $container/@type || "_" || $container/text()))
		else
			"":)
	let $link_to_holding_institution_record := 
		if ($mss/ancestor::ead//eadid/@url)
		then $mss/ancestor::ead//eadid/data(@url)
		else ""
	let $iiif_manifest :=
		if (matches($mss/did/dao/@xlink:href, "manifest"))
		then
			$mss/did/dao/data(@xlink:href)
		else
			""
	let $geogname := 
		if ($mss/ancestor::archdesc/controlaccess/geogname)
		then $mss/ancestor::archdesc/controlaccess/geogname[1]/text()
		else ""
	let $genre_as_recorded := 
		if ($mss/ancestor::archdesc/controlaccess/genreform)
		then $mss/ancestor::archdesc/controlaccess/genreform[1]/text()
		else ""
	let $genre_ds_qid := ""
	let $production_place_as_recorded := 
		if ($geogname)
		then tokenize($geogname, '--')[1]
		else 
			if ($genre_as_recorded)
			then tokenize($genre_as_recorded, '--')[2]
			else ""
	let $production_place_ds_qid := ""
	let $production_date_as_recorded := $mss/did/unitdate/text()
(:keeping this for now in case we want to use it elsewhere:)
		(:if ($genre_as_recorded)
		then
			for $token at $pos in tokenize($genre_as_recorded, '--')
				where (matches($token, "^\d") or matches($token, "cent")) and $pos > 1
			return
				$token
		else "":)
	let $production_date := 
		if ($mss/did/unitdate[@normal])
		then 
			let $tokens := tokenize($mss/did/unitdate/@normal, "/")
			return
				if (count($tokens) = 2)
				then 
					if ($tokens[1] = $tokens[2])
					then $tokens[1]
					else $tokens[1] || "-" || $tokens[2]
				else $tokens[1]
		else ""
	let $century := ""
	let $century_aat := ""
	let $dated :=
		if ($production_date_as_recorded = "")
		then
			"FALSE"
		else
			""
	let $title_as_recorded := 
(:for the condition, check only the direct child of current:)
		if ($mss/c[@level="otherlevel"])
		then
			$mss/did/unittitle/text() || "|" ||
(:for the execution, check all descendants:)
			string-join($mss//c[@level="otherlevel"]/did/unittitle/text(), "|")		
		else $mss/did/unittitle/text()
	let $title_as_recorded_agr := ""
	let $uniform_title_as_recorded := ""
	let $uniform_title_agr := ""
	let $standard_title_ds_qid := ""
	let $subject_as_recorded :=
		if ($mss/controlaccess)
		then string-join($mss/controlaccess/*/text(), '|')
		else string-join($mss/ancestor::archdesc/controlaccess/*/text(), '|')
	let $subject_ds_qid := ""
	let $author_as_recorded :=
		if ($mss/did/origination/persname[matches(@role, "cre")])
		then string-join($mss/did/origination/persname[matches(@role, "cre")], "|")
		else
			if ($mss/ancestor::archdesc/did/origination/persname[matches(@role, "cre")])
			then string-join($mss/ancestor::archdesc/did/origination/persname[matches(@role, "cre")], "|")
			else ""
	let $author_as_recorded_agr := ""
	let $author_ds_qid := ""
	let $artist_as_recorded :=
		if ($mss/did/origination/persname[matches(@role, "art|ill|ilu")])
		then string-join($mss/did/origination/persname[matches(@role, "art|ill|ilu")], "|")
		else
			if ($mss/ancestor::archdesc/did/origination/persname[matches(@role, "art|ill|ilu")])
			then string-join($mss/ancestor::archdesc/did/origination/persname[matches(@role, "art|ill|ilu")], "|")
			else ""
	let $artist_as_recorded_agr := ""
	let $artist_ds_qid := ""
	let $scribe_as_recorded :=
		if ($mss/did/origination/persname[matches(@role, "scr")])
		then string-join($mss/did/origination/persname[matches(@role, "scr")], "|")
		else
			if ($mss/ancestor::archdesc/did/origination/persname[matches(@role, "scr")])
			then string-join($mss/ancestor::archdesc/did/origination/persname[matches(@role, "scr")], "|")
			else ""
	let $scribe_as_recorded_agr := ""
	let $scribe_ds_qid := ""
	let $associated_agent_as_recorded :=
		if ($mss/did/origination/persname[matches(@role, "asn")])
		then string-join($mss/did/origination/persname[matches(@role, "asn")], "|")
		else
			if ($mss/ancestor::archdesc/did/origination/persname[matches(@role, "asn")])
			then string-join($mss/ancestor::archdesc/did/origination/persname[matches(@role, "asn")], "|")
			else ""
	let $associated_agent_as_recorded_agr := ""
	let $associated_agent_ds_qid := ""
	let $former_owner_as_recorded :=
		if ($mss/did/origination/*[matches(@role, "fmo")])
		then string-join($mss/did/origination/*[matches(@role, "fmo")], "|")
		else
			if ($mss/ancestor::archdesc/did/origination/*[matches(@role, "fmo")])
			then string-join($mss/ancestor::archdesc/did/origination/*[matches(@role, "fmo")], "|")
			else ""
	let $former_owner_as_recorded_agr := ""
	let $former_owner_ds_qid := ""
	let $language_as_recorded := 
		if ($mss/did/langmaterial/language)
		then 
			if ($mss/did/langmaterial/language[@langcode])
			then string-join(
				for $language in $mss/did/langmaterial/language
				return string-join($language/text() || "|" || $language/@langcode),
				";")
			else string-join($mss/did/langmaterial/language/text(), ";")
(:		else
			if ($mss/ancestor::archdesc/did/langmaterial/language)
			then 
				if ($mss/ancestor::archdesc/did/langmaterial/language[@langcode])
				then string-join(
					for $language in $mss/ancestor::archdesc/did/langmaterial/language
					return string-join($language/text() || "|" || $language/@langcode),
					";")
				else string-join($mss/ancestor::archdesc/did/langmaterial/text(), ";"):)
			else ""
	let $language_ds_qid := ""
	let $material_as_recorded := ""
	let $material_ds_qid := ""
	let $physical_description := 
		if ($mss/did/physdesc/*)
		then 
			"Extent: " || normalize-space($mss/did/physdesc/extent/text()) || " ; " ||
			"Dimensions: " || normalize-space($mss/did/physdesc/dimensions/text()) || " ; " ||
			"Description: " || normalize-space($mss/did/physdesc/physfacet/text())
		else ""
	let $note := 
		if ($mss/scopecontent)
		then substring(normalize-space(string-join($mss/scopecontent/*[not(self::head)]/text(), '|')), 1, 400)
		else ""
	let $acknowledgments := 
		if ($mss//ancestor::ead/eadheader//sponsor)
		then $mss/ancestor::ead/eadheader//sponsor/text()
		else ""
	let $data_processed_at := string(current-dateTime())
	let $data_source_modified := ""
	let $source_file := base-uri($ead)
	
	return
	(
	string-join(
		local:format-for-csv(
			( 
	  	  $blank,
			$ds_id,
			$date_added,
			$date_last_updated,
			$source_type,
			$cataloging-convention,
			$holding_institution_ds_qid,
			$holding_institution_as_recorded,
			$holding_institution_id_number,
			$holding_institution_shelfmark,
			$link_to_holding_institution_record,
			$iiif_manifest,
			$production_place_as_recorded,
			$production_place_ds_qid,
			$production_date_as_recorded,
			$production_date,
			$century,
			$century_aat,
			$dated,
			$title_as_recorded,
			$title_as_recorded_agr,
			$uniform_title_as_recorded,
			$uniform_title_agr,
			$standard_title_ds_qid,
			$genre_as_recorded,
			$genre_ds_qid,
			$subject_as_recorded,
			$subject_ds_qid,
			$author_as_recorded,
			$author_as_recorded_agr,
			$author_ds_qid,
			$artist_as_recorded,
			$artist_as_recorded_agr,
			$artist_ds_qid,
			$scribe_as_recorded,
			$scribe_as_recorded_agr,
			$scribe_ds_qid,
			$associated_agent_as_recorded,
			$associated_agent_as_recorded_agr,
			$associated_agent_ds_qid,
			$former_owner_as_recorded,
			$former_owner_as_recorded_agr,
			$former_owner_ds_qid,
			$language_as_recorded,
			$language_ds_qid,
			$material_as_recorded,
			$material_ds_qid,
			$physical_description,
			$note,
			$acknowledgments,
			$data_processed_at,
			$data_source_modified,
			$source_file)), ",") || codepoints-to-string(10)
	)
}</csv>

let $csv := document{$csv/text()}
return put($csv, "ead2ds.csv")
