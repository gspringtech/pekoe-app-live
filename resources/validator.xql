import module namespace v="http://gspring.com.au/pekoe/validator" at "validator.xqm";
(:
    The path to the schematron should be provided as a parameter...
:)
let $job-path := request:get-parameter("job",())
let $job := doc($job-path)
return 
    if (empty($job)) 
    then <result status='error'>No Job document</result>
else v:validate($job, xs:anyURI("/db/pekoe/files/education/schemas/school-bk-send-email.sch") )