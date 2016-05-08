xquery version "3.1";



(:
<report created-dateTime="2015-12-15T15:01:10.775+10:30" created-by="admin" edited="2015-12-15T04:32:03.089Z">
    <title>Booking stats data</title>
    <applies-to>ad-bookings</applies-to>
    <instructions>
        <p xmlns="http://www.w3.org/1999/xhtml">For the given date range, return each booking with days-prior and paid-before. Seletion is based on AD-date.</p>
    </instructions>
    <input>
        <name>from</name>
        <type>date</type>
        <default-value/>
    </input>
    <input>
        <name>to</name>
        <type>date</type>
        <default-value/>
    </input>
    <xquery></xquery>
    </report>
    
    :)
    
    declare function local:process-inputs() {
    (: Generate a map of the named inputs. Get the value from the paramter OR the default.
        Params should be either text, date, or number.
        default-values should be ???? an evaluable query? A named-function? 
        
        REMEMBER these are form-inputs.
        
        Maybe all that is required is to set them as attributes
        
        The problem is that the first time the report is run, (whether compiled or not) there will be NO PARAMS and so DEFAULT values will be used.
        BUT because there are no params, there will be no values to display in the stylesheet.
        
        AND the Query doesn't have access to those defaults because the query doesn't have access to itself. Perhaps it should
        
        So if THIS compile phase is run prior to the actual query, then the params will be in the pipeline.
        
        
        What if the /report gets MODIFIED by this COMPILE query so that the INPUTS have REAL VALUES? (That would be a real compilation)
        
        SO the saved query can get parameters, but can't pass them to the stylesheet. Is that the problem?
        
        
        HERE's the answer:
        Instead of this (in the <forward>
        <set-attribute name='xslt.source' value='xmldb:exist://{$report-path}' />
        
        THIS QUERY should return the value of the SOURCE after modifying the inputs appropriately.
        So - effectively regenerate that structure above. (which looks like another stylesheet)
        
        AND it would be easy to simply EVAL the whole thing. ????
        
        So the output of THIS query is simply the /report above, with the appropriate VALUES added to the INPUTs. 
        It doesn't need to have the query.
:)
    ()
    };
    
    let $report-path := request:get-attribute('report-path')
    let $report := doc($report-path)
    
    let $attributes := for $input in $report//input return request:set-attribute($input/name/string(), evaluate default-value or try to get the parameter. )
    
    return ()