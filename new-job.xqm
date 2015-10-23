xquery version "3.1";
module namespace job="http://pekoe.io/pekoe/new-job";

import module namespace rp = "http://pekoe.io/resource-permissions"      at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";
import module namespace tenant = "http://pekoe.io/tenant"                at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace sn="http://gspring.com.au/pekoe/serial-numbers"  at "xmldb:exist:///db/apps/pekoe/modules/serial-numbers.xqm";

declare variable $job:doctype := request:get-parameter("doctype", ());


(: ****
    One of the main problems that must be handled is how to create a 'new' with a serial-number, 
    and then either SAVE it or RELEASE and RETURN/RECYCLE the serial-number. 
    Alongside this is the desire to standardise the process,
    and to avoid complex front-end code to handle 'new' vs open/save.
    
    When the front-end asks for a 'new' file, we create it, return it and provide a suitable path for it.
    If the user chooses Save, the file is POSTed back here - and POST means SAVE.
    The response from the Save is a new Location. Thus the consequent RELEASE will be sent to the resource-manager (via the controller) and NOT THIS FUNCTION.
    
    Otherwise, the file is "released" through here - which means RECYCLE the serial number and the data is NOT SAVED.
    
    The 'new-path-fn' key in the config can use one of the two provided functions OR override the function
    job:direct-year-month-path#2    ( YYYY/MM/id.xml)
    job:bundle-path#2               ( YYYY/MM/id/data.xml )
    
   **** :)

declare variable $job:config := map {
    'save-fn'           : job:save#1,
    'id-fn'             : function ($config) { sn:get-next-padded-id($config) },
    'id-number-picture' : '000000',
    'id-prefix'         : '',
    'new-fn'            : job:new#1,
    'new-path-fn'       : job:bundle-path#2 , (: this can be replaced by the other new-path-fn below 'job:direct-year-month-path#2' , or with a custom function :)
    'get-job-fn'        : function ($config, $id) { error(QName('http://pekoe.io/err', 'JobFnReq'), 'Missing get-job-fn')  },   (: This one must be replaced. :)
    'item-id-name'      : $job:doctype, 
    'doctype'           : $job:doctype, 
    'path-to-me'        : '/exist/pekoe-files' || substring-after(request:get-servlet-path(),$tenant:tenant-path)
    };
    

(: ------------------------------------------------  MAIN FUNCTION. Save (POST) or 'action' Capture, Release --------------------------------------- :)
declare function job:process($config as map(*)) {
    if (request:get-method() eq 'POST') then  $config?save-fn($config)
    else
        switch (request:get-parameter('action',''))
        case "capture"  return job:capture($config)
        case "release"  return job:release($config)
        default         return <result status='error'>Unknown action</result>
};

declare function job:capture($config as map(*)) { (: this is a guard for job:new :)
    response:set-header("Content-type","text/xml"),
    util:declare-option("exist:serialize", "method=xml media-type=text/xml"),
    let $id := request:get-parameter("id",())
    return 
        if ($id eq "new") 
        then ($config?new-fn($config)) 
        else 
           <result status='fail'>Can't capture {$id} here</result>
};

declare function job:release($config) {       (:  THIS ONLY APPLIES to NEW Jobs. It should only be called if the job has not been saved.:)
    let $id := request:get-parameter("id",())
    let $job := $config?get-job-fn($config, $id)
    return 
        if (exists($job)) then (: This should be an error. :)
            let $job-file := document-uri(root($job))
            return rp:release-job($job-file)
        else sn:return($config?item-id-name, $id)
};


(: -----------------  new-path-fn -------------------------------------------------------------------------
   Use one of these or your own custom file-path function. It should return a path and a data-file-name :)
   
declare function job:bundle-path($config, $id) {  (: --------------  This is a "BUNDLE" path - Create a collection named with the job-id in which to store the data.xml :)
    map { 
        'path' : concat( format-date(current-date(),"[Y]/[M01]") , '/' , $id), 
        'data-file-name' : "data.xml" 
        }
};

declare function job:direct-year-month-path($config, $id) { (: ------------- This is a "FILE" path - Create a file named with the job-id  :)
    map { 
        'path' :  format-date(current-date(),"[Y]/[M01]"),
        'data-file-name' :    $id || ".xml"
        }
};

declare function job:new($config as map(*)) {
    let $id := $config?id-fn($config)
    let $new-path :=  $config?new-path-fn($config, $id) 
    let $quarantined-path := "/exist/pekoe-files" || substring-after($new-path?path, $tenant:tenant-path)
    let $created-by := sm:id()//sm:real/sm:username/text()
    
    return 
    (   response:set-status-code(201), (: "Created" :)
        response:set-header("Location", $config?path-to-me || "?id=" || $id || "&amp;doctype=" || $config?doctype), (: The path remains the same with the addition of the id parameter. This allows the user to Close without Saving - and the ID can be recycled. :)

        element {$config?doctype} {
            attribute created-dateTime {current-dateTime()},
            attribute created-by {$created-by},
            element id {$id}
        }
    )
};

(:  Save only applies to new jobs. Save is a POST. SAVE IS ONLY USED BY NEW JOBS. Save is only used by NEW jobs. ALL OTHERS GO THROUGH resource-management.xql 
    Save uses the id to create a new file. It sets the Location to the path of this new file.
    BUT I'm not really sure why this can't be handled by the resource-manager.
    
    ************** THIS WHOLE FUNCTION CAN BE REPLACED BY YOUR OWN CUSTOM SAVE FUNCTION.  ************* :)
    
declare function job:save($config) {
     let $id := request:get-parameter("id",()) 
     let $data := request:get-data()
     
     let $new-path-map := $config?new-path-fn($config, $id) 
     let $good-collection := rp:create-collection($config?collection-path, $new-path-map?path)
     
     (: this is where a file-write should happen - storing the previous version to the file-system. Or other Version Control :)
     
     let $stored := xmldb:store($good-collection, $new-path-map?data-file-name, $data)
     let $owner := sm:id()//sm:real/sm:username/string()
     let $chown := sm:chown(xs:anyURI($stored), $owner )
     let $permissions : = sm:chmod(xs:anyURI($stored), $rp:open-for-editing)
     
     let $quarantined-path := "/exist/pekoe-files" || substring-after($stored, $tenant:tenant-path)
     return (response:set-status-code(201), (: "Created". Changing the location means this job will be 'released' by the resource-manager - NOT the original query. :)
        response:set-header("Location", $quarantined-path),
        <result status='okay' path='{$stored}'>Saved item {$id}</result>
        )
};





