xquery version "3.1";
(: manage the Config and Table of Contents for AWS S3. 
   Wrapper for s3-post-get and s3m:shmac functions:)
module namespace ps3="http://pekoe.io/pekoe-s3";
import module namespace s3="http://pekoe.io/s3";
import module namespace http = "http://expath.org/ns/http-client";

declare variable $ps3:default-toc-name := "S3-TOC.xml";

(: Can I wrap the s3 module here so that I don't need it elsewhere? :)
(: Manage TOC :)

(: Create an s3:toc resource :)
(: Create an s3:file :)
(: Add an s3:file to an s3:toc (or update/replace) It's up to the calling query to decide whether to overwrite or change the file-name.
    NOTE - There is the possibility of VERSIONING files with a date-time-stamp.
    :)

(: The imported s3 module provides the functions 
    s3:make-download-link($s3-resource, $config) 
    s3:make-upload-form-partial-key($col, $file-name, $config)
    s3:make-upload-form-full-key($col, $file-name, $config)
    
    ** TODO UPDATE ---- The module code is in /Users/alisterpillow/Development/exist-builds/book-code/chapters/advanced-topics/shmac-module  **

:)

(: Other config files can be used - this is a convenience function :)
declare function ps3:config($tenant-path) {
    doc($tenant-path || '/config/pekoe-s3.xml')/s3:config  
};

declare function ps3:create-toc($path) {
    ps3:create-toc($path, $ps3:default-toc-name)
};

declare function ps3:create-toc($path, $name) {
    let $toc := $path || '/' || $name
    let $log := util:log('warn','S3-TOC created  in ' || $toc)
    
    return
    if (exists(doc($toc)/s3:toc)) 
    then $toc
    else xmldb:store($path,$name,<s3:toc></s3:toc>)
};  

(: Fix encoding issues. I can't change what the user uploads, so I must encode the filename part of the key - not the Path. :)
declare function ps3:fix-key($k) {
    let $parts := tokenize($k,'/')
    let $fname := $parts[last()]
    return string-join(($parts[position() ne last()], encode-for-uri($fname)),'/')
};

(: RETURN an existing FILE SPEC, or create a new one. The @etag is the indicator
let $f-map := map {
            'key':  $s3-key,
            'display': $binary,
            'toc' : $toc,
            'config': $config,
            'user': 'admin',
            'size': xmldb:size($col, $binary),
            'mime' : xmldb:get-mime-type(xs:anyURI($full-path)),
            'created' : xmldb:created($col,$binary),
            'modified' : xmldb:last-modified($col, $binary)
        }
:)
declare function ps3:create-file($spec) {
    <s3:file 
        key="{$spec?key}" 
        user="{$spec?user}" 
        created-date="{$spec?created}" 
        modified-date="{$spec?modified}" 
        size="{$spec?size}" 
        etag="{$spec?etag}" 
        mime-type="{$spec?mime}">{$spec?config/@bucket}{$spec?config/@region}{($spec?display, tokenize($spec?key,'/')[position() eq last()])[. ne ''][1]}</s3:file>
};

declare function ps3:update-toc($toc, $s3-file) {
    if (exists($toc/s3:file[@key eq $s3-file/@key])) then update replace $toc/s3:file[@key eq $s3-file/@key] with $s3-file
    else update insert $s3-file into $toc
};

(: Upload binaries from a collection into the tenant's current S3 bucket :)
(: NOTE ************************** THIS UPLOADS EVERYTHING!!!! DON'T USE ON AN ACTIVE JOB ****************** NEED TO ADD A FILTER FOR PDF ONLY ************ :)
(: THIS UPLOADS EVERYTHING INCLUDING XQUERY AND OTHER NON-XML FILES. :)
declare function ps3:upload-binaries-from-collection($config, $tenant-path, $col) {
    let $toc-path := ps3:create-toc($col, $ps3:default-toc-name)
    let $toc := doc($toc-path)/s3:toc
    
    let $local-path := substring-after($col, $tenant-path || "/")
    
    (: UPLOAD LOOP   :)
    for $binary in (xmldb:get-child-resources($col)[not(ends-with(.,'.xml'))]) (: NEEDS BETTER FILTER :)

    (: Existing files can have really dumb names like "D.pdf-1.pdf"       :)
        let $s3-key := $local-path || "/" || encode-for-uri($binary)  (: Key is $col path after tenant path   :)
        let $log := util:log("warn","MOVE TO S3 " || $s3-key)
        
(:  I feel this is not quite right - creating the map is useful because it's neater than using unnamed params, but having to create it twice doesn't feel right.
    TODO FIX THIS The created and modified dates (plus USER) aren't being MODIFIED below. :)
    
(:    TODO **********************************************************   NOTE - FILENAMES CAN BE BADD - URL ENCODE OR FIX. :)
        let $full-path := $col || '/' || $binary
        let $f-map := map {
            'key':  $s3-key,
            'display': $binary,
            'toc' : $toc,
            'config': $config,
            'user': 'admin',
            'size': xmldb:size($col, $binary),
            'mime' : xmldb:get-mime-type(xs:anyURI($full-path)),
            'created' : xmldb:created($col,$binary),
            'modified' : xmldb:last-modified($col, $binary)
        }
        
        let $s3-file := ps3:create-file($f-map)
        

        let $aws-signed-form := s3:make-upload-form-full-key($s3-file, $config) (: MAKE UPLOAD FORM :)
        
        
        let $file-data := util:binary-doc($full-path)
        let $mime-type := xmldb:get-mime-type(xs:anyURI($full-path))
       
        let $ss := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                    xmlns:h="http://www.w3.org/1999/xhtml"
                    xmlns:http="http://expath.org/ns/http-client"
                    exclude-result-prefixes="xs xd" version="2.0">
                    
                    <xsl:template match="/form">
                        <http:request method="post" http-version="1.0">
                            <http:header name="Connection" value="close" />
                            <http:multipart media-type="multipart/form-data" boundary='xyzBouNDarYxyz'>
                                <xsl:apply-templates />                                
                                <http:header name="Content-Disposition" value="form-data; name=file; filename={$binary}"/>
                                <http:header name="Content-Type" value="{$mime-type}" />
                                <http:body media-type="{$mime-type}" method="binary">{$file-data}</http:body>
                            </http:multipart>
                        </http:request>
                    </xsl:template>
                    
                    <xsl:template match="input">
                        <http:header name="Content-Disposition" value="form-data; name={{./@name}}" />
                        <http:body media-type="text/plain"><xsl:value-of select="./@value"/></http:body>
                    </xsl:template>
                </xsl:stylesheet>
    
        let $content := transform:transform($aws-signed-form, $ss,())
        
        let $resp := http:send-request($content, $aws-signed-form//@action)
        return if ($resp[1]/@status eq '201') 
            then 
                let $uploaded := map:new(($f-map, map {'etag':replace($resp[2]//ETag,'"','') }))
                let $new-file := ps3:create-file($uploaded)
                let $u := ps3:update-toc($toc,$new-file)
                return $new-file
            else util:log('error',$resp)
};



