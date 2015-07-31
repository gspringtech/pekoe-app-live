xquery version "3.0";
module namespace af = "http://pekoe.io/fs/associated-files";
declare %private variable $af:secret_word := environment-variable('MY_WORD');
declare %private variable $af:prefx := "/chai/";

import module "http://expath.org/ns/crypto";
import module namespace tenant="http://pekoe.io/tenant" at "tenant.xqm";

(: -----------------------
This module is primarily for writing, listing and providing secure access 
to binary documents associated with Client Jobs.

Instead of storing Associated Files within the /db, this module
will allow them to be stored in the local File System, and be served securely by Nginx.

However, it is flawed. It requires a DBA to execute the file module functions which means that it must be a main query.
That means every access to associated files must be through a main query. TOO HARD.

-------------------------:)

declare function af:job-folder($job) {
    let $path := tenant:local-path(util:collection-name($job))
    let $job-name := substring-before(util:document-name($job),'.')
    return string-join(('/client-files', $tenant:tenant, $path, $job-name),'/') 
};

declare function af:write-file-to-job-folder($job-path, $doc-name as xs:string, $binary as xs:base64Binary) {
    let $folder := af:job-folder($job-path)
    return if( $doc-name ne '' and file:mkdirs($folder)) then file:serialize-binary($binary,$folder || '/' || $doc-name)
    else ()
};


(: Generate a secure_link url.
    Secure content is served from /client-files using a path aliased from /tenant-files in nginx
    /tenant-files is marked as "internal" to Nginx meaning that a visitor can't simply type .pekoe.io/tenant-files/path/to/resource
    
    The secure link is prefixed with /chai/ (not a good tea)
    and this location is rewritten to /tenant-files IF the HASH is valid and matches the supplied path
    
    https://bkfa.pekoe.io/chai/cd9b407384c1d1cef9fe288e79d77c5d0/path/to/Residential-Cover.odt
    ... this doesn't work now because I've changed the secure word.
    
    The actual link doesn't begin with a slash - but it MUST begin with the tenant-name
    cm/files/jobs/2015/06/RT-00001/Residential-Cover-201506-001.odt
    
    So the path must start with the tenant id
    and then be a full path to the Job within the tenant. 
    
    This is only intended to be used by Associated Files (which includes Uploads and Generated content.)
:)

(: Generate a secure link to a file outside the db:)
declare function af:secure-link($path-to-file) {
    
    let $link := 'path/to/Residential-Cover.odt'
    let $prefix := "/chai/"
    let $sl := crypto:hash($link || $af:secret_word, "MD5", "hex")
    return $sl
};

declare function af:list-files ($job-path) {
    let $folder := af:job-folder($job-path)
    return file:list($folder)
};



(:file:mkdirs('/client-files/path/to'),:)
